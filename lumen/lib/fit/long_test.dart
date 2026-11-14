import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'diag.dart';

/// What the long test writes down as it goes, and the report it makes of it.
///
/// The test itself is the shell's: it knows where things are on the screen. This keeps the
/// three kinds of record. A check is something that must be true after a step, and is either
/// right or wrong. A scene is a stretch of Prism's own screen moving, with how every frame of
/// it was made. A phase is a minute of nothing being touched, with what the battery, the
/// processor and the floating lens did meanwhile.
class TestRun {
  TestRun() {
    SchedulerBinding.instance.addTimingsCallback(_took);
    final FlutterView v = PlatformDispatcher.instance.views.first;
    final double hz = v.display.refreshRate;
    budget = 1000 / (hz > 1 ? hz : 60);
  }

  static const MethodChannel _device = MethodChannel('lumen/device');
  final Stopwatch clock = Stopwatch()..start();
  final List<FrameTiming> _frames = <FrameTiming>[];
  final List<(String, bool, String)> checks = <(String, bool, String)>[];
  final List<(String, List<FrameTiming>, int)> scenes =
      <(String, List<FrameTiming>, int)>[];
  final List<(String, Map<String, Object?>)> lensRuns =
      <(String, Map<String, Object?>)>[];
  final List<(String, Map<String, Object?>, int, bool)> phases =
      <(String, Map<String, Object?>, int, bool)>[];
  final List<String> notes = <String>[];

  /// How long one refresh of the screen is, in thousandths of a second.
  late final double budget;

  void _took(List<FrameTiming> t) => _frames.addAll(t);

  void close() => SchedulerBinding.instance.removeTimingsCallback(_took);

  void check(String what, bool ok, [String note = '']) {
    checks.add((what, ok, note));
    Diag.instance.event('test ${ok ? 'ok' : 'WRONG'}: $what');
  }

  void note(String what) => notes.add(what);

  /// Asks Android's side of the test for one thing. It never throws: with no answer, the
  /// answer says so.
  Future<Map<String, Object?>> lens(
    Map<String, Object?> ask, {
    int extraMs = 0,
  }) async {
    try {
      final Map<Object?, Object?>? told = await _device
          .invokeMethod<Map<Object?, Object?>>('lensTest', ask)
          .timeout(Duration(milliseconds: 20000 + extraMs));
      return <String, Object?>{
        for (final MapEntry<Object?, Object?> e
            in (told ?? <Object?, Object?>{}).entries)
          '${e.key}': e.value,
      };
    } catch (e) {
      return <String, Object?>{'ok': false, 'note': 'no answer ($e)'};
    }
  }

  /// Frames are handed over about once a second, so a pause either side of a stretch keeps
  /// its frames apart from the next one's.
  Future<void> _settle() =>
      Future<void>.delayed(const Duration(milliseconds: 1300));

  /// Runs [body] and keeps every frame Prism made while it ran.
  Future<void> scene(String name, Future<void> Function() body) async {
    await _settle();
    final int from = _frames.length;
    final Stopwatch took = Stopwatch()..start();
    try {
      await body();
    } catch (e) {
      check('$name: ran without an error', false, '$e');
    }
    final int ms = took.elapsedMilliseconds;
    await _settle();
    scenes.add((name, _frames.sublist(from), ms));
  }

  /// Something done to the floating lens, as Android reported it.
  void lensRun(String name, Map<String, Object?> told) {
    lensRuns.add((name, told));
    if (told['ok'] != true) {
      check('$name: Android could do it', false, '${told['note']}');
    }
  }

  /// A stretch of nothing being touched, in Prism or with another app in front.
  Future<void> phase(String name, int seconds, {bool away = false}) async {
    await _settle();
    final int from = _frames.length;
    final Map<String, Object?> told = await lens(<String, Object?>{
      'op': away ? 'away' : 'measure',
      'ms': seconds * 1000,
    }, extraMs: seconds * 1000 + 15000);
    await _settle();
    phases.add((name, told, _frames.length - from, away));
    if (told['ok'] != true) {
      check('$name: measured', false, '${told['note']}');
    } else if (away) {
      check('$name: Settings came to the front', told['away'] == true);
      check('$name: Prism came back afterwards', told['back'] == true);
    }
  }

  static double _num(Object? v) => v is num ? v.toDouble() : 0;
  static String _f(double x, [int d = 1]) => x.toStringAsFixed(d);

  /// The current readings of a phase as milliamps drawn: phones disagree on the unit and on
  /// the sign, so the size is what counts.
  static List<double> _milliamps(Object? raw) {
    final List<double> v = <double>[
      for (final Object? o in raw is List ? raw : const <Object?>[])
        _num(o).abs(),
    ];
    if (v.isEmpty) {
      return v;
    }
    final List<double> s = <double>[...v]..sort();
    final bool micro = s[s.length ~/ 2] > 20000;
    return <double>[for (final double x in v) micro ? x / 1000 : x];
  }

  static (double, double) _meanSd(List<double> v) {
    if (v.isEmpty) {
      return (0, 0);
    }
    final double m = v.reduce((double a, double b) => a + b) / v.length;
    final double s = math.sqrt(
      v
              .map((double x) => (x - m) * (x - m))
              .reduce((double a, double b) => a + b) /
          v.length,
    );
    return (m, s);
  }

