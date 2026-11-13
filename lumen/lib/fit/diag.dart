import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/glass.dart';
import '../core/settings.dart';

/// What one place in the app cost, frame by frame.
class _Bucket {
  int frames = 0, late = 0;
  double buildSum = 0, rasterSum = 0, buildMax = 0, rasterMax = 0;
  final List<double> raster =
      <double>[]; // recent raster times, for the 95th percentile
}

/// Records how every part of Prism performs, so one tap can copy a report.
/// Each frame is filed under the scene that was showing ("home", "train+rest",
/// "food+sheet" and so on).
class Diag {
  Diag._();
  static final Diag instance = Diag._();
  static const String build = 'Prism build 6';

  /// Where the person is: the page, what floats over it, and anything extra on that page.
  String _page = 'home', _overlay = '', _extra = '';
  String get page => _page;
  set page(String v) => _move(() => _page = v);
  set overlay(String v) => _move(() => _overlay = v);
  set extra(String v) => _move(() => _extra = v);
  String get scene => '$_page${_page == 'train' ? _extra : ''}$_overlay';

  // How long each scene has been showing, so frames can be read as "per second".
  final Map<String, int> _shownMs = <String, int>{};
  int _since = 0;
  void _move(void Function() change) {
    final int now = _clock.elapsedMilliseconds;
    _shownMs[scene] = (_shownMs[scene] ?? 0) + now - _since;
    _since = now;
    change();
  }

  /// The soft coloured lights behind everything. Off by default: a plain background is the cheapest.
  final ValueNotifier<bool> wallpaperOn = ValueNotifier<bool>(false);
  bool get wallpaper => wallpaperOn.value;
  final Map<String, _Bucket> _buckets = <String, _Bucket>{};
  final List<String> _events = <String>[];
  final Stopwatch _clock = Stopwatch()..start();
  int? _prevVsync;
  String _device = 'unknown device';
  double _refresh = 60;

  Future<void> start() async {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    try {
      _device =
          await const MethodChannel('lumen/device')
              .invokeMethod<String>('info') ??
          _device;
    } catch (_) {
      // Not on Android, or an older build of the native side.
    }
  }

  /// Notes something the person did, with the time it happened.
  void event(String what) {
    _events.add(
      '${(_clock.elapsedMilliseconds / 1000).toStringAsFixed(1)}s $what',
    );
    if (_events.length > 60) {
      _events.removeAt(0);
    }
  }

  void reset() {
    _buckets.clear();
    _events.clear();
    _shownMs.clear();
    _since = 0;
    _clock
      ..reset()
      ..start();
  }

  void _onTimings(List<FrameTiming> timings) {
    final Iterable<FlutterView> views = PlatformDispatcher.instance.views;
    if (views.isNotEmpty && views.first.display.refreshRate > 1) {
      _refresh = views.first.display.refreshRate;
    }
    final double interval = 1e6 / _refresh;
    final _Bucket b = _buckets.putIfAbsent(scene, _Bucket.new);
    for (final FrameTiming t in timings) {
      final int vsync = t.timestampInMicroseconds(FramePhase.vsyncStart);
      final int? prev = _prevVsync;
      _prevVsync = vsync;
      final double build = t.buildDuration.inMicroseconds / 1000,
          raster = t.rasterDuration.inMicroseconds / 1000;
      b.frames++;
      b.buildSum += build;
      b.rasterSum += raster;
      if (build > b.buildMax) {
        b.buildMax = build;
      }
      if (raster > b.rasterMax) {
        b.rasterMax = raster;
      }
      b.raster.add(raster);
      if (b.raster.length > 1500) {
        b.raster.removeAt(0);
      }
      // A frame that arrived more than half a refresh late, while things were moving.
      if (prev != null) {
        final int gap = vsync - prev;
        if (gap > interval * 1.5 && gap < interval * 6) {
          b.late += ((gap / interval).round() - 1).clamp(1, 5);
        }
      }
    }
  }

  String report() {
    final FlutterView v = PlatformDispatcher.instance.views.first;
    final StringBuffer o = StringBuffer()
      ..writeln('$build  ·  ${_clock.elapsed.inSeconds}s recorded')
      ..writeln(_device)
      ..writeln(
        'screen ${v.physicalSize.width.round()}x${v.physicalSize.height.round()} @${v.devicePixelRatio}x, ${_refresh.round()} Hz, frame budget ${(1000 / _refresh).toStringAsFixed(1)} ms',
      )
      ..writeln(
        'glass: set ${settings.quality.name}, running ${settings.effectiveQuality.name}, shader ${GlassShaders.available ? 'ok' : 'MISSING'}'
        '${settings.reduceTransparency ? ', transparency reduced' : ''}  ·  wallpaper ${wallpaper ? 'on' : 'off'}  ·  ${settings.themeMode.name}',
      )
      ..writeln()
      ..writeln(
        'scene             shown  frames  per s        late   build avg/max   draw avg/p95/max (ms)',
      );
    _move(() {}); // count the time up to this moment
    final List<MapEntry<String, _Bucket>> rows = _buckets.entries.toList()
      ..sort(
        (MapEntry<String, _Bucket> a, MapEntry<String, _Bucket> b) =>
            b.value.frames.compareTo(a.value.frames),
      );
    int frames = 0;
    for (final MapEntry<String, _Bucket> e in rows) {
      final _Bucket b = e.value;
      if (b.frames == 0) {
        continue;
      }
      frames += b.frames;
      final List<double> sorted = List<double>.of(b.raster)..sort();
      final double p95 = sorted[((sorted.length - 1) * 0.95).round()];
      final double secs = (_shownMs[e.key] ?? 0) / 1000;
      String f(double x) => x.toStringAsFixed(1);
      o.writeln(
        '${e.key.padRight(16)} ${'${secs.round()}s'.padLeft(6)} ${b.frames.toString().padLeft(7)} ${(secs > 0 ? f(b.frames / secs) : '-').padLeft(6)} '
        '${'${b.late} (${f(100 * b.late / b.frames)}%)'.padLeft(11)}  ${f(b.buildSum / b.frames).padLeft(5)}/${f(b.buildMax).padRight(6)}  ${f(b.rasterSum / b.frames).padLeft(5)}/${f(p95)}/${f(b.rasterMax)}',
      );
    }
    // The battery figure: a screen left alone should draw nothing at all.
    final double total = _clock.elapsedMilliseconds / 1000;
    o
      ..writeln()
      ..writeln(
        'battery: $frames frames in ${total.round()}s = ${(frames / total).toStringAsFixed(2)} per second overall; '
        'the screen was still for ${(100 * (1 - frames / (total * _refresh))).clamp(0, 100).toStringAsFixed(1)}% of the time',
      );
    o
      ..writeln()
      ..writeln('last actions:')
      ..writeln(_events.isEmpty ? '(none)' : _events.join('\n'));
    return o.toString();
  }

  Future<void> copy() {
    final String text = report();
    if (const bool.fromEnvironment('DIAG_PRINT')) {
      // ignore: avoid_print
      print(text); // lets the report be read when testing on a computer
    }
    return Clipboard.setData(ClipboardData(text: text));
  }
}
