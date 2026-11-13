import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/shapes.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/panel.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';
import '../details/small_things.dart';

/// Room 35. Moments of reward. Each one is short, earns its place, and ends:
/// nothing here keeps moving once it has made its point.
class CelebrateRoom extends StatefulWidget {
  const CelebrateRoom({super.key});

  @override
  State<CelebrateRoom> createState() => _CelebrateRoomState();
}

class _CelebrateRoomState extends State<CelebrateRoom>
    with TickerProviderStateMixin {
  // Personal best
  int _best = 120;
  late final SpringValue _medal = SpringValue(this, spring: Motions.expressive);
  final ValueNotifier<double> _burst = ValueNotifier<double>(1);
  late final Ticker _burstTicker = createTicker((Duration e) {
    final double t = e.inMilliseconds / 1500;
    _burst.value = t.clamp(0.0, 1.0);
    if (t >= 1) {
      _burstTicker.stop();
    }
  });
  int _seed = 1;

  // Streak
  int _streak = 4;
  late final List<SpringValue> _days = <SpringValue>[
    for (int i = 0; i < 7; i++)
      SpringValue(this, value: i < 4 ? 1 : 0, spring: Motions.expressiveFast),
  ];

  // Goal ring
  late final SpringValue _ring = SpringValue(
    this,
    value: 0.62,
    spring: Motions.expressiveSlow,
  );
  late final SpringValue _ringDone = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  final List<Timer> _timers = <Timer>[];

  @override
  void dispose() {
    for (final Timer t in _timers) {
      t.cancel();
    }
    _burstTicker.dispose();
    _burst.dispose();
    for (final SpringValue s in <SpringValue>[
      _medal,
      _ring,
      _ringDone,
      ..._days,
    ]) {
      s.dispose();
    }
    super.dispose();
  }

  void _newBest() {
    setState(() {
      _best += 5;
      _seed++;
    });
    _medal.jumpTo(0);
    _medal.animateTo(1);
    _burstTicker
      ..stop()
      ..start();
    // Haptics follow the picture: a thud for the pop, then three light ticks.
    Haptics.thud();
    for (int i = 1; i <= 3; i++) {
      _timers.add(Timer(Duration(milliseconds: 120 * i), Haptics.tick));
    }
  }

  void _nextDay() {
    if (_streak >= 7) {
      setState(() => _streak = 0);
      for (final SpringValue d in _days) {
        d.animateTo(0, spring: Motions.spatialFast);
      }
      return;
    }
    _days[_streak].onSettle = Haptics.tick;
    _days[_streak].animateTo(1);
    setState(() => _streak++);
    if (_streak == 7) {
      _timers.add(Timer(const Duration(milliseconds: 260), Haptics.thud));
    }
  }

  void _closeRing() {
    if (_ring.target >= 1) {
      _ring.animateTo(0.62, spring: Motions.spatial);
      _ringDone.animateTo(0, spring: Motions.spatialFast);
      return;
    }
    _ring.onSettle = () {
      if (_ring.target >= 1) {
        _ringDone.animateTo(1);
        Haptics.thud();
      }
    };
    _ring.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    const Color gold = Color(0xFFF5B301);
    Widget action(String label, VoidCallback onTap) => Pressable(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: c.accent.withValues(alpha: 0.16),
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: LumenType.text(15, weight: 650, color: c.accent, height: 1),
        ),
      ),
    );
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 35,
          title: 'Celebrate',
          hint: 'Pattern: reward the moment, briefly. Each of these runs for about a second and then the screen is still again.',
        ),
        const SectionLabel('Personal best'),
        Panel(
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 170,
                child: ListenableBuilder(
                  listenable: Listenable.merge(<Listenable>[_medal, _burst]),
                  builder: (BuildContext context, Widget? _) => CustomPaint(
                    painter: _Confetti(_burst.value, _seed),
                    child: Center(
                      child: Transform.scale(
                        scale: 0.7 + 0.3 * _medal.value,
                        child: Transform.rotate(
                          angle: (1 - _medal.value) * -0.5,
                          child: SizedBox.square(
                            dimension: 112,
                            child: CustomPaint(
                              painter: _Medal(gold),
                              child: const Center(
                                child: Icon(
                                  Icons.emoji_events_rounded,
                                  size: 46,
                                  color: Color(0xFF5A3E00),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Odometer(
                    value: _best,
                    digits: 3,
                    style: LumenType.display(
                      48,
                      weight: 720,
                      color: c.ink,
                      height: 1.1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 6),
                    child: Text(
                      'kg deadlift',
                      style: LumenType.text(15, color: c.inkMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              action('Lift 5 kg more', _newBest),
            ],
          ),
        ),
        const SectionLabel('Streak'),
        Panel(
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (int i = 0; i < 7; i++)
                    Column(
                      children: <Widget>[
                        ListenableBuilder(
                          listenable: _days[i],
                          builder: (BuildContext context, Widget? _) {
                            final double v = _days[i].value;
                            return Transform.scale(
                              scale: 0.8 + 0.2 * v,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: ShapeDecoration(
                                  color: Color.lerp(
                                    c.ink.withValues(alpha: 0.08),
                                    _streak == 7 ? gold : c.accent,
                                    v.clamp(0.0, 1.0),
                                  ),
                                  shape: const CircleBorder(),
                                ),
                                child: Transform.scale(
                                  scale: v.clamp(0.0, 1.2),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 20,
                                    color: _streak == 7
                                        ? const Color(0xFF5A3E00)
                                        : c.onAccent,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'MTWTFSS'[i],
                          style: LumenType.text(
                            12,
                            weight: 600,
                            color: c.inkMuted,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _streak == 7
                    ? 'A full week. That is the whole point.'
                    : '$_streak of 7 days',
                style: LumenType.text(
                  15,
                  weight: 620,
                  color: _streak == 7 ? gold : c.ink,
                ),
              ),
              const SizedBox(height: 12),
              action(
                _streak >= 7 ? 'Start a new week' : 'Finish today',
                _nextDay,
              ),
            ],
          ),
        ),
        const SectionLabel('Closing a goal'),
        Panel(
          child: Column(
            children: <Widget>[
              SizedBox.square(
                dimension: 150,
                child: ListenableBuilder(
                  listenable: Listenable.merge(<Listenable>[_ring, _ringDone]),
                  builder: (BuildContext context, Widget? _) {
                    final double d = _ringDone.value;
                    return Transform.scale(
                      scale: 1 + 0.06 * d,
                      child: CustomPaint(
                        painter: _GoalRing(
                          _ring.value,
                          Color.lerp(
                            c.accent,
                            const Color(0xFF2FA84F),
                            d.clamp(0.0, 1.0),
                          )!,
                          c.ink.withValues(alpha: 0.08),
                        ),
                        child: Center(
                          child: d > 0.05
                              ? Transform.scale(
                                  scale: d,
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 64,
                                    color: Color(0xFF2FA84F),
                                  ),
                                )
                              : Text(
                                  '${(_ring.value * 100).round().clamp(0, 100)}%',
                                  style: LumenType.display(
                                    34,
                                    weight: 700,
                                    color: c.ink,
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              action(
                _ring.target >= 1 ? 'Reset' : 'Reach the goal',
                () => setState(_closeRing),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Confetti extends CustomPainter {
  const _Confetti(this.t, this.seed);
  final double t;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) {
      return;
    }
    final math.Random r = math.Random(seed);
    final Offset c = size.center(Offset.zero);
    const List<Color> cols = <Color>[
      Color(0xFFF5B301),
      Color(0xFFFF6B4A),
      Color(0xFF8E7CFF),
      Color(0xFF2ED3B7),
      Color(0xFF4FB8FF),
    ];
    for (int i = 0; i < 46; i++) {
      final double a = r.nextDouble() * math.pi * 2;
      final double speed = 90 + r.nextDouble() * 190;
      // Out fast, slowing, and falling a little.
      final double k = 1 - math.pow(1 - t, 3).toDouble();
      final Offset p =
          c +
          Offset(math.cos(a), math.sin(a)) * speed * k +
          Offset(0, 90 * t * t);
      final double w = 5 + r.nextDouble() * 5;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + t * (4 + r.nextDouble() * 6));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.5),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color = cols[i % cols.length].withValues(
            alpha: (1 - t * t).clamp(0.0, 1.0),
          ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Confetti old) => old.t != t || old.seed != seed;
}

class _Medal extends CustomPainter {
  const _Medal(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final Path p = ShapeLib.at(
      ShapeLib.gallery,
      5,
      c,
      size.width / 2 * 0.92,
      0,
    );
    canvas.drawPath(
      p.shift(const Offset(0, 4)),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(color, Colors.white, 0.45)!,
            color,
            Color.lerp(color, Colors.black, 0.18)!,
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_Medal old) => old.color != color;
}

class _GoalRing extends CustomPainter {
  const _GoalRing(this.v, this.color, this.track);
  final double v;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = (Offset.zero & size).deflate(9);
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * v.clamp(0.0, 1.0),
      false,
      p..color = color,
    );
  }

  @override
  bool shouldRepaint(_GoalRing old) => old.v != v || old.color != color;
}