  String report(List<String> head) {
    final StringBuffer o = StringBuffer();
    for (final String h in head) {
      o.writeln(h);
    }
    final int wrong = checks.where(((String, bool, String) c) => !c.$2).length;
    o
      ..writeln(
        'took ${clock.elapsed.inMinutes} min ${clock.elapsed.inSeconds % 60} s  ·  one refresh is ${_f(budget)} ms',
      )
      ..writeln()
      ..writeln(
        'CHECKS: ${checks.length - wrong} right, $wrong wrong, of ${checks.length}',
      );
    for (final (String what, bool ok, String note) in checks) {
      if (!ok) {
        o.writeln('  WRONG  $what${note.isEmpty ? '' : '  [$note]'}');
      }
    }
    for (final (String what, bool ok, String note) in checks) {
      if (ok) {
        o.writeln('  ok     $what${note.isEmpty ? '' : '  [$note]'}');
      }
    }

    // Prism's own screen.
    o
      ..writeln()
      ..writeln(
        'PRISM, frame by frame. "late" is a refresh that was missed while things were moving, which is what can be seen.',
      )
      ..writeln(
        '${'what'.padRight(46)} frames  late  over  build avg/max  draw avg/max   took',
      );
    for (final (String name, List<FrameTiming> fs, int ms) in scenes) {
      if (fs.isEmpty) {
        o.writeln('${name.padRight(46)}      0');
        continue;
      }
      final List<FrameTiming> sorted = <FrameTiming>[...fs]
        ..sort(
          (FrameTiming a, FrameTiming b) => a
              .timestampInMicroseconds(FramePhase.vsyncStart)
              .compareTo(b.timestampInMicroseconds(FramePhase.vsyncStart)),
        );
      int late = 0, over = 0;
      double bSum = 0, bMax = 0, rSum = 0, rMax = 0;
      for (int i = 0; i < sorted.length; i++) {
        final double b = sorted[i].buildDuration.inMicroseconds / 1000,
            r = sorted[i].rasterDuration.inMicroseconds / 1000;
        bSum += b;
        rSum += r;
        bMax = math.max(bMax, b);
        rMax = math.max(rMax, r);
        if (b + r > budget) {
          over++;
        }
        if (i > 0) {
          final double gap =
              (sorted[i].timestampInMicroseconds(FramePhase.vsyncStart) -
                  sorted[i - 1].timestampInMicroseconds(
                    FramePhase.vsyncStart,
                  )) /
              1000;
          if (gap > budget * 1.6 && gap < 120) {
            late++;
          }
        }
      }
      final int n = sorted.length;
      o.writeln(
        '${name.padRight(46)} ${'$n'.padLeft(6)} ${'$late'.padLeft(5)} ${'$over'.padLeft(5)}  ${'${_f(bSum / n)}/${_f(bMax)}'.padLeft(13)}  ${'${_f(rSum / n)}/${_f(rMax)}'.padLeft(12)}  ${'${_f(ms / 1000)} s'.padLeft(6)}',
      );
    }

    // The floating lens.
    if (lensRuns.isNotEmpty) {
      o
        ..writeln()
        ..writeln(
          'THE FLOATING LENS. How evenly Android drew it while each thing was done to it. This is when it was drawn, which is not proof of when the screen showed it.',
        )
        ..writeln('${'what'.padRight(46)} drawn   gaps  usual gap  worst gap');
      for (final (String name, Map<String, Object?> m) in lensRuns) {
        o.writeln(
          '${name.padRight(46)} ${'${m['frames'] ?? '-'}'.padLeft(5)} ${'${m['late'] ?? '-'}'.padLeft(6)}  ${(m['usualMs'] == null ? '-' : '${_f(_num(m['usualMs']))} ms').padLeft(9)}  ${(m['worstMs'] == null ? '-' : '${_f(_num(m['worstMs']))} ms').padLeft(9)}${m['ok'] == true ? '' : '   NOT DONE: ${m['note']}'}',
        );
      }
    }

    // Power.
    if (phases.isNotEmpty) {
      o
        ..writeln()
        ..writeln(
          'POWER, with nothing being touched. The current is the whole phone\'s, screen included, and wanders by itself: only a difference clearly larger than the "±" means anything. The processor figure is Prism\'s alone and is the steadier one.',
        )
        ..writeln(
          '${'what'.padRight(52)} current mA (±)   Prism processor   Prism frames/s   lens drawn/s',
        );
      for (final (String name, Map<String, Object?> m, int frames, bool _)
          in phases) {
        final List<double> ma = _milliamps(m['current']);
        final (double mean, double sd) = _meanSd(ma);
        final double secs = math.max(1, _num(m['ms']) / 1000);
        o.writeln(
          '${name.padRight(52)} ${'${_f(mean, 0)} (±${_f(sd, 0)})'.padLeft(14)}   ${'${_f(_num(m['cpuMs']) / secs / 10, 2)}% of a core'.padLeft(15)}   ${_f(frames / secs, 2).padLeft(14)}   ${_f(_num(m['lensDraws']) / secs, 2).padLeft(12)}${m['plugged'] == true ? '   (charging: current means nothing)' : ''}',
        );
      }
      final Map<String, Object?> last = phases.last.$2;
      o.writeln(
        'battery ${last['level']}%  ·  ${_f(_num(last['temp']) / 10)} °C  ·  brightness setting ${last['bright']}',
      );
    }
    if (notes.isNotEmpty) {
      o
        ..writeln()
        ..writeln('NOTES');
      for (final String n in notes) {
        o.writeln('  $n');
      }
    }
    return o.toString();
  }

  /// Keeps the report where it can be found again if the screen showing it is closed.
  static void keep(String text) {
    try {
      final Directory files = Directory(
        '${Directory.systemTemp.parent.path}/files',
      );
      File(
        '${files.existsSync() ? files.path : Directory.systemTemp.path}/prism_long_test.txt',
      ).writeAsStringSync(text);
    } catch (_) {
      // Not kept: it is still on the screen and can be copied from there.
    }
  }
}
