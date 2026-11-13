import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/haptics.dart';
import '../core/theme.dart';
import '../rooms/details/small_things.dart';
import '../widgets/pressable.dart';
import 'common.dart';
import 'shell.dart';
import 'state.dart';

const List<String> _plan = <String>[
  'Bench press',
  'Incline press',
  'Cable fly',
  'Lateral raise',
  'Triceps pushdown',
];

/// Prism's first page: what today asks of you, at a glance.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onStart,
    required this.onFood,
    required this.onWeigh,
  });
  final VoidCallback onStart, onFood, onWeigh;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    const Color green = Color(0xFF2FA84F), red = Color(0xFFE5484D);
    return ListenableBuilder(
      listenable: fit,
      builder: (BuildContext context, Widget? _) {
        final int done = fit.habits
            .where(((String, bool?) h) => h.$2 != null)
            .length;
        return ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            safe.top + 22,
            16,
            safe.bottom + 130,
          ),
          children: <Widget>[
            PageTitle(
              'Good evening',
              kicker: 'Friday 13 November',
              icon: Icons.tune_rounded,
              onIcon: () => showPrismSettings(context),
            ),
            const SizedBox(height: 20),
            // Today's workout, with enough on it that you rarely need to open it to remember.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: card(c, radius: 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        "TODAY'S WORKOUT",
                        style: LumenType.label(color: c.accent),
                      ),
                      const Spacer(),
                      Text(
                        '2 of 5 done',
                        style: LumenType.text(
                          13,
                          weight: 600,
                          color: c.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Push day',
                              style: LumenType.display(
                                36,
                                weight: 720,
                                color: c.ink,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '5 exercises',
                              style: LumenType.text(14.5, color: c.inkMuted),
                            ),
                            Text(
                              'about 52 min',
                              style: LumenType.text(14.5, color: c.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (int i = 0; i < 4; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                i == 3 ? '…' : '${i + 1})  ${_plan[i]}',
                                style:
                                    LumenType.text(
                                      13.5,
                                      weight: 560,
                                      color: i < 1 ? c.inkFaint : c.ink,
                                    ).copyWith(
                                      decoration: i < 1
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Pressable(
                    onTap: onStart,
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: c.accent,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'Continue with bench press',
                        style: LumenType.text(
                          16,
                          weight: 700,
                          color: c.onAccent,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: Pressable(
                    scale: 0.97,
                    onTap: onFood,
                    child: Container(
                      height: 168,
                      padding: const EdgeInsets.all(16),
                      decoration: card(c),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'KCAL LEFT',
                            style: LumenType.label(color: c.inkMuted),
                          ),
                          const Spacer(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Expanded(
                                child: Odometer(
                                  value: fit.left.abs(),
                                  digits: 4,
                                  style: LumenType.display(
                                    34,
                                    weight: 720,
                                    color: fit.left < 0 ? red : c.ink,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              SizedBox.square(
                                dimension: 46,
                                child: CustomPaint(
                                  painter: _Ring(
                                    (fit.eaten / fit.goal).clamp(0.0, 1.0),
                                    fit.left < 0 ? red : c.accent,
                                    c.ink.withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${fit.eaten} of ${fit.goal} eaten',
                            style: LumenType.text(13, color: c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Pressable(
                    scale: 0.97,
                    onTap: onWeigh,
                    child: Container(
                      height: 168,
                      padding: const EdgeInsets.all(16),
                      decoration: card(c),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'WEIGHT',
                            style: LumenType.label(color: c.inkMuted),
                          ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: _Spark(),
                              ),
                            ),
                          ),
                          Text(
                            '${fit.weight.toStringAsFixed(1)} kg',
                            style: LumenType.display(
                              28,
                              weight: 720,
                              color: c.ink,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            fit.weighedToday
                                ? 'Logged today'
                                : 'Down 0.3 this week',
                            style: LumenType.text(
                              13,
                              color: fit.weighedToday ? green : c.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
              decoration: card(c),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        "TODAY'S LIST",
                        style: LumenType.label(color: c.inkMuted),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          '$done / ${fit.habits.length}',
                          style: LumenType.text(
                            13,
                            weight: 650,
                            color: c.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final (int i, (String, bool?) h) in fit.habits.indexed)
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              fit.mark(i, h.$2 == true ? null : true);
                              Haptics.settle();
                            },
                            child: SizedBox(
                              height: 52,
                              child: Row(
                                children: <Widget>[
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    width: 26,
                                    height: 26,
                                    decoration: ShapeDecoration(
                                      color: h.$2 == null
                                          ? Colors.transparent
                                          : (h.$2! ? green : red),
                                      shape: CircleBorder(
                                        side: BorderSide(
                                          color: h.$2 == null
                                              ? c.inkFaint
                                              : (h.$2! ? green : red),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    child: h.$2 == null
                                        ? null
                                        : Icon(
                                            h.$2!
                                                ? Icons.check_rounded
                                                : Icons.close_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      h.$1,
                                      style:
                                          LumenType.text(
                                            15.5,
                                            weight: 560,
                                            color: h.$2 == null
                                                ? c.ink
                                                : c.inkMuted,
                                          ).copyWith(
                                            decoration: h.$2 == null
                                                ? null
                                                : TextDecoration.lineThrough,
                                            decorationColor: h.$2 == true
                                                ? green
                                                : red,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (h.$2 == null)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              fit.mark(i, false);
                              Haptics.tick();
                            },
                            child: SizedBox(
                              width: 64,
                              height: 52,
                              child: Center(
                                child: Text(
                                  'Skip',
                                  style: LumenType.text(
                                    13.5,
                                    weight: 650,
                                    color: c.inkMuted,
                                  ),
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
        );
      },
    );
  }
}

class _Ring extends CustomPainter {
  const _Ring(this.v, this.color, this.track);
  final double v;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = (Offset.zero & size).deflate(4);
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, p..color = color);
  }

  @override
  bool shouldRepaint(_Ring old) => old.v != v || old.color != color;
}

class _Spark extends CustomPainter {
  const _Spark();

  @override
  void paint(Canvas canvas, Size size) {
    const List<double> v = <double>[0.25, 0.4, 0.3, 0.5, 0.45, 0.6, 0.55, 0.8];
    final Path p = Path();
    for (int i = 0; i < v.length; i++) {
      final Offset o = Offset(
        size.width * i / (v.length - 1),
        size.height * v[i],
      );
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = const Color(0xFF4FB8FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Spark old) => false;
}
