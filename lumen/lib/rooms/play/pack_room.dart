import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';
import 'critter.dart';

const List<(String, Color)> _rarity = <(String, Color)>[
  ('Common', Color(0xFF8A93A6)),
  ('Rare', Color(0xFF3F8CF0)),
  ('Epic', Color(0xFF9B5CF6)),
  ('Legendary', Color(0xFFF5B301)),
];
const List<(String, Color, String)> _roster = <(String, Color, String)>[
  ('Mote', Color(0xFF2FB7A3), 'Hops when it is happy.'),
  ('Pebble', Color(0xFF7C8CF8), 'Sleeps through leg day.'),
  ('Ember', Color(0xFFF2784B), 'Warm to the touch.'),
  ('Sprig', Color(0xFF6FBF4A), 'Grows a leaf a week.'),
  ('Gust', Color(0xFF58B7E8), 'Never arrives on time.'),
  ('Plum', Color(0xFFB067D9), 'Collects shiny things.'),
  ('Dune', Color(0xFFD9A441), 'Loves a long walk.'),
  ('Inkling', Color(0xFF4B5578), 'Shy until snack time.'),
];

class _Card {
  const _Card(this.who, this.rarity);
  final int who, rarity;
}

/// Room 54. Opening a pack, our own take. Tear the top off with a swipe;
/// the cards rise out; tap to turn each one over. The edge of the stack
/// glows in the colour of what is coming, so the wait is part of the fun,
/// and the best card is always last.
class PackRoom extends StatefulWidget {
  const PackRoom({super.key});

  @override
  State<PackRoom> createState() => _PackRoomState();
}

