import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/panel.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';

/// Room 22. A rest timer done the battery-friendly way: it stores when it
/// ends (not how long is left), redraws once a second, and stays reachable
/// as a small pill when you scroll away.
class TimerRoom extends StatefulWidget {
  const TimerRoom({super.key});

  @override
  State<TimerRoom> createState() => _TimerRoomState();
}

class _TimerRoomState extends State<TimerRoom> with TickerProviderStateMixin {
  DateTime? _end; // running: when it ends
  Duration? _paused; // paused: what was left
  Duration _total = const Duration(seconds: 60);
  bool _done = false;
  Timer? _tick;
  final ScrollController _scroll = ScrollController();
  late final SpringValue _ring = SpringValue(
    this,
    value: 1,
    spring: Motions.spatial,
  );
  late final SpringValue _pill = SpringValue(this, spring: Motions.expressive);
  late final SpringValue _check = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );

  bool get _running => _end != null;
  bool get _active => _end != null || _paused != null;

  Duration get _left {
    if (_paused != null) {
      return _paused!;
    }
    if (_end == null) {
      return Duration.zero;
    }
    final Duration d = _end!.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncPill);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    _ring.dispose();
    _pill.dispose();
    _check.dispose();
    super.dispose();
  }

  void _syncPill() => _pill.animateTo(
    _active && _scroll.hasClients && _scroll.offset > 250 ? 1 : 0,
  );

  void _start(Duration d) {
    setState(() {
      _total = d;
      _end = DateTime.now().add(d);
      _paused = null;
      _done = false;
    });
    _check.animateTo(0);
    _ring.jumpTo(1);
    _schedule();
    Haptics.tick();
  }

  /// Wakes exactly when the displayed second changes, then once a second.
  void _schedule() {
    _tick?.cancel();
    final int ms = _left.inMilliseconds;
    final int toNext = ms % 1000 == 0 ? 1000 : ms % 1000;
    _tick = Timer(Duration(milliseconds: toNext), _onSecond);
  }

  void _onSecond() {
    if (!_running) {
      return;
    }
    final Duration left = _left;
    setState(() {});
    _ring.animateTo(left.inMilliseconds / _total.inMilliseconds);
    if (left.inMilliseconds <= 0) {
      setState(() {
        _end = null;
        _done = true;
      });
      _check.animateTo(1);
      Haptics.thud();
      Timer(const Duration(milliseconds: 220), Haptics.thud);
      _syncPill();
      return;
    }
    _tick = Timer(const Duration(seconds: 1), _onSecond);
  }

  void _pauseResume() {
    setState(() {
      if (_running) {
        _paused = _left;
        _end = null;
        _tick?.cancel();
      } else if (_paused != null) {
        _end = DateTime.now().add(_paused!);
        _paused = null;
        _schedule();
      }
    });
    Haptics.tick();
  }

  void _add(int seconds) {
    if (!_active) {
      return;
    }
    setState(() {
      final Duration d = Duration(
        seconds: math.max(1, _left.inSeconds + seconds),
      );
      if (d > _total) {
        _total = d;
      }
      if (_running) {
        _end = DateTime.now().add(d);
        _schedule();
      } else {
        _paused = d;
      }
    });
    _ring.animateTo(_left.inMilliseconds / _total.inMilliseconds);
    Haptics.tick();
  }

  void _stop() {
    _tick?.cancel();
    setState(() {
      _end = null;
      _paused = null;
      _done = false;
    });
    _ring.animateTo(1);
    _check.animateTo(0);
    _syncPill();
  }

  String _fmt(Duration d) {
    final int s = (d.inMilliseconds / 1000).ceil();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          ListView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              safe.top + 44,
              16,
              safe.bottom + 32,
            ),
            children: <Widget>[
              const RoomHeader(
                number: 22,
                title: 'Timers',
                hint:
                    'Pattern: a countdown stores the moment it ends, so it is right even if the app was closed. '
                    'It redraws once a second, not sixty times. Start one, then scroll down.',
              ),
              const SizedBox(height: 18),
              Panel(
                child: Column(
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 230,
                      child: ListenableBuilder(
                        listenable: Listenable.merge(<Listenable>[
                          _ring,
                          _check,
                        ]),
                        builder: (BuildContext context, Widget? _) =>
                            CustomPaint(
                              painter: _RingPainter(
                                _ring.value,
                                _done ? const Color(0xFF2FA84F) : c.accent,
                                c.ink.withValues(alpha: 0.1),
                              ),
                              child: Center(
                                child: _done
                                    ? Transform.scale(
                                        scale: _check.value,
                                        child: const Icon(
                                          Icons.check_rounded,
                                          size: 96,
                                          color: Color(0xFF2FA84F),
                                        ),
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Text(
                                            _active
                                                ? _fmt(_left)
                                                : _fmt(_total),
                                            textScaler: TextScaler.noScaling,
                                            style: LumenType.display(
                                              64,
                                              weight: 680,
                                              color: c.ink,
                                              height: 1,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _running
                                                ? 'Ends at ${_clock(_end!)}'
                                                : _paused != null
                                                ? 'Paused'
                                                : 'Rest',
                                            style: LumenType.text(
                                              13.5,
                                              color: c.inkMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!_active)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          for (final int s in <int>[30, 60, 90, 120])
                            _chip(
                              c,
                              '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
                              () => _start(Duration(seconds: s)),
                              primary: s == 60,
                            ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _chip(c, '−15 s', () => _add(-15)),
                          const SizedBox(width: 8),
                          _chip(
                            c,
                            _running ? 'Pause' : 'Resume',
                            _pauseResume,
                            primary: true,
                          ),
                          const SizedBox(width: 8),
                          _chip(c, '+15 s', () => _add(15)),
                          const SizedBox(width: 8),
                          _chip(c, 'Stop', _stop),
                        ],
                      ),
                  ],
                ),
              ),
              const SectionLabel(
                'Keep scrolling',
                detail: 'The timer follows you as a pill. Tap the pill to come back.',
              ),
              for (int i = 1; i <= 9; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: c.ink.withValues(alpha: 0.07),
                            shape: const CircleBorder(),
                          ),
                          child: Text(
                            '$i',
                            style: LumenType.text(
                              15,
                              weight: 650,
                              color: c.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            <String>[
                              'Deadlift',
                              'Pull-up',
                              'Dumbbell row',
                              'Face pull',
                              'Preacher curl',
                              'Hammer curl',
                              'Plank',
                              'Hang',
                              'Stretch',
                            ][i - 1],
                            style: LumenType.text(
                              16,
                              weight: 600,
                              color: c.ink,
                            ),
                          ),
                        ),
                        Text(
                          '3 × ${6 + i}',
                          style: LumenType.text(14, color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Positioned(
            top: safe.top + 44,
            left: 0,
            right: 0,
            child: ListenableBuilder(
              listenable: _pill,
              builder: (BuildContext context, Widget? child) {
                final double v = _pill.value;
                if (v < 0.01) {
                  return const SizedBox.shrink();
                }
                return Center(
                  child: Opacity(
                    opacity: v.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -30 * (1 - v)),
                      child: Transform.scale(
                        scale: 0.8 + 0.2 * v,
                        child: child,
                      ),
                    ),
                  ),
                );
              },
              child: GestureDetector(
                onTap: () => _scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                ),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.only(left: 10, right: 16),
                  decoration: const ShapeDecoration(
                    color: Colors.black,
                    shape: StadiumBorder(),
                    shadows: <BoxShadow>[
                      BoxShadow(
                        color: Color(0x55000000),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox.square(
                        dimension: 24,
                        child: ListenableBuilder(
                          listenable: _ring,
                          builder: (BuildContext context, Widget? _) =>
                              CustomPaint(
                                painter: _RingPainter(
                                  _ring.value,
                                  const Color(0xFFFF9F0A),
                                  const Color(0x44FF9F0A),
                                  width: 3.5,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _paused != null
                            ? 'Paused ${_fmt(_left)}'
                            : 'Rest ${_fmt(_left)}',
                        style: LumenType.text(
                          15,
                          weight: 650,
                          color: const Color(0xFFFF9F0A),
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    LumenColors c,
    String label,
    VoidCallback onTap, {
    bool primary = false,
  }) {
    return Pressable(
      onTap: onTap,
      scale: 0.93,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: primary ? c.accent : c.ink.withValues(alpha: 0.08),
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: LumenType.text(
            15,
            weight: 640,
            color: primary ? c.onAccent : c.ink,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.v, this.color, this.track, {this.width = 12});
  final double v;
  final Color color;
  final Color track;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = (Offset.zero & size).deflate(width / 2);
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    if (v > 0.001) {
      canvas.drawArc(
        r,
        -math.pi / 2,
        math.pi * 2 * v.clamp(0.0, 1.0),
        false,
        p..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.v != v || old.color != color || old.track != track;
}
