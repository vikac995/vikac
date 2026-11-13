import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/haptics.dart';
import '../core/springs.dart';
import '../core/theme.dart';
import '../widgets/tag.dart';
import 'common.dart';
import 'state.dart';
import '../rooms/details/small_things.dart';

/// Room 46. A complete food day: what is left, the three macros, meals you
/// add to with one tap, and water.
class FoodPage extends StatefulWidget {
  const FoodPage({super.key});

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> with TickerProviderStateMixin {
  static const int _goal = 2400;
  static const List<(String, IconData, String, int, int, int, int)>
  _quick = <(String, IconData, String, int, int, int, int)>[
    ('Breakfast', Icons.wb_twilight_rounded, 'Oats and banana', 420, 14, 72, 8),
    ('Lunch', Icons.wb_sunny_rounded, 'Chicken and rice', 610, 48, 70, 12),
    ('Dinner', Icons.nights_stay_rounded, 'Salmon, potatoes', 680, 42, 55, 30),
    ('Snacks', Icons.cookie_rounded, 'Protein bar', 210, 20, 22, 7),
  ];
  final List<int> _count = <int>[1, 1, 0, 0];
  int _water = 3;
  late final SpringValue _ring = SpringValue(
    this,
    value: _eaten / _goal,
    spring: Motions.expressiveSlow,
  );
  late final List<SpringValue> _pop = <SpringValue>[
    for (int i = 0; i < 4; i++)
      SpringValue(this, value: 1, spring: Motions.expressiveFast),
  ];

  int _sum(int field) {
    int s = 0;
    for (int i = 0; i < 4; i++) {
      s +=
          _count[i] *
          <int>[_quick[i].$4, _quick[i].$5, _quick[i].$6, _quick[i].$7][field];
    }
    return s;
  }

  int get _eaten => _sum(0);

  @override
  void dispose() {
    _ring.dispose();
    for (final SpringValue s in _pop) {
      s.dispose();
    }
    super.dispose();
  }

  void _add(int i, int by) {
    if (_count[i] + by < 0) {
      return;
    }
    setState(() => _count[i] += by);
    fit.eat(by * _quick[i].$4);
    _pop[i].jumpTo(0.8);
    _pop[i].animateTo(1);
    _ring.animateTo(_eaten / _goal);
    by > 0 ? Haptics.settle() : Haptics.tick();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final int left = _goal - _eaten;
    final bool over = left < 0;
    const Color warn = Color(0xFFE5484D);
    Widget macro(String name, int g, int goal, Color col) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            name,
            style: LumenType.text(12.5, weight: 600, color: c.inkMuted),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: ColoredBox(color: c.ink.withValues(alpha: 0.09)),
                  ),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerLeft,
                    widthFactor: (g / goal).clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: ColoredBox(color: col),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$g / $goal g',
            style: LumenType.text(13, weight: 620, color: c.ink),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, safe.top + 22, 16, safe.bottom + 130),
        children: <Widget>[
          const PageTitle('Food'),
          const SizedBox(height: 22),
          Tag(
            'R46.1',
            'What is left, not what is eaten',
            child: Row(
              children: <Widget>[
                SizedBox.square(
                  dimension: 156,
                  child: ListenableBuilder(
                    listenable: _ring,
                    builder: (BuildContext context, Widget? child) =>
                        CustomPaint(
                          painter: _Ring(
                            _ring.value,
                            over ? warn : c.accent,
                            c.ink.withValues(alpha: 0.09),
                          ),
                          child: child,
                        ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Odometer(
                          value: left.abs(),
                          digits: 4,
                          style: LumenType.display(
                            32,
                            weight: 720,
                            color: over ? warn : c.ink,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          over ? 'kcal over' : 'kcal left',
                          style: LumenType.text(13, color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final (String l, String v) in <(String, String)>[
                        ('Goal', '$_goal'),
                        ('Eaten', '$_eaten'),
                        ('Burned', '320'),
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  l,
                                  style: LumenType.text(
                                    14.5,
                                    color: c.inkMuted,
                                  ),
                                ),
                              ),
                              Text(
                                v,
                                style:
                                    LumenType.text(
                                      15.5,
                                      weight: 680,
                                      color: c.ink,
                                    ).copyWith(
                                      fontFeatures: const <FontFeature>[
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Tag(
            'R46.2',
            'Three macros, one line each',
            child: Row(
              children: <Widget>[
                macro('Protein', _sum(1), 160, const Color(0xFF4FB8FF)),
                const SizedBox(width: 14),
                macro('Carbs', _sum(2), 280, const Color(0xFFF5B301)),
                const SizedBox(width: 14),
                macro('Fat', _sum(3), 75, const Color(0xFF9B6BFF)),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Tag(
            'R46.3',
            'Meals: one tap adds the usual',
            child: Column(
              children: <Widget>[
                for (int i = 0; i < 4; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    decoration: ShapeDecoration(
                      color: c.ink.withValues(alpha: 0.055),
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(_quick[i].$2, size: 22, color: c.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _quick[i].$1,
                                style: LumenType.text(
                                  15.5,
                                  weight: 650,
                                  color: c.ink,
                                ),
                              ),
                              Text(
                                _count[i] == 0
                                    ? 'Nothing yet'
                                    : '${_count[i] > 1 ? '${_count[i]} × ' : ''}${_quick[i].$3}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LumenType.text(13, color: c.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        ListenableBuilder(
                          listenable: _pop[i],
                          builder: (BuildContext context, Widget? child) =>
                              Transform.scale(
                                scale: _pop[i].value,
                                child: child,
                              ),
                          child: Text(
                            '${_count[i] * _quick[i].$4}',
                            style: LumenType.text(
                              16,
                              weight: 700,
                              color: _count[i] == 0 ? c.inkFaint : c.ink,
                            ),
                          ),
                        ),
                        if (_count[i] > 0)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _add(i, -1),
                            child: Semantics(
                              button: true,
                              label: 'Remove one',
                              child: SizedBox(
                                width: 44,
                                height: 48,
                                child: Icon(
                                  Icons.remove_rounded,
                                  color: c.inkMuted,
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => _add(i, 1),
                          child: Semantics(
                            button: true,
                            label: 'Add ${_quick[i].$3}',
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: ShapeDecoration(
                                color: c.accent.withValues(alpha: 0.16),
                                shape: const CircleBorder(),
                              ),
                              child: Icon(Icons.add_rounded, color: c.accent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Tag(
            'R46.4',
            'Water: tap a glass',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Water  ·  ${(_water * 0.25).toStringAsFixed(2)} of 2.00 l',
                  style: LumenType.text(14.5, weight: 620, color: c.ink),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    for (int i = 0; i < 8; i++)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          // Tapping the last full glass empties it; any other sets the level.
                          setState(() => _water = i + 1 == _water ? i : i + 1);
                          Haptics.tick();
                        },
                        child: SizedBox(
                          width: 40,
                          height: 48,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutBack,
                            scale: i < _water ? 1 : 0.86,
                            child: Icon(
                              i < _water
                                  ? Icons.water_drop_rounded
                                  : Icons.water_drop_outlined,
                              size: 30,
                              color: i < _water
                                  ? const Color(0xFF4FB8FF)
                                  : c.inkFaint,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends CustomPainter {
  const _Ring(this.v, this.color, this.track);
  final double v;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = (Offset.zero & size).deflate(8);
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
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
  bool shouldRepaint(_Ring old) => old.v != v || old.color != color;
}
