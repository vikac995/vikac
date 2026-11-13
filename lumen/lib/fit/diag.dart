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
  int frames = 0, over = 0, late = 0, gaps = 0, times = 0, buildSlow = 0;
  // How long the screen kept drawing after the action: what it costs the battery.
  double settleSum = 0, settleMax = 0;
  int settleN = 0;
  double buildSum = 0, drawSum = 0, worst = 0;
  double firstWorst = 0,
      laterWorst = 0; // the first time something happens is often the slowest
  // The last 512 draw times, overwritten in a circle, for the 95th percentile.
  final Float32List recent = Float32List(512);
  int at = 0;

  void add(
    double build,
    double draw,
    bool overBudget,
    int lateFrames,
    int gapFrames,
  ) {
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
    gaps += gapFrames;
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

/// A moment something changed: a new screen, a new setting or an action.
/// Frames are matched to marks by their own timestamps, because the engine
/// hands frame times over in batches up to a second late.
class _Mark {
  _Mark(this.at, this.scene, this.label) : drawer = label.contains('+drawer');

  /// Frames with the app drawer up say nothing about whether the phone can afford the glass bar.
  final bool drawer;
  final int at; // microseconds, on the frame clock
  final _Bucket scene;
  final String label;
  _Bucket? action;
  String actionName = '';
  int actionAt = 0;
}

/// One step of the guided test: a name and the settings it runs with.
class _Step {
  const _Step(
    this.name,
    this.quality, {
    // ignore: unused_element_parameter
    this.solid = false,
    // ignore: unused_element_parameter
    this.lights = false,
    this.mode = 0,
  });
  final int mode;
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
  static const String build = 'Prism build 46';

  // ---- where the person is
  String _page = 'home', _overlay = '', _extra = '';
  String get page => _page;
  set page(String v) => _move(() => _page = v);
  set overlay(String v) => _move(() => _overlay = v);
  set extra(String v) => _move(() => _extra = v);
  String get scene => '$_page${_page == 'train' ? _extra : ''}$_overlay';

  /// The soft coloured lights behind everything. On by default: measured, they cost nothing.
  final ValueNotifier<bool> wallpaperOn = ValueNotifier<bool>(true);

  /// How much glass the bar uses. 0 original: always glass. 1 one at a time:
  /// only one moving piece of glass at once. 2 frosted: the bar blurs but does
  /// not bend. 3 event: the bar is solid; only the carried lens and the rest timer are glass.
  /// 4 is automatic: Original while the phone keeps up, Event when it does not.
  final ValueNotifier<int> glassMode = ValueNotifier<int>(4);

  /// What automatic has settled on: 0 Original or 3 Event.
  final ValueNotifier<int> autoLevel = ValueNotifier<int>(0);

  /// The style actually in use.
  int get barMode => glassMode.value == 4 ? autoLevel.value : glassMode.value;
  int _autoDowns = 0, _winFrames = 0, _winOver = 0;
  double _winMs = 0;
  File get _autoFile =>
      File('${Directory.systemTemp.path}/prism_auto_level_v2');

  /// Judged every 480 frames (four seconds of movement at 120 Hz). More than
  /// 15 % of frames over budget on Original means this phone cannot afford the
  /// glass bar. Going back up is tried only with clear headroom, and only once,
  /// so it cannot flip back and forth.
  void _autoJudge(double budget) {
    final double over = _winOver / _winFrames, avg = _winMs / _winFrames;
    _winFrames = 0;
    _winOver = 0;
    _winMs = 0;
    if (glassMode.value != 4 || _guided || banner.value != null) {
      return;
    }
    if (autoLevel.value == 0 && over > 0.15) {
      autoLevel.value = 3;
      _autoDowns++;
      event('auto: stepped down to Event (${(over * 100).round()}% slow)');
    } else if (autoLevel.value == 3 &&
        _autoDowns < 2 &&
        over < 0.02 &&
        avg < budget * 0.45) {
      autoLevel.value = 0;
      event('auto: stepped up to Original');
    } else {
      return;
    }
    try {
      _autoFile.writeAsStringSync('${autoLevel.value} $_autoDowns');
    } catch (_) {
      // No storage: it simply starts from Original next time.
    }
  }

  static const List<String> glassModes = <String>[
    'Original',
    'One at a time',
    'Frosted',
    'Event',
  ];

  // ---- what is being recorded
  String _cfg = 'your settings';
  final Map<String, _Bucket> _scenes = <String, _Bucket>{}; // "setting | scene"
  final Map<String, _Bucket> _actions =
      <String, _Bucket>{}; // "setting | scene > action"
  final Map<String, int> _shownMs = <String, int>{};
  final List<String> _slow = <String>[];
  final List<String> _events = <String>[];
  final Stopwatch _clock = Stopwatch()..start();
  final List<_Mark> _marks = <_Mark>[];
  int _since = 0;
  int _off = 0; // frame clock minus my clock, in microseconds
  bool _prevOver = false, _prevPrevOver = false;
  // The action whose settling is being timed.
  _Bucket? _trk;
  int _trkAt = 0, _trkLast = 0;
  bool _trkDone = true;
  static const int _window =
      700000; // an action owns the frames of the next 0.7 s
  int? _prevVsync;
  String _device = 'unknown device';
  double _refresh = 60;

  Future<void> start() async {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    // Ties my clock to the clock frames are stamped with. One subtraction a frame.
    SchedulerBinding.instance.addPersistentFrameCallback((Duration _) {
      _off =
          SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds -
          _clock.elapsedMicroseconds;
    });
    _mark();
    try {
      final List<String> saved = _autoFile.readAsStringSync().split(' ');
      autoLevel.value = int.parse(saved[0]);
      _autoDowns = int.parse(saved[1]);
    } catch (_) {
      // First run.
    }
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
    _mark();
  }

  int get _nowOnFrameClock => _clock.elapsedMicroseconds + _off;

  /// Starts a new stretch of frames. An action still running carries over.
  _Mark _mark() {
    final _Mark m = _Mark(
      _nowOnFrameClock,
      _scenes.putIfAbsent('$_cfg | $scene', _Bucket.new),
      '[$_cfg]  $scene',
    );
    if (_marks.isNotEmpty) {
      m
        ..action = _marks.last.action
        ..actionName = _marks.last.actionName
        ..actionAt = _marks.last.actionAt;
    }
    _marks.add(m);
    return m;
  }

  void _endSettle() {
    final _Bucket? b = _trk;
    if (b != null && _trkLast > _trkAt) {
      final double ms = (_trkLast - _trkAt) / 1000;
      b
        ..settleSum += ms
        ..settleN += 1;
      if (ms > b.settleMax) {
        b.settleMax = ms;
      }
    }
    _trk = null;
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
    _mark()
      ..action = (_actions.putIfAbsent('$_cfg | $scene > $what', _Bucket.new)
        ..times += 1)
      ..actionName = what
      ..actionAt = _nowOnFrameClock;
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
    _trk = null;
    _since = _clock.elapsedMilliseconds;
    _marks.clear();
    _mark();
  }

  void _onTimings(List<FrameTiming> timings) {
    final Iterable<FlutterView> views = PlatformDispatcher.instance.views;
    if (views.isNotEmpty && views.first.display.refreshRate > 1) {
      _refresh = views.first.display.refreshRate;
    }
    final double budget = 1000 / _refresh, interval = 1e6 / _refresh;
    if (_marks.isEmpty) {
      _mark();
    }
    int mi = 0;
    for (final FrameTiming t in timings) {
      final int vsync = t.timestampInMicroseconds(FramePhase.vsyncStart);
      while (mi + 1 < _marks.length && _marks[mi + 1].at <= vsync) {
        mi++;
      }
      final _Mark m = _marks[mi];
      final _Bucket? ab =
          m.action != null &&
              vsync >= m.actionAt &&
              vsync - m.actionAt <= _window
          ? m.action
          : null;
      final int? prev = _prevVsync;
      _prevVsync = vsync;
      final double build = t.buildDuration.inMicroseconds / 1000,
          draw = t.rasterDuration.inMicroseconds / 1000;
      final bool over = build + draw > budget;
      // A missing refresh is only a stutter if a slow frame caused it.
      // Otherwise there was simply nothing new to draw.
      int late = 0, gap = 0;
      if (prev != null) {
        final int d = vsync - prev;
        if (d > interval * 1.5 && d < interval * 6) {
          final int n = ((d / interval).round() - 1).clamp(1, 5);
          if (_prevOver || _prevPrevOver) {
            late = n;
          } else {
            gap = n;
          }
        }
      }
      _prevPrevOver = _prevOver;
      _prevOver = over;
      m.scene.add(build, draw, over, late, gap);
      totalFrames++;
      totalLate += late;
      if (over) {
        totalOver++;
      }
      if (!m.drawer) {
        _winFrames++;
        _winMs += build + draw;
        if (over) {
          _winOver++;
        }
        if (_winFrames >= 480) {
          _autoJudge(budget);
        }
      }
      ab?.add(build, draw, over, late, gap);
      // How long the screen keeps drawing after an action.
      if (m.action != null && vsync >= m.actionAt) {
        if (m.actionAt != _trkAt || _trk != m.action) {
          _endSettle();
          _trk = m.action;
          _trkAt = m.actionAt;
          _trkLast = m.actionAt;
          _trkDone = false;
        }
        if (!_trkDone) {
          final double slack = _trkLast == _trkAt ? 150000 : interval * 4;
          if (vsync - _trkLast <= slack && vsync - _trkAt < 3000000) {
            _trkLast = vsync;
          } else {
            _trkDone = true;
          }
        }
      }
      // Only a frame that was really slow costs any text.
      if (build + draw > budget * 1.5) {
        _slow.add(
          '${((vsync - _off) / 1e6).toStringAsFixed(1)}s  ${(build + draw).toStringAsFixed(1)} ms '
          '(${build > draw ? 'BUILD ${build.toStringAsFixed(1)}, draw ${draw.toStringAsFixed(1)}' : 'build ${build.toStringAsFixed(1)}, DRAW ${draw.toStringAsFixed(1)}'})  '
          '${m.label}${ab == null ? '' : '  after "${m.actionName}"'}',
        );
        if (_slow.length > 50) {
          _slow.removeAt(0);
        }
      }
    }
    if (mi > 0) {
      _marks.removeRange(0, mi);
    }
  }

  // ---- the guided test: use the app; the settings change by themselves
  static const List<_Step> _steps = <_Step>[
    // Only the one thing that was measured to matter: the bar as glass, and the bar solid.
    // Everything else, the background lights included, is the same in both.
    _Step('Full glass', GlassQuality.full, lights: true),
    _Step('Event', GlassQuality.full, mode: 3, lights: true),
  ];
  static const int secondsPerStep = int.fromEnvironment(
    'DIAG_STEP',
    defaultValue: 14,
  );
  static int get testSeconds =>
      _steps.length * secondsPerStep +
      (_steps.length + 1) * 41 +
      _idleSeconds +
      3;

  /// What the banner says while a test runs; null when none is running.
  final ValueNotifier<String?> banner = ValueNotifier<String?>(null);

  /// Becomes the finished report when a guided test ends.
  final ValueNotifier<String?> finished = ValueNotifier<String?>(null);
  (GlassQuality, bool, bool, int)? _saved;

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

  /// The app driving itself: set by the shell, which knows where things are on screen.
  /// Running totals since the app started, for the diary.
  int totalFrames = 0, totalOver = 0, totalLate = 0;

  /// More text for the end of the report, supplied by whoever has it.
  String Function()? tail;

  /// The action that has cost the most late frames so far, in a few words.
  String worstAction() {
    MapEntry<String, _Bucket>? worst;
    for (final MapEntry<String, _Bucket> e in _actions.entries) {
      if (e.value.late > 0 &&
          (worst == null || e.value.late > worst.value.late)) {
        worst = e;
      }
    }
    return worst == null
        ? ''
        : '${worst.key.split(' | ').last} (${worst.value.late} late)';
  }

  Future<void> Function()? autoScript;

  /// One extra line for the top of the report, supplied by whoever knows it.
  String Function()? extraLine;

  /// Called with true when a test starts and false when it ends, so the
  /// blob menu can show Prism's own actions while the robot is tapping it.
  void Function(bool testing)? onTest;
  int _run = 0;

  void _apply(_Step s) {
    settings
      ..quality = s.quality
      ..reduceTransparency = s.solid;
    wallpaperOn.value = s.lights;
    glassMode.value = s.mode;
  }

  /// One test, two halves. First the app drives itself through the same
  /// script under every setting, so builds can be compared exactly. Then a
  /// person uses it under every setting, which is the data that matters.
  Future<void> startGuided() async {
    final int run = ++_run;
    bool live() => run == _run;
    Future<void> second() => Future<void>.delayed(const Duration(seconds: 1));
    _saved = (
      settings.quality,
      settings.reduceTransparency,
      wallpaperOn.value,
      glassMode.value,
    );
    onTest?.call(true);
    _coverage.clear();
    _idleFrames = -1;
    _powerEnd = '';
    _power().then((String p) => _powerStart = p);
    for (int n = 3; n > 0 && live(); n--) {
      banner.value = 'Test starts in $n\nPart 1 is automatic: hands off';
      await second();
    }
    // Part 1: the app drives itself. One pass first that is not recorded,
    // so one-off warm-up costs do not land on whichever setting runs first.
    if (autoScript != null) {
      _apply(_steps.first);
      banner.value =
          'Part 1 of 2  ·  warming up\nHands off: the app is driving itself';
      await autoScript!();
    }
    reset();
    if (autoScript != null) {
      for (int i = 0; i < _steps.length && live(); i++) {
        _move(() => _cfg = 'auto ${_steps[i].name}');
        _apply(_steps[i]);
        banner.value =
            'Part 1 of 2  ·  automatic ${i + 1} of ${_steps.length}  ·  ${_steps[i].name}\nHands off: the app is driving itself';
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await autoScript!();
      }
    }
    if (!live()) {
      return;
    }
    // In between: nobody touches anything. A screen left alone should draw nothing.
    _restore();
    _move(() => _cfg = 'Idle, hands off');
    for (int n = _idleSeconds; n > 0 && live(); n--) {
      banner.value =
          'Still hands off  ·  $n s\nChecking that nothing draws while idle';
      await second();
    }
    _idleFrames = _scenes.entries
        .where((MapEntry<String, _Bucket> e) => e.key.startsWith('Idle'))
        .fold<int>(
          0,
          (int n, MapEntry<String, _Bucket> e) => n + e.value.frames,
        );
    // Part 2: a person.
    _guided = true;
    for (int i = 0; i < _steps.length && live(); i++) {
      final _Step s = _steps[i];
      _move(() => _cfg = 'you ${s.name}');
      _did.clear();
      _coverage[_cfg] = <String>{};
      _apply(s);
      for (int n = secondsPerStep; n > 0 && live(); n--) {
        final List<String> todo = <String>[
          for (final (String k, String label) in _kinds)
            if (!_did.contains(k)) label,
        ];
        banner.value =
            'Part 2 of 2  ·  your turn ${i + 1} of ${_steps.length}  ·  ${s.name}  ·  $n s\n${todo.isEmpty ? 'All covered. Keep using it.' : 'Still to do: ${todo.join(', ')}'}';
        await second();
      }
    }
    if (live()) {
      await _endGuided();
    }
  }

  void _restore() {
    final (GlassQuality, bool, bool, int)? s = _saved;
    if (s != null) {
      settings
        ..quality = s.$1
        ..reduceTransparency = s.$2;
      wallpaperOn.value = s.$3;
      glassMode.value = s.$4;
    }
  }

  Future<void> _endGuided() async {
    _guided = false;
    onTest?.call(false);
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
        'glass shader ${GlassShaders.available ? 'ok' : 'MISSING'}  ·  ${settings.themeMode == ThemeMode.dark ? 'dark' : 'light'}  ·  glass style ${glassMode.value == 4 ? 'Auto, using ${autoLevel.value == 0 ? 'Original' : 'Event'}, stepped down $_autoDowns times' : glassModes[glassMode.value]}',
      );

    if (extraLine != null) {
      o.writeln(extraLine!());
    }

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
        'LATE is what a person can see: a refresh that was missed because the frame before it was slow.\n"Over budget" frames took longer than one refresh to make, but usually still arrive on time.\n\nBY SETTING              frames  over budget   late   build avg  draw avg  worst (ms)',
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

    _endSettle();
    // 1b. The same actions side by side: one row per action, one column per setting.
    String kind(String a) => a.startsWith('tab ')
        ? 'tab switch'
        : a.startsWith('lens on ')
        ? 'lens over a card'
        : a == 'sheet close' || !a.startsWith('sheet ')
        ? a
        : 'sheet open';
    for (final String who in <String>['auto', 'you']) {
      final Map<String, Map<String, _Bucket>> grid =
          <String, Map<String, _Bucket>>{};
      for (final MapEntry<String, _Bucket> e in _actions.entries) {
        final String cfg = e.key.split(' | ').first;
        if (!cfg.startsWith('$who ')) {
          continue;
        }
        final _Bucket b = e.value;
        final _Bucket t = grid
            .putIfAbsent(
              kind(e.key.split(' > ').last),
              () => <String, _Bucket>{},
            )
            .putIfAbsent(cfg.substring(who.length + 1), _Bucket.new);
        t
          ..frames += b.frames
          ..over += b.over
          ..late += b.late
          ..times += b.times
          ..settleSum += b.settleSum
          ..settleN += b.settleN;
        if (b.worst > t.worst) {
          t.worst = b.worst;
        }
      }
      if (grid.isEmpty) {
        continue;
      }
      o
        ..writeln()
        ..writeln(
          '${who == 'auto' ? 'ROBOT' : 'YOU'}, ACTION BY SETTING   each cell: times done / late frames / slow % / worst ms / ms it kept drawing',
        )
        ..writeln(
          '${''.padRight(18)}${_steps.map((_Step s) => s.name.padRight(27)).join()}',
        );
      for (final String a in grid.keys.toList()..sort()) {
        o.writeln(
          '${a.padRight(18)}${_steps.map((_Step s) {
            final _Bucket? b = grid[a]![s.name];
            return (b == null || b.frames == 0 ? '-' : '${b.times}x ${b.late} ${pct(b.over, b.frames)} ${f(b.worst)} ${b.settleN == 0 ? '-' : (b.settleSum / b.settleN).round()}').padRight(27);
          }).join()}',
        );
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
    if (tail != null) {
      o.write(tail!());
    }
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
