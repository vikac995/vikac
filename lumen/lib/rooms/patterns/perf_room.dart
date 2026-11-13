import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/panel.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';
import '../glass/feed.dart';

class _Result {
  const _Result(this.frames, this.build, this.raster, this.worst, this.missed);
  final int frames;
  final double build, raster, worst;
  final int missed;
}

const List<(String, String, String, String)> _cases =
    <(String, String, String, String)>[
      (
        'Shadows',
        'Forty cards, each with two large blurred shadows.',
        'The same cards with a hairline edge instead.',
        'scroll',
      ),
      (
        'Blur',
        'Fourteen panes, each blurring what is behind it, live.',
        'The same panes as a painted tint.',
        'scroll',
      ),
      (
        'Idle',
        'A badge that pulses for ever.',
        'A badge that pulses twice, then rests.',
        'idle',
      ),
    ];

/// Room 19. The same screen, built the costly way and the cheap way, and
/// measured on this device with the engine's own frame timings.
class PerfRoom extends StatefulWidget {
  const PerfRoom({super.key});

  @override
  State<PerfRoom> createState() => _PerfRoomState();
}

class _PerfRoomState extends State<PerfRoom> {
  int _case = 0;
  bool _cheap = false;
  bool _running = false;
  final Map<String, _Result> _results = <String, _Result>{};
  final ScrollController _list = ScrollController();
  final List<FrameTiming> _timings = <FrameTiming>[];
  int _t0 = 0, _t1 = 0;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _list.dispose();
    super.dispose();
  }

  void _onTimings(List<FrameTiming> t) {
    if (_running) {
      _timings.addAll(t);
    }
  }

  Future<void> _test() async {
    if (_running) {
      return;
    }
    final bool idle = _cases[_case].$4 == 'idle';
    setState(() {
      _running = true;
      _run++; // restarts the badge, so both variants start from the same state
    });
    _timings.clear();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _t0 = developer.Timeline.now;
    if (idle) {
      await Future<void>.delayed(const Duration(seconds: 3));
    } else {
      final double max = _list.position.maxScrollExtent;
      await _list.animateTo(
        max,
        duration: const Duration(milliseconds: 1500),
        curve: Curves.linear,
      );
      await _list.animateTo(
        0,
        duration: const Duration(milliseconds: 1500),
        curve: Curves.linear,
      );
    }
    _t1 = developer.Timeline.now;
    // Timings arrive in batches up to a second later.
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    final double interval =
        1e6 / ui.PlatformDispatcher.instance.views.first.display.refreshRate;
    int frames = 0, missed = 0;
    double build = 0, raster = 0, worst = 0;
    int? prev;
    for (final FrameTiming f in _timings) {
      final int v = f.timestampInMicroseconds(ui.FramePhase.vsyncStart);
      if (v < _t0 || v > _t1) {
        continue;
      }
      frames++;
      build += f.buildDuration.inMicroseconds / 1000;
      raster += f.rasterDuration.inMicroseconds / 1000;
      final double total =
          (f.buildDuration + f.rasterDuration).inMicroseconds / 1000;
      if (total > worst) {
        worst = total;
      }
      if (prev != null && !idle && v - prev > interval * 1.5) {
        missed += ((v - prev) / interval).round() - 1;
      }
      prev = v;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _running = false;
      _results['$_case${_cheap ? 'b' : 'a'}'] = _Result(
        frames,
        frames == 0 ? 0 : build / frames,
        frames == 0 ? 0 : raster / frames,
        worst,
        missed,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final (String name, String costly, String cheap, String kind) =
        _cases[_case];
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 19,
          title: 'Performance lab',
          hint:
              'Pattern: looks the same, costs differently. Pick a case, run the test on the costly build, '
              'switch to the cheap build, run it again, and compare the numbers from this phone.',
        ),
        const SizedBox(height: 16),
        Segmented<int>(
          values: const <int>[0, 1, 2],
          labels: _cases
              .map(((String, String, String, String) x) => x.$1)
              .toList(),
          value: _case,
          onChanged: _running ? (_) {} : (int v) => setState(() => _case = v),
        ),
        const SizedBox(height: 10),
        Segmented<bool>(
          values: const <bool>[false, true],
          labels: const <String>['Costly', 'Cheap'],
          value: _cheap,
          onChanged: _running ? (_) {} : (bool v) => setState(() => _cheap = v),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
          child: Text(
            _cheap ? cheap : costly,
            style: LumenType.text(14, color: c.inkMuted),
          ),
        ),
        Container(
          height: 300,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: c.surface,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(26),
              side: BorderSide(color: c.hairline),
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey<String>('$_case$_cheap$_run'),
            child: _stage(c),
          ),
        ),
        const SizedBox(height: 12),
        Pressable(
          onTap: _running ? null : _test,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: _running ? c.ink.withValues(alpha: 0.1) : c.accent,
              shape: const StadiumBorder(),
            ),
            child: Text(
              _running
                  ? 'Measuring…'
                  : kind == 'idle'
                  ? 'Measure 3 s without touching'
                  : 'Run 3 s scroll test',
              style: LumenType.text(
                15.5,
                weight: 640,
                color: _running ? c.inkFaint : c.onAccent,
                height: 1,
              ),
            ),
          ),
        ),
        const SectionLabel('Results on this device'),
        Panel(
          child: Column(
            children: <Widget>[
              _row(c, name, 'Costly', 'Cheap', head: true),
              _row(
                c,
                'Frames drawn',
                _fmt('a', (_Result r) => '${r.frames}'),
                _fmt('b', (_Result r) => '${r.frames}'),
              ),
              _row(
                c,
                'Build, average',
                _fmt('a', (_Result r) => '${r.build.toStringAsFixed(1)} ms'),
                _fmt('b', (_Result r) => '${r.build.toStringAsFixed(1)} ms'),
              ),
              _row(
                c,
                'Raster, average',
                _fmt('a', (_Result r) => '${r.raster.toStringAsFixed(1)} ms'),
                _fmt('b', (_Result r) => '${r.raster.toStringAsFixed(1)} ms'),
              ),
              _row(
                c,
                'Slowest frame',
                _fmt('a', (_Result r) => '${r.worst.toStringAsFixed(1)} ms'),
                _fmt('b', (_Result r) => '${r.worst.toStringAsFixed(1)} ms'),
              ),
              if (kind != 'idle')
                _row(
                  c,
                  'Missed frames',
                  _fmt('a', (_Result r) => '${r.missed}'),
                  _fmt('b', (_Result r) => '${r.missed}'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: Text(
            kind == 'idle'
                ? 'For Idle, "frames drawn" is the result: every frame costs battery. The readout at the top adds about one frame a second of its own.'
                : 'Raster is the time the GPU side needs per frame. At 120 Hz a frame has about 8 ms in total.',
            style: LumenType.text(13, color: c.inkMuted),
          ),
        ),
      ],
    );
  }

  String _fmt(String v, String Function(_Result) f) {
    final _Result? r = _results['$_case$v'];
    return r == null ? '–' : f(r);
  }

  Widget _row(
    LumenColors c,
    String a,
    String b,
    String d, {
    bool head = false,
  }) {
    final TextStyle s = LumenType.text(
      head ? 12.5 : 14.5,
      weight: head ? 650 : 560,
      color: head ? c.inkFaint : c.ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Text(
              head ? a.toUpperCase() : a,
              style: head ? s : s.copyWith(color: c.inkMuted),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(b, textAlign: TextAlign.right, style: s),
          ),
          Expanded(
            flex: 3,
            child: Text(d, textAlign: TextAlign.right, style: s),
          ),
        ],
      ),
    );
  }

  Widget _stage(LumenColors c) {
    switch (_case) {
      case 0:
        return ListView.builder(
          controller: _list,
          padding: const EdgeInsets.all(16),
          itemCount: 40,
          itemBuilder: (BuildContext context, int i) => Container(
            height: 62,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              borderRadius: BorderRadius.circular(20),
              border: _cheap
                  ? Border.all(color: c.ink.withValues(alpha: 0.10))
                  : null,
              boxShadow: _cheap
                  ? null
                  : const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x55000000),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 40,
                        offset: Offset(0, 18),
                      ),
                    ],
            ),
            child: Text(
              'Card ${i + 1}',
              style: LumenType.text(16, weight: 600, color: c.ink),
            ),
          ),
        );
      case 1:
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CustomPaint(painter: PosterPainter(feeds[0], 1)),
            ListView.builder(
              controller: _list,
              padding: const EdgeInsets.all(16),
              itemCount: 14,
              itemBuilder: (BuildContext context, int i) {
                final Widget label = Container(
                  height: 62,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  color: _cheap
                      ? const Color(0xCC2A2136)
                      : const Color(0x662A2136),
                  child: Text(
                    'Pane ${i + 1}',
                    style: LumenType.text(16, weight: 600, color: Colors.white),
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _cheap
                        ? label
                        : BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: label,
                          ),
                  ),
                );
              },
            ),
          ],
        );
      default:
        return Center(
          child: _Badge(forever: !_cheap, color: c.accent),
        );
    }
  }
}

class _Badge extends StatefulWidget {
  const _Badge({required this.forever, required this.color});
  final bool forever;
  final Color color;

  @override
  State<_Badge> createState() => _BadgeState();
}

class _BadgeState extends State<_Badge> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.forever) {
      _a.repeat(reverse: true);
    } else {
      // Two pulses to say "look here", then nothing more is drawn.
      _a.repeat(reverse: true, count: 4);
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (BuildContext context, Widget? child) {
        final double v = Curves.easeInOut.transform(_a.value);
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              width: 96 + 60 * v,
              height: 96 + 60 * v,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.25 * (1 - v)),
              ),
            ),
            child!,
          ],
        );
      },
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
        child: const Icon(
          Icons.notifications_rounded,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}
