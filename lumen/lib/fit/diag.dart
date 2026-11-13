import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

import '../core/glass.dart';
import '../core/settings.dart';

/// Running totals for one place or one action. Adding a frame is a handful
/// of additions; nothing is allocated.
class _Bucket {
  int frames = 0, over = 0, late = 0, times = 0, buildSlow = 0;
  double buildSum = 0, drawSum = 0, worst = 0;
  double firstWorst = 0,
      laterWorst = 0; // the first time something happens is often the slowest
  // The last 512 draw times, overwritten in a circle, for the 95th percentile.
  final Float32List recent = Float32List(512);
  int at = 0;

  void add(double build, double draw, bool overBudget, int lateFrames) {
    frames++;
    buildSum += build;
    drawSum += draw;
    if (build + draw > worst) {
      worst = build + draw;
    }
    if (times <= 1) {
      if (build + draw > firstWorst) {
        firstWorst = build + draw;
      }
    } else if (build + draw > laterWorst) {
      laterWorst = build + draw;
    }
    if (overBudget && build > draw) {
      buildSlow++;
    }
    if (overBudget) {
      over++;
    }
    late += lateFrames;
    recent[at++ & 511] = draw;
  }

  double get p95 {
    final int n = frames < 512 ? frames : 512;
    if (n == 0) {
      return 0;
    }
    final List<double> s = recent.sublist(0, n).toList()..sort();
    return s[((n - 1) * 0.95).round()];
  }
}

/// One step of the guided test: a name and the settings it runs with.
class _Step {
  const _Step(
    this.name,
    this.quality, {
    this.solid = false,
    this.lights = false,
  });
  final String name;
  final GlassQuality quality;
  final bool solid, lights;
}

/// Records how every part of Prism performs, so a report can say which
/// setting, screen and action cost frames. Built to stay out of the way:
/// per frame it does two bucket updates and no string work; text is only
/// made for frames that were actually slow, and for the report itself.
class Diag {
  Diag._();
  static final Diag instance = Diag._();
  static const String build = 'Prism build 10';

  // ---- where the person is
  String _page = 'home', _overlay = '', _extra = '';
  String get page => _page;
  set page(String v) => _move(() => _page = v);
  set overlay(String v) => _move(() => _overlay = v);
  set extra(String v) => _move(() => _extra = v);
  String get scene => '$_page${_page == 'train' ? _extra : ''}$_overlay';

  /// The soft coloured lights behind everything. Off by default.
  final ValueNotifier<bool> wallpaperOn = ValueNotifier<bool>(false);