class _PackRoomState extends State<PackRoom> with TickerProviderStateMixin {
  int _seed = 3;
  late List<_Card> _cards = _deal();
  double _tear = 0; // 0..1 across the top
  bool _torn = false;
  int _index = 0; // card on top of the stack
  bool _faceUp = false;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (Duration e) => _time.value = e.inMicroseconds / 1e6,
  );

  @override
  void initState() {
    super.initState();
    // A late field is only created when first used, so the clock is started here.
    _ticker.start();
  }

  late final SpringValue _rise = SpringValue(
    this,
    spring: Motions.expressive,
  ); // cards out of the pack
  late final SpringValue _drop = SpringValue(
    this,
    spring: Motions.spatialSlow,
  ); // pack falls away
  late final SpringValue _flip = SpringValue(this, spring: Motions.expressive);
  late final SpringValue _away = SpringValue(
    this,
    spring: Motions.spatial,
  ); // top card to the tray
  late final SpringValue _lid = SpringValue(
    this,
    spring: Motions.spatial,
  ); // torn strip flying off
  double _burstAt = -10;

  List<_Card> _deal() {
    final math.Random r = math.Random(_seed);
    final List<_Card> out = <_Card>[
      for (int i = 0; i < 5; i++)
        _Card(r.nextInt(_roster.length), () {
          final double x = r.nextDouble();
          return x < 0.62 ? 0 : (x < 0.9 ? 1 : (x < 0.985 ? 2 : 3));
        }()),
    ];
    // The pack always holds at least one Rare or better, and the best comes last.
    if (out.every((_Card c) => c.rarity == 0)) {
      out[0] = _Card(out[0].who, 1 + r.nextInt(2));
    }
    out.sort((_Card a, _Card b) => a.rarity.compareTo(b.rarity));
    return out;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    for (final SpringValue s in <SpringValue>[
      _rise,
      _drop,
      _flip,
      _away,
      _lid,
    ]) {
      s.dispose();
    }
    super.dispose();
  }

  void _tearTo(double v) {
    if (_torn) {
      return;
    }
    final double before = _tear;
    setState(() => _tear = math.max(_tear, v.clamp(0.0, 1.0)));
    // The foil gives way in little steps you can feel.
    if ((_tear * 12).floor() != (before * 12).floor()) {
      Haptics.tick();
    }
    if (_tear > 0.9) {
      setState(() => _torn = true);
      Haptics.thud();
      _lid.animateTo(1);
      _rise.animateTo(1);
      _drop.animateTo(1);
    }
  }

  void _tapCard() {
    if (!_torn ||
        _index >= _cards.length ||
        _away.value > 0.02 && _away.target == 1) {
      return;
    }
    if (!_faceUp) {
      setState(() => _faceUp = true);
      _flip.animateTo(1);
      final int r = _cards[_index].rarity;
      if (r >= 2) {
        _burstAt = _time.value;
        Haptics.thud();
      } else {
        Haptics.settle();
      }
    } else {
      // Send it to the tray, then bring up the next one.
      _away.onSettle = () {
        _away.onSettle = null;
        setState(() {
          _index++;
          _faceUp = false;
        });
        _flip.jumpTo(0);
        _away.jumpTo(0);
      };
      _away.animateTo(1);
      Haptics.tick();
    }
  }

  void _another() {
    setState(() {
      _seed += 7;
      _cards = _deal();
      _tear = 0;
      _torn = false;
      _index = 0;
      _faceUp = false;
    });
    for (final SpringValue s in <SpringValue>[
      _rise,
      _drop,
      _flip,
      _away,
      _lid,
    ]) {
      s.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final bool done = _index >= _cards.length;
    return Scaffold(
      backgroundColor: c.bg,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final Size stage = box.biggest;
          const Size card = Size(214, 300);
          final Offset centre = Offset(stage.width / 2, stage.height * 0.47);
          final Rect pack = Rect.fromCenter(
            center: centre + const Offset(0, 16),
            width: 238,
            height: 340,
          );
          return ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[
              _rise,
              _drop,
              _flip,
              _away,
              _lid,
              _time,
            ]),
            builder: (BuildContext context, Widget? _) {
              final double t = _time.value;
              final _Card? top = done ? null : _cards[_index];
              final _Card? next = _index + 1 < _cards.length
                  ? _cards[_index + 1]
                  : null;
              final Offset tray = Offset(
                36.0 + _index * 44,
                stage.height - safe.bottom - 132,
              );
              final double away = _away.value.clamp(0.0, 1.0);
              final double flip = _flip.value;
              return Stack(
                children: <Widget>[
                  Positioned(
                    left: 16,
                    right: 16,
                    top: safe.top + 44,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const RoomHeader(number: 54, title: 'Card pack'),
                        const SizedBox(height: 10),
                        Text(
                          !_torn
                              ? 'Swipe across the top of the pack to tear it open.'
                              : (done
                                    ? 'Five new friends.'
                                    : (_faceUp
                                          ? 'Tap to keep it.'
                                          : 'Tap the card to turn it over. Watch the glow.')),
                          style: LumenType.text(
                            14,
                            color: c.inkMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The stack waiting under the top card.
                  if (_torn && !done)
                    for (
                      int i = math.min(_cards.length - 1 - _index, 3);
                      i >= 1;
                      i--
                    )
                      Positioned.fromRect(
                        rect: Rect.fromCenter(
                          center:
                              centre +
                              Offset(0, (1 - _rise.value) * 60 + i * 5.0),
                          width: card.width - i * 6,
                          height: card.height,
                        ),
                        child: _Back(
                          glow: i == 1 && next != null
                              ? _rarity[next.rarity].$2
                              : null,
                          t: t,
                        ),
                      ),
                  // The top card.
                  if (_torn && top != null)
                    Positioned.fromRect(
                      rect: Rect.fromCenter(
                        center: Offset.lerp(
                          centre + Offset(0, (1 - _rise.value) * 60),
                          tray,
                          away,
                        )!,
                        width: card.width * (1 - 0.82 * away),
                        height: card.height * (1 - 0.82 * away),
                      ),
                      child: GestureDetector(
                        onTap: _tapCard,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0014)
                            ..rotateY(flip * math.pi),
                          child: flip < 0.5
                              ? _Back(
                                  glow: _rarity[top.rarity].$2,
                                  t: t,
                                  strong: true,
                                )
                              : Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.rotationY(math.pi),
                                  child: FittedBox(
                                    child: SizedBox.fromSize(
                                      size: card,
                                      child: _Face(top, t: t),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  // Confetti for the good ones.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _Burst(
                          centre,
                          (t - _burstAt) / 1.4,
                          _index + _seed,
                        ),
                      ),
                    ),
                  ),
                  // The pack, in front of the cards until it falls away.
                  if (_drop.value < 0.98)
                    Positioned.fromRect(
                      rect: pack.shift(
                        Offset(0, _drop.value * (stage.height * 0.7)),
                      ),
                      child: Opacity(
                        opacity: (1 - _drop.value * 1.1).clamp(0.0, 1.0),
                        child: GestureDetector(
                          onHorizontalDragUpdate: (DragUpdateDetails d) {
                            if (d.localPosition.dy < 110) {
                              _tearTo(d.localPosition.dx / pack.width);
                            }
                          },
                          child: CustomPaint(
                            painter: _Pack(
                              tear: _tear,
                              lid: _lid.value,
                              t: t,
                              accent: c.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // What you have so far.
                  for (int i = 0; i < _index; i++)
                    Positioned.fromRect(
                      rect: Rect.fromCenter(
                        center: Offset(
                          36.0 + i * 44,
                          stage.height - safe.bottom - 132,
                        ),
                        width: card.width * 0.18,
                        height: card.height * 0.18,
                      ),
                      child: FittedBox(
                        child: SizedBox.fromSize(
                          size: card,
                          child: _Face(_cards[i], t: t),
                        ),
                      ),
                    ),
                  if (done)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: safe.bottom + 24,
                      child: Pressable(
                        onTap: _another,
                        child: Container(
                          height: 56,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: c.accent,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Open another',
                            style: LumenType.text(
                              16,
                              weight: 700,
                              color: c.onAccent,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (done)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: stage.height * 0.36,
                      child: Column(
                        children: <Widget>[
                          Text(
                            'Best pull',
                            style: LumenType.label(color: c.inkMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _roster[_cards.last.who].$1,
                            style: LumenType.display(
                              44,
                              weight: 720,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            _rarity[_cards.last.rarity].$1,
                            style: LumenType.text(
                              16,
                              weight: 700,
                              color: _rarity[_cards.last.rarity].$2,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// The back of a card. Its rim can glow in the colour of the rarity inside.
class _Back extends StatelessWidget {
  const _Back({this.glow, required this.t, this.strong = false});
  final Color? glow;
  final double t;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final double pulse = 0.5 + 0.5 * math.sin(t * 4.2);
    return Container(
      decoration: ShapeDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF2A2F45), Color(0xFF171A28)],
        ),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: glow == null
                ? Colors.white12
                : glow!.withValues(alpha: 0.55 + 0.45 * pulse),
            width: glow == null ? 1 : 2.5,
          ),
        ),
        shadows: <BoxShadow>[
          if (glow != null)
            BoxShadow(
              color: glow!.withValues(
                alpha: (strong ? 0.5 : 0.3) * (0.4 + 0.6 * pulse),
              ),
              blurRadius: strong ? 34 : 18,
              spreadRadius: strong ? 2 : 0,
            ),
          const BoxShadow(
            color: Color(0x55000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 74,
          height: 74,
          decoration: ShapeDecoration(
            shape: CircleBorder(
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.18),
                width: 2,
              ),
            ),
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white.withValues(alpha: 0.3),
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face(this.card, {required this.t});
  final _Card card;
  final double t;

  @override
  Widget build(BuildContext context) {
    final (String name, Color col, String line) = _roster[card.who];
    final (String rare, Color rc) = _rarity[card.rarity];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(col, Colors.white, 0.72)!,
            Color.lerp(col, Colors.white, 0.4)!,
          ],
        ),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: rc, width: 4),
        ),
        shadows: <BoxShadow>[
          BoxShadow(
            color: rc.withValues(alpha: card.rarity == 0 ? 0 : 0.5),
            blurRadius: 30,
          ),
          const BoxShadow(
            color: Color(0x55000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        name,
                        style: LumenType.display(
                          26,
                          weight: 720,
                          color: const Color(0xFF17181C),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: ShapeDecoration(
                        color: rc,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        rare,
                        textScaler: TextScaler.noScaling,
                        style: LumenType.text(
                          11.5,
                          weight: 750,
                          color: card.rarity == 3
                              ? const Color(0xFF3A2A00)
                              : Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: SizedBox.square(
                      dimension: 150,
                      child: CustomPaint(
                        painter: CritterPainter(
                          color: col,
                          squash: 0.12 * math.sin(t * 3 + card.who),
                          look: Offset(math.sin(t * 0.9 + card.who), 0),
                          happy: card.rarity >= 2 ? 1 : 0,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  line,
                  style: LumenType.text(
                    13.5,
                    weight: 560,
                    color: const Color(0xFF3B3D45),
                  ),
                ),
              ],
            ),
          ),
          // A band of light crosses the better cards.
          if (card.rarity >= 1)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(
                        -3 + ((t * (card.rarity >= 2 ? 0.7 : 0.35)) % 1) * 6,
                        -1,
                      ),
                      end: Alignment(
                        -2 + ((t * (card.rarity >= 2 ? 0.7 : 0.35)) % 1) * 6,
                        1,
                      ),
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(
                          alpha: card.rarity >= 2 ? 0.55 : 0.3,
                        ),
                        Colors.white.withValues(alpha: 0),
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
}

class _Burst extends CustomPainter {
  const _Burst(this.from, this.t, this.seed);
  final Offset from;
  final double t;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) =>
      paintConfetti(canvas, from, t, seed, reach: 320);

  @override
  bool shouldRepaint(_Burst old) => old.t != t;
}

/// The sealed pack: foil with a crimped top, torn open along a line that follows the finger.
class _Pack extends CustomPainter {
  const _Pack({
    required this.tear,
    required this.lid,
    required this.t,
    required this.accent,
  });
  final double tear, lid, t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const double line = 58; // where it tears
    final RRect body = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, line, size.width, size.height - line),
      bottomLeft: const Radius.circular(14),
      bottomRight: const Radius.circular(14),
    );
    final Paint foil = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1, -1 + 0.4 * math.sin(t * 0.8)),
        end: Alignment(1, 1 - 0.4 * math.sin(t * 0.8)),
        colors: <Color>[
          Color.lerp(accent, Colors.white, 0.3)!,
          Color.lerp(accent, const Color(0xFF3B1E8F), 0.45)!,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
      body.shift(const Offset(0, 8)),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawPath(Path()..addRRect(body), foil);
    // Emblem and crimp at the bottom.
    final Offset c = Offset(size.width / 2, line + (size.height - line) / 2);
    canvas.drawCircle(
      c,
      52,
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.save();
    canvas.translate(c.dx - 46, c.dy - 52);
    const CritterPainter(
      color: Color(0xFFFFFFFF),
      happy: 1,
    ).paint(canvas, const Size(92, 92));
    canvas.restore();
    for (double x = 8; x < size.width - 4; x += 9) {
      canvas.drawLine(
        Offset(x, size.height - 16),
        Offset(x, size.height - 4),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..strokeWidth = 2,
      );
    }
    // Inside the pack, where the tear has opened it: darkness and the tops of the cards.
    if (tear > 0.01 && lid < 0.5) {
      final double open = tear * size.width;
      canvas.drawRect(
        Rect.fromLTWH(0, line - 40, open, 42),
        Paint()..color = const Color(0xFF14151C),
      );
      for (int i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(10, line - 6.0 - i * 5),
          Offset(math.max(10, open - 8), line - 6.0 - i * 5),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5 - i * 0.14)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    // The top strip. The torn part curls up and away; once free, the whole strip flies off.
    final double done = tear * size.width;
    canvas.save();
    canvas.translate(lid * 80, -lid * 260);
    canvas.rotate(lid * 0.5);
    final Path strip = Path()..moveTo(0, line);
    strip.lineTo(0, 8);
    for (double x = 0; x <= size.width; x += 10) {
      strip.lineTo(x + 5, 0);
      strip.lineTo(x + 10, 8);
    }
    strip.lineTo(size.width, line);
    // The tear itself is ragged.
    for (double x = size.width; x >= 0; x -= 8) {
      final double lift = x < done ? (12 + 26 * ((done - x) / size.width)) : 0;
      strip.lineTo(x, line - lift + (x < done ? 3 * math.sin(x * 0.9) : 0));
    }
    strip.close();
    canvas.drawPath(strip, foil);
    canvas.drawPath(
      strip,
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.restore();
    if (lid < 0.02) {
      // The dark gap where it has opened, and a mark showing where to swipe.
      if (done > 2) {
        canvas.drawLine(
          Offset(0, line),
          Offset(done, line),
          Paint()
            ..color = const Color(0xFF14151C)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
      }
      final Paint dash = Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (double x = math.max(done + 8, 10); x < size.width - 8; x += 12) {
        canvas.drawLine(Offset(x, line), Offset(x + 5, line), dash);
      }
      final double k = (t * 0.7) % 1;
      canvas.drawCircle(
        Offset(done + 14 + k * (size.width - done - 40), line - 26),
        7,
        Paint()..color = Colors.white.withValues(alpha: 0.7 * (1 - k)),
      );
    }
  }

  @override
  bool shouldRepaint(_Pack old) => true;
}
