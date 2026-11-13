import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';
import 'critter.dart';

const List<(String, Color)> _wild = <(String, Color)>[
  ('Mote', Color(0xFF2FB7A3)),
  ('Pebble', Color(0xFF7C8CF8)),
  ('Ember', Color(0xFFF2784B)),
  ('Sprig', Color(0xFF6FBF4A)),
];

/// Room 53. A catching game of our own. Nothing is captured: a shy creature
/// hops about, and you win its trust by tossing it treats. Flick a treat so
/// it arrives where the creature is; land it mid-jump, when its mouth is
/// open, and it counts double.
class TossRoom extends StatefulWidget {
  const TossRoom({super.key});

  @override
  State<TossRoom> createState() => _TossRoomState();
}

class _TossRoomState extends State<TossRoom>
    with SingleTickerProviderStateMixin {
  static const double _flight = 0.72, _gravity = 1500, _gain = 0.55, _need = 5;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_tick);

  @override
  void initState() {
    super.initState();
    // A late field is only created when first used, so the clock is started here.
    _ticker.start();
  }

  Duration _last = Duration.zero;
  double _time = 0;
  Size _stage = Size.zero;

  int _who = 0;
  double _trust = 0, _shownTrust = 0;
  bool _won = false;
  double _wonAt = 0, _happy = 0;

  // The treat: resting in the hand, dragged, or flying.
  Offset _treat = Offset.zero, _vel = Offset.zero, _flyFrom = Offset.zero;
  bool _dragging = false, _flying = false, _eaten = false;
  double _flyT = 0;
  String _word = '';
  double _wordAt = -10;
  final List<(Offset, double)> _trail = <(Offset, double)>[];

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  Offset get _hand => Offset(_stage.width / 2, _stage.height - 150);

  // The creature drifts side to side and jumps every couple of seconds.
  double get _jump {
    final double p = (_time % 2.3) / 2.3; // one hop cycle
    return p < 0.34 ? math.sin(p / 0.34 * math.pi) : 0;
  }

  Offset get _critter {
    if (_won) {
      return Offset(_stage.width / 2, _stage.height * 0.4);
    }
    final double x =
        _stage.width / 2 +
        math.sin(_time * 0.9) * _stage.width * 0.26 +
        math.sin(_time * 2.1) * 14;
    return Offset(x, _stage.height * 0.36 - _jump * 74);
  }

  void _tick(Duration e) {
    final double dt = ((e - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = e;
    _time += dt;
    _shownTrust += (_trust - _shownTrust) * math.min(1, dt * 8);
    _happy += ((_won ? 1 : 0) - _happy) * math.min(1, dt * 6);
    if (_flying) {
      _flyT += dt;
      final double t = _flyT;
      _treat =
          _flyFrom +
          Offset(
            _vel.dx * _gain * t,
            _vel.dy * _gain * t + 0.5 * _gravity * t * t,
          );
      _trail.add((_treat, _time));
      // It "arrives" over the last part of the flight; that is when it can be caught.
      if (!_eaten &&
          t > _flight * 0.72 &&
          (_treat - (_critter + const Offset(0, 10))).distance < 62) {
        _eaten = true;
        final bool perfect = _jump > 0.45;
        _trust = math.min(_need, _trust + (perfect ? 2 : 1));
        _word = perfect ? 'Perfect!' : 'Nice';
        _wordAt = _time;
        perfect ? Haptics.thud() : Haptics.settle();
        if (_trust >= _need) {
          _won = true;
          _wonAt = _time;
        }
      }
      if (_eaten || t > _flight + 0.25) {
        if (!_eaten) {
          _word = 'Missed';
          _wordAt = _time;
        }
        _flying = false;
        _treat = _hand;
      }
    } else if (!_dragging) {
      _treat = _hand;
    }
    _trail.removeWhere(((Offset, double) p) => _time - p.$2 > 0.25);
    _frame.value++;
  }

  void _again() {
    setState(() {
      _who = (_who + 1) % _wild.length;
      _trust = 0;
      _shownTrust = 0;
      _won = false;
      _word = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final (String name, Color col) = _wild[_who];
    return Scaffold(
      backgroundColor: const Color(0xFF0C1322),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          _stage = box.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (DragStartDetails d) {
              if (!_flying &&
                  !_won &&
                  (d.localPosition - _hand).distance < 90) {
                _dragging = true;
                _treat = d.localPosition;
              }
            },
            onPanUpdate: (DragUpdateDetails d) {
              if (_dragging) {
                _treat = d.localPosition;
              }
            },
            onPanEnd: (DragEndDetails d) {
              if (!_dragging) {
                return;
              }
              _dragging = false;
              final Offset v = d.velocity.pixelsPerSecond;
              if (v.dy < -500) {
                // Let go moving upward: it is a throw.
                final double sp = v.distance.clamp(900.0, 3200.0);
                _vel = v / v.distance * sp;
                _flyFrom = _treat;
                _flyT = 0;
                _flying = true;
                _eaten = false;
                Haptics.tick();
              }
            },
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _frame,
                    builder: (BuildContext context, int _, Widget? _) =>
                        CustomPaint(
                          painter: _Scene(
                            time: _time,
                            critter: _critter,
                            jump: _jump,
                            color: col,
                            treat: _treat,
                            treatScale: _flying
                                ? 1 - 0.58 * (_flyT / _flight).clamp(0.0, 1.0)
                                : (_dragging ? 1.15 : 1),
                            showTreat: !_won && !(_flying && _eaten),
                            trail: _flying
                                ? _trail
                                : const <(Offset, double)>[],
                            happy: _happy,
                            wonFor: _won ? _time - _wonAt : -1,
                            word: _time - _wordAt < 0.9 ? _word : '',
                            wordT: (_time - _wordAt) / 0.9,
                            hand: _hand,
                            idleHint:
                                !_dragging && !_flying && _trust == 0 && !_won,
                          ),
                        ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: safe.top + 44,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Theme(
                        data: Theme.of(context).copyWith(
                          extensions: <ThemeExtension<dynamic>>[
                            LumenColors.night,
                          ],
                        ),
                        child: const RoomHeader(
                          number: 53,
                          title: 'Treat toss',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<int>(
                        valueListenable: _frame,
                        builder: (BuildContext context, int _, Widget? _) =>
                            Row(
                              children: <Widget>[
                                Text(
                                  _won ? '$name trusts you' : 'A wild $name',
                                  style: LumenType.text(
                                    15,
                                    weight: 650,
                                    color: Colors.white,
                                  ),
                                ),
                                const Spacer(),
                                for (int i = 0; i < _need; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 5),
                                    child: Icon(
                                      Icons.favorite_rounded,
                                      size: 20,
                                      color: Color.lerp(
                                        Colors.white24,
                                        const Color(0xFFFF6B8A),
                                        (_shownTrust - i).clamp(0.0, 1.0),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: safe.bottom + 24,
                  child: _won
                      ? Pressable(
                          onTap: _again,
                          child: Container(
                            height: 56,
                            alignment: Alignment.center,
                            decoration: ShapeDecoration(
                              color: c.accent,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              'Find another',
                              style: LumenType.text(
                                16,
                                weight: 700,
                                color: c.onAccent,
                                height: 1,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          'Flick the treat upward. Land it while $name is in the air for two hearts.',
                          textAlign: TextAlign.center,
                          style: LumenType.text(
                            13.5,
                            color: Colors.white60,
                            height: 1.35,
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Scene extends CustomPainter {
  const _Scene({
    required this.time,
    required this.critter,
    required this.jump,
    required this.color,
    required this.treat,
    required this.treatScale,
    required this.showTreat,
    required this.trail,
    required this.happy,
    required this.wonFor,
    required this.word,
    required this.wordT,
    required this.hand,
    required this.idleHint,
  });
  final double time, jump, treatScale, happy, wonFor, wordT;
  final Offset critter, treat, hand;
  final Color color;
  final bool showTreat, idleHint;
  final List<(Offset, double)> trail;
  final String word;

  @override
  void paint(Canvas canvas, Size size) {
    // Dusk sky, hills, a few stars.
    // Painted as thin bands rather than one gradient: it looks the same and behaves the same on every renderer.
    const int bands = 48;
    for (int i = 0; i < bands; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          size.height * 0.6 * i / bands,
          size.width,
          size.height * 0.6 / bands + 1,
        ),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF141B3A),
            const Color(0xFF7A4A6E),
            i / (bands - 1),
          )!,
      );
    }
    final math.Random r = math.Random(7);
    for (int i = 0; i < 40; i++) {
      final Offset s = Offset(
        r.nextDouble() * size.width,
        r.nextDouble() * size.height * 0.4,
      );
      canvas.drawCircle(
        s,
        0.8 + r.nextDouble(),
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.3 + 0.5 * (0.5 + 0.5 * math.sin(time * 1.5 + i)),
          ),
      );
    }
    final Path hills = Path()..moveTo(0, size.height * 0.56);
    for (double x = 0; x <= size.width + 12; x += 12) {
      hills.lineTo(
        x,
        size.height * 0.56 -
            26 * math.sin(x / size.width * math.pi * 2.2 + 0.6) -
            10 * math.sin(x / 31),
      );
    }
    hills
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      hills,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF24403A), Color(0xFF0E1A1C)],
        ).createShader(Offset.zero & size),
    );

    // Creature: shadow on the ground, then the body.
    final double big = wonFor >= 0
        ? 1 +
              0.5 *
                  (1 - math.exp(-wonFor * 5)) *
                  (1 + 0.08 * math.sin(wonFor * 9))
        : 1;
    final double s = 150 * big;
    final double ground = size.height * 0.36 + 58;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          critter.dx,
          wonFor >= 0 ? critter.dy + s * 0.42 : ground,
        ),
        width: 96 * big * (1 - jump * 0.35),
        height: 18 * big,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35 - 0.15 * jump),
    );
    final Offset d = treat - critter;
    canvas.save();
    canvas.translate(critter.dx - s / 2, critter.dy - s * 0.56);
    CritterPainter(
      color: color,
      mouth: wonFor >= 0
          ? 0
          : (jump > 0.45 ? ((jump - 0.45) / 0.4).clamp(0.0, 1.0) : 0),
      look: Offset(
        (d.dx / 160).clamp(-1.0, 1.0),
        (d.dy / 220).clamp(-1.0, 1.0),
      ),
      squash: jump > 0
          ? jump * 0.8
          : -0.25 * math.max(0, math.sin(time * 5.4)) * (wonFor >= 0 ? 0 : 0.6),
      happy: happy,
    ).paint(canvas, Size(s, s));
    canvas.restore();

    if (wonFor >= 0) {
      paintConfetti(
        canvas,
        critter,
        (wonFor / 1.6).clamp(0.0, 1.0),
        11,
        reach: 300,
      );
    }

    // The treat and its trail.
    if (showTreat) {
      for (final (Offset p, double at) in trail) {
        final double a = 1 - (time - at) / 0.25;
        canvas.drawCircle(
          p,
          9 * treatScale * a,
          Paint()
            ..color = const Color(0xFFFFD27A)
                .withValues(alpha: 0.35 * a.clamp(0.0, 1.0)),
        );
      }
      if (idleHint) {
        // A quiet nudge upward until the first treat lands.
        final double k = (time * 0.8) % 1;
        canvas.drawCircle(
          hand - Offset(0, 40 + 90 * k),
          5,
          Paint()..color = Colors.white.withValues(alpha: 0.5 * (1 - k)),
        );
      }
      final double rr = 24 * treatScale;
      canvas.drawCircle(
        treat + Offset(0, rr * 0.5),
        rr,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      final Rect t = Rect.fromCircle(center: treat, radius: rr);
      canvas.drawCircle(
        treat,
        rr,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.5),
            colors: <Color>[
              Color(0xFFFFF0B8),
              Color(0xFFF5A623),
              Color(0xFFB8620F),
            ],
            stops: <double>[0, 0.6, 1],
          ).createShader(t),
      );
      // A leaf, so it reads as a berry and not as a ball.
      final Path leaf = Path()
        ..moveTo(treat.dx, treat.dy - rr * 0.9)
        ..quadraticBezierTo(
          treat.dx + rr * 0.9,
          treat.dy - rr * 1.7,
          treat.dx + rr * 0.95,
          treat.dy - rr * 0.9,
        )
        ..quadraticBezierTo(
          treat.dx + rr * 0.4,
          treat.dy - rr * 0.75,
          treat.dx,
          treat.dy - rr * 0.9,
        );
      canvas.drawPath(leaf, Paint()..color = const Color(0xFF58B85A));
    }

    if (word.isNotEmpty) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: word,
          style: LumenType.display(
            34,
            weight: 720,
            color: (word == 'Missed' ? Colors.white70 : const Color(0xFFFFD27A))
                .withValues(alpha: (1 - wordT).clamp(0.0, 1.0)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(size.width / 2 - tp.width / 2, size.height * 0.52 - 30 * wordT),
      );
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(_Scene old) => true;
}