  // ---- what is being recorded
  String _cfg = 'your settings';
  final Map<String, _Bucket> _scenes = <String, _Bucket>{}; // "setting | scene"
  final Map<String, _Bucket> _actions =
      <String, _Bucket>{}; // "setting | scene > action"
  final Map<String, int> _shownMs = <String, int>{};
  final List<String> _slow = <String>[];
  final List<String> _events = <String>[];
  final Stopwatch _clock = Stopwatch()..start();
  _Bucket? _sceneBucket,
      _actionBucket; // looked up once, then reused every frame
  String _actionName = '';
  int _actionUntil = 0, _since = 0;
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
      // Not on Android.
    }
  }

  void _move(void Function() change) {
    final int now = _clock.elapsedMilliseconds;
    final String k = '$_cfg | $scene';
    _shownMs[k] = (_shownMs[k] ?? 0) + now - _since;
    _since = now;
    change();
    _sceneBucket = null;
  }

  /// Notes something the person did. Frames in the next 0.7 s are charged to it.
  void event(String what) {
    final int now = _clock.elapsedMilliseconds;
    if (_guided) {
      for (final (String k, String _) in _kinds) {
        if (what.startsWith(k)) {
          _did.add(k);
          _coverage[_cfg]?.add(k);
        }
      }
    }
    _actionName = what;
    _actionUntil = now + 700;
    _actionBucket = _actions.putIfAbsent('$_cfg | $scene > $what', _Bucket.new)
      ..times += 1;
    _events.add('${(now / 1000).toStringAsFixed(1)}s $what');
    if (_events.length > 60) {
      _events.removeAt(0);
    }
  }

  void reset() {
    _scenes.clear();
    _actions.clear();
    _shownMs.clear();
    _slow.clear();
    _events.clear();
    _sceneBucket = null;
    _actionBucket = null;
    _actionUntil = 0;
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
    final double budget = 1000 / _refresh, interval = 1e6 / _refresh;
    final _Bucket sb = _sceneBucket ??= _scenes.putIfAbsent(
      '$_cfg | $scene',
      _Bucket.new,
    );
    final int now = _clock.elapsedMilliseconds;
    final _Bucket? ab = now <= _actionUntil ? _actionBucket : null;
    for (final FrameTiming t in timings) {
      final int vsync = t.timestampInMicroseconds(FramePhase.vsyncStart);
      final int? prev = _prevVsync;
      _prevVsync = vsync;
      final double build = t.buildDuration.inMicroseconds / 1000,
          draw = t.rasterDuration.inMicroseconds / 1000;
      int late = 0;
      if (prev != null) {
        final int gap = vsync - prev;
        if (gap > interval * 1.5 && gap < interval * 6) {
          late = ((gap / interval).round() - 1).clamp(1, 5);
        }
      }
      final bool over = build + draw > budget;
      sb.add(build, draw, over, late);
      ab?.add(build, draw, over, late);
      // Only a frame that was really slow costs any text.
      if (build + draw > budget * 1.5) {
        _slow.add(
          '${(now / 1000).toStringAsFixed(1)}s  ${(build + draw).toStringAsFixed(1)} ms '
          '(${build > draw ? 'BUILD ${build.toStringAsFixed(1)}, draw ${draw.toStringAsFixed(1)}' : 'build ${build.toStringAsFixed(1)}, DRAW ${draw.toStringAsFixed(1)}'})  '
          '[$_cfg]  $scene${ab == null ? '' : '  after "$_actionName"'}',
        );
        if (_slow.length > 50) {
          _slow.removeAt(0);
        }
      }
    }
  }

  // ---- the guided test: use the app; the settings change by themselves
  static const List<_Step> _steps = <_Step>[
    _Step('Full glass', GlassQuality.full),
    _Step('Medium glass', GlassQuality.medium),
    _Step('Low glass', GlassQuality.low),
    _Step('No glass', GlassQuality.low, solid: true),
    _Step('Full glass + lights', GlassQuality.full, lights: true),
  ];
  static const int secondsPerStep = int.fromEnvironment(
    'DIAG_STEP',
    defaultValue: 14,
  );
  static int get testSeconds => _steps.length * secondsPerStep;

  /// What the banner says while a test runs; null when none is running.
  final ValueNotifier<String?> banner = ValueNotifier<String?>(null);

  /// Becomes the finished report when a guided test ends.
  final ValueNotifier<String?> finished = ValueNotifier<String?>(null);
  Timer? _timer;
  (GlassQuality, bool, bool)? _saved;

  // What each step should include, so every setting is tested on the same things.
  static const List<(String, String)> _kinds = <(String, String)>[
    ('tab', 'switch tabs'),
    ('blobs', 'open the blobs'),
    ('lens', 'carry the lens'),
    ('sheet', 'open a sheet'),
    ('scroll', 'scroll'),
  ];
  final Set<String> _did = <String>{};
  final Map<String, Set<String>> _coverage = <String, Set<String>>{};
  bool _guided = false;
  String _powerStart = '', _powerEnd = '';
  int _idleFrames = -1;
  static const int _idleSeconds = 8;

  Future<String> _power() async {
    try {
      return await const MethodChannel('lumen/device')
              .invokeMethod<String>('power') ??
          '';
    } catch (_) {
      return '';
    }
  }

  void startGuided() {
    _timer?.cancel();
    _saved = (settings.quality, settings.reduceTransparency, wallpaperOn.value);
    _coverage.clear();
    _idleFrames = -1;
    _powerEnd = '';
    _power().then((String p) => _powerStart = p);
    // Three seconds to put the settings sheet away and get a thumb ready.
    int tick = -3;
    final int active = _steps.length * secondsPerStep;
    void apply() {
      if (tick < 0) {
        banner.value =
            'Guided test starts in ${-tick}\nUse the app as usual; do a bit of everything';
        tick++;
        return;
      }
      if (tick == 0) {
        reset();
        _guided = true;
      }
      if (tick >= active + _idleSeconds) {
        _endGuided();
        return;
      }
      if (tick >= active) {
        // Last step: nobody touches anything. A screen left alone should draw nothing.
        if (tick == active) {
          _restore();
          _move(() => _cfg = 'Idle, hands off');
        }
        banner.value =
            'Hands off the screen  ·  ${active + _idleSeconds - tick} s\nChecking that nothing draws while idle';
        tick++;
        return;
      }
      final int i = tick ~/ secondsPerStep;
      final _Step s = _steps[i];
      if (tick % secondsPerStep == 0) {
        _move(() => _cfg = s.name);
        _did.clear();
        _coverage[s.name] = <String>{};
        settings
          ..quality = s.quality
          ..reduceTransparency = s.solid;
        wallpaperOn.value = s.lights;
      }
      final List<String> todo = <String>[
        for (final (String k, String label) in _kinds)
          if (!_did.contains(k)) label,
      ];
      banner.value =
          'Test ${i + 1} of ${_steps.length}  ·  ${s.name}  ·  ${secondsPerStep - tick % secondsPerStep} s\n${todo.isEmpty ? 'All covered. Keep going.' : 'Still to do: ${todo.join(', ')}'}';
      tick++;
    }

    apply();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => apply());
  }

  void _restore() {
    final (GlassQuality, bool, bool)? s = _saved;
    if (s != null) {
      settings
        ..quality = s.$1
        ..reduceTransparency = s.$2;
      wallpaperOn.value = s.$3;
    }
  }

  Future<void> _endGuided() async {
    _timer?.cancel();
    _guided = false;
    _idleFrames = _scenes.entries
        .where((MapEntry<String, _Bucket> e) => e.key.startsWith('Idle'))
        .fold<int>(
          0,
          (int n, MapEntry<String, _Bucket> e) => n + e.value.frames,
        );
    _powerEnd = await _power();
    final String text = report();
    _restore();
    _move(() => _cfg = 'your settings');
    banner.value = null;
    finished.value = text;
  }

  // ---- remembering the last run, so the next report can say what changed
  File get _memory => File('${Directory.systemTemp.path}/prism_last_run.txt');

  Map<String, List<double>> _previous() {
    try {
      final Map<String, List<double>> out = <String, List<double>>{};
      for (final String line in _memory.readAsLinesSync()) {
        final List<String> p = line.split('|');
        if (p.length == 4) {
          out[p[0]] = <double>[
            double.parse(p[1]),
            double.parse(p[2]),
            double.parse(p[3]),
          ];
        }
      }
      return out;
    } catch (_) {
      return <String, List<double>>{};
    }
  }

  String _previousBuild() {
    try {
      return _memory.readAsLinesSync().first;
    } catch (_) {
      return '';
    }
  }

  // ---- the report
  String report() {
    _move(() {}); // count the time up to this moment
    final FlutterView v = PlatformDispatcher.instance.views.first;
    final double budget = 1000 / _refresh;
    String f(double x) => x.toStringAsFixed(1);
    String pct(int a, int b) =>
        b == 0 ? '-' : '${(100 * a / b).toStringAsFixed(1)}%';
    final StringBuffer o = StringBuffer()
      ..writeln('$build  ·  ${_clock.elapsed.inSeconds}s recorded')
      ..writeln(_device)
      ..writeln(
        'screen ${v.physicalSize.width.round()}x${v.physicalSize.height.round()} @${v.devicePixelRatio}x, ${_refresh.round()} Hz, budget ${f(budget)} ms per frame',
      )
      ..writeln(
        'glass shader ${GlassShaders.available ? 'ok' : 'MISSING'}  ·  ${settings.themeMode == ThemeMode.dark ? 'dark' : 'light'}',
      );

    // 1. Each setting as a whole.
    final Map<String, _Bucket> perCfg = <String, _Bucket>{};
    for (final MapEntry<String, _Bucket> e in _scenes.entries) {
      final _Bucket t = perCfg.putIfAbsent(
        e.key.split(' | ').first,
        _Bucket.new,
      );
      final _Bucket b = e.value;
      t
        ..frames += b.frames
        ..over += b.over
        ..late += b.late
        ..buildSum += b.buildSum
        ..drawSum += b.drawSum;
      if (b.worst > t.worst) {
        t.worst = b.worst;
      }
    }
    o
      ..writeln()
      ..writeln(
        'LATE is what a person can see: a frame that reached the screen after its turn.\n"Over budget" frames took longer than one refresh to make, but usually still arrive on time.\n\nBY SETTING              frames  over budget   late   build avg  draw avg  worst (ms)',
      );
    for (final MapEntry<String, _Bucket> e in perCfg.entries) {
      final _Bucket b = e.value;
      if (b.frames > 0) {
        o.writeln(
          '${e.key.padRight(22)} ${b.frames.toString().padLeft(7)} ${pct(b.over, b.frames).padLeft(12)} ${pct(b.late, b.frames).padLeft(6)} ${f(b.buildSum / b.frames).padLeft(10)} ${f(b.drawSum / b.frames).padLeft(9)} ${f(b.worst).padLeft(9)}',
        );
      }
    }

    // What changed since the last guided run on this phone.
    final Map<String, List<double>> before = _previous();
    if (before.isNotEmpty && _coverage.isNotEmpty) {
      o
        ..writeln()
        ..writeln(
          'SINCE YOUR LAST RUN (${_previousBuild()})    late now (was)     over budget now (was)   draw avg now (was)',
        );
      for (final MapEntry<String, _Bucket> e in perCfg.entries) {
        final List<double>? was = before[e.key];
        final _Bucket b = e.value;
        if (was != null && b.frames > 0) {
          o.writeln(
            '${e.key.padRight(22)} ${'${pct(b.late, b.frames)} (${was[0].toStringAsFixed(1)}%)'.padLeft(24)} ${'${pct(b.over, b.frames)} (${was[1].toStringAsFixed(1)}%)'.padLeft(24)} ${'${f(b.drawSum / b.frames)} (${f(was[2])})'.padLeft(20)}',
          );
        }
      }
    }
    if (_coverage.isNotEmpty) {
      // Was every setting tested on the same things? If not, the comparison above is uneven.
      o
        ..writeln()
        ..writeln('COVERAGE (what each setting was tested on)');
      for (final MapEntry<String, Set<String>> e in _coverage.entries) {
        final List<String> missing = <String>[
          for (final (String k, String label) in _kinds)
            if (!e.value.contains(k)) label,
        ];
        o.writeln(
          '${e.key.padRight(22)} ${missing.isEmpty ? 'everything' : 'MISSING: ${missing.join(', ')}'}',
        );
      }
      o
        ..writeln()
        ..writeln(
          _idleFrames < 0
              ? 'IDLE: not measured'
              : 'IDLE: $_idleFrames frames in $_idleSeconds s with hands off. The test banner itself causes about $_idleSeconds; '
                    '${_idleFrames > _idleSeconds * 3 ? 'MORE than that means something keeps drawing and costs battery.' : 'so nothing else is drawing.'}',
        )
        ..writeln('POWER: start $_powerStart  ·  end $_powerEnd');
      // Remember this run for next time.
      try {
        _memory.writeAsStringSync(
          <String>[
            build,
            for (final MapEntry<String, _Bucket> e in perCfg.entries)
              if (e.value.frames > 0)
                '${e.key}|${(100 * e.value.late / e.value.frames).toStringAsFixed(2)}|${(100 * e.value.over / e.value.frames).toStringAsFixed(2)}|${(e.value.drawSum / e.value.frames).toStringAsFixed(2)}',
          ].join('\n'),
        );
      } catch (_) {
        // No storage: the next report simply has no comparison.
      }
    }

    // 2. The places to fix, worst first.
    final List<MapEntry<String, _Bucket>> acts =
        _actions.entries
            .where((MapEntry<String, _Bucket> e) => e.value.frames > 0)
            .toList()
          ..sort((MapEntry<String, _Bucket> a, MapEntry<String, _Bucket> b) {
            // Late frames are the ones a person sees, so they rank first.
            final int l = b.value.late.compareTo(a.value.late);
            if (l != 0) {
              return l;
            }
            final int c = b.value.over.compareTo(a.value.over);
            return c != 0 ? c : b.value.worst.compareTo(a.value.worst);
          });
    o
      ..writeln()
      ..writeln('WHERE IT STUTTERS, worst first  (setting | screen > action)')
      ..writeln(
        '"1st / later": the worst frame the first time it happened against every time after. A big first and small later means a one-off warm-up.',
      )
      ..writeln(
        '"slow because of": BUILD = working out what to show (my code); DRAW = painting it (glass, shadows, size).',
      )
      ..writeln(
        '                                                    times  frames  LATE  over budget  worst: 1st / later   slow because of   avg build/draw',
      );
    for (final MapEntry<String, _Bucket> e in acts.take(25)) {
      final _Bucket b = e.value;
      o.writeln(
        '${e.key.padRight(52)} ${b.times.toString().padLeft(4)} ${b.frames.toString().padLeft(7)} ${b.late.toString().padLeft(5)} ${'${b.over} (${pct(b.over, b.frames)})'.padLeft(12)} ${'${f(b.firstWorst)} / ${b.times > 1 ? f(b.laterWorst) : '-'}'.padLeft(18)}   ${(b.over == 0 ? '-' : (b.buildSlow * 2 > b.over ? 'BUILD' : 'DRAW')).padRight(16)}  ${f(b.buildSum / b.frames)}/${f(b.drawSum / b.frames)}',
      );
    }
    if (acts.isEmpty) {
      o.writeln('(no actions recorded)');
    }

    // 3. Every screen under every setting.
    o
      ..writeln()
      ..writeln(
        'BY SCREEN (setting | screen)                 shown  frames  per s  over budget  draw avg/p95  worst',
      );
    final List<MapEntry<String, _Bucket>> rows =
        _scenes.entries
            .where((MapEntry<String, _Bucket> e) => e.value.frames > 0)
            .toList()
          ..sort(
            (MapEntry<String, _Bucket> a, MapEntry<String, _Bucket> b) =>
                a.key.compareTo(b.key),
          );
    int frames = 0;
    for (final MapEntry<String, _Bucket> e in rows) {
      final _Bucket b = e.value;
      frames += b.frames;
      final double secs = (_shownMs[e.key] ?? 0) / 1000;
      o.writeln(
        '${e.key.padRight(42)} ${'${secs.round()}s'.padLeft(6)} ${b.frames.toString().padLeft(7)} ${(secs > 0 ? f(b.frames / secs) : '-').padLeft(6)} ${pct(b.over, b.frames).padLeft(12)}  ${f(b.drawSum / b.frames).padLeft(5)}/${f(b.p95).padRight(5)} ${f(b.worst).padLeft(6)}',
      );
    }
    final double total = _clock.elapsedMilliseconds / 1000;
    o
      ..writeln()
      ..writeln(
        'battery: $frames frames in ${total.round()}s; the screen was still ${(100 * (1 - frames / (total * _refresh))).clamp(0, 100).toStringAsFixed(1)}% of the time',
      )
      ..writeln()
      ..writeln(
        'SLOW FRAMES (over 1.5x budget; capitals mark the slower half), newest last:',
      )
      ..writeln(_slow.isEmpty ? '(none)' : _slow.join('\n'))
      ..writeln()
      ..writeln('last actions:')
      ..writeln(_events.isEmpty ? '(none)' : _events.join('\n'));
    return o.toString();
  }

  Future<void> copy([String? text]) {
    final String t = text ?? report();
    if (const bool.fromEnvironment('DIAG_PRINT')) {
      // ignore: avoid_print
      print(t); // lets the report be read when testing on a computer
    }
    return Clipboard.setData(ClipboardData(text: t));
  }
}
