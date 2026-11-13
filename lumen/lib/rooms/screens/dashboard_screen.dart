import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/glass.dart';
import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/tag.dart';

/// Room 26. A complete home screen in the current style: one thing to look
/// at first, a bento of supporting facts, and a floating glass toolbar.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late final List<SpringValue> _rise = <SpringValue>[
    for (int i = 0; i < 6; i++) SpringValue(this, spring: Motions.expressive),
  ];
  late final SpringValue _ring = SpringValue(
    this,
    spring: Motions.expressiveSlow,
  );
  final List<Timer> _timers = <Timer>[];
  int _tool = 0;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _rise.length; i++) {
      _timers.add(
        Timer(Duration(milliseconds: 80 + 60 * i), () => _rise[i].animateTo(1)),
      );
    }
    _timers.add(
      Timer(const Duration(milliseconds: 380), () => _ring.animateTo(0.72)),
    );
  }

  @override
  void dispose() {
    for (final Timer t in _timers) {
      t.cancel();
    }
    for (final SpringValue s in <SpringValue>[..._rise, _ring]) {
      s.dispose();
    }
    super.dispose();
  }

  Widget _in(int i, Widget child) => ListenableBuilder(
    listenable: _rise[i],
    builder: (BuildContext context, Widget? child) {
      final double v = _rise[i].value;
      return Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - v)),
          child: child,
        ),
      );
    },
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    Widget tile(Color col, Widget child, {double height = 150}) => Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(col, Colors.white, 0.08)!,
            col,
            Color.lerp(col, Colors.black, 0.08)!,
          ],
        ),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
      child: child,
    );
    Widget cap(String s) => Text(
      s,
      style: LumenType.text(
        13,
        weight: 600,
        color: Colors.white.withValues(alpha: 0.82),
      ),
    );
    Widget big(String v, String unit) => Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          v,
          style: LumenType.display(
            34,
            weight: 700,
            color: Colors.white,
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 3),
          child: Text(
            unit,
            style: LumenType.text(
              13,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              safe.top + 104,
              16,
              safe.bottom + 120,
            ),
            children: <Widget>[
              _in(
                0,
                Tag(
                  'R26.1',
                  'Greeting',
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'FRIDAY 13 NOVEMBER',
                              style: LumenType.label(color: c.inkFaint),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Good evening',
                              style: LumenType.display(
                                34,
                                weight: 720,
                                color: c.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF8E7CFF),
                        child: Text(
                          'V',
                          style: LumenType.display(
                            20,
                            weight: 700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _in(
                1,
                Tag(
                  'R26.2',
                  'Summary card',
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: ShapeDecoration(
                      color: c.surface,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(32),
                        side: BorderSide(color: c.hairline),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        SizedBox.square(
                          dimension: 112,
                          child: ListenableBuilder(
                            listenable: _ring,
                            builder: (BuildContext context, Widget? _) =>
                                CustomPaint(
                                  painter: _Ring(
                                    _ring.value,
                                    c.accent,
                                    c.ink.withValues(alpha: 0.08),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${(_ring.value * 100).round()}%',
                                      style: LumenType.display(
                                        26,
                                        weight: 700,
                                        color: c.ink,
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Today',
                                style: LumenType.text(
                                  13,
                                  weight: 600,
                                  color: c.inkMuted,
                                ),
                              ),
                              Text(
                                'On track',
                                style: LumenType.display(
                                  24,
                                  weight: 700,
                                  color: c.ink,
                                ),
                              ),
                              const SizedBox(height: 10),
                              for (final (String l, String v, Color col)
                                  in <(String, String, Color)>[
                                    (
                                      'Move',
                                      '412 / 600 kcal',
                                      const Color(0xFFFF6B4A),
                                    ),
                                    (
                                      'Train',
                                      '38 / 45 min',
                                      const Color(0xFF8E7CFF),
                                    ),
                                  ])
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: col,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l,
                                        style: LumenType.text(
                                          13.5,
                                          weight: 600,
                                          color: c.ink,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        v,
                                        style: LumenType.text(
                                          13,
                                          color: c.inkMuted,
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
                ),
              ),
              const SizedBox(height: 12),
              _in(
                2,
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Tag(
                        'R26.3',
                        'Stat tile',
                        child: tile(
                          const Color(0xFF4E6CC4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              cap('Steps'),
                              const SizedBox(height: 4),
                              big('8,214', ''),
                              const Spacer(),
                              SizedBox(
                                height: 36,
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: _Bars(<double>[
                                    .4,
                                    .7,
                                    .5,
                                    .9,
                                    .6,
                                    .8,
                                    .75,
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: tile(
                        const Color(0xFF2F978F),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            cap('Sleep'),
                            const SizedBox(height: 4),
                            big('7.4', 'h'),
                            const Spacer(),
                            Text(
                              '20 min more than usual',
                              style: LumenType.text(
                                12.5,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _in(
                3,
                Tag(
                  'R26.4',
                  'Action tile',
                  child: tile(
                    const Color(0xFF865AC9),
                    height: 132,
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              cap('Next workout'),
                              Text(
                                'Pull day',
                                style: LumenType.display(
                                  28,
                                  weight: 720,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '5 exercises · about 60 min',
                                style: LumenType.text(
                                  13.5,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Pressable(
                          onTap: Haptics.settle,
                          scale: 0.92,
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            alignment: Alignment.center,
                            decoration: const ShapeDecoration(
                              color: Colors.white,
                              shape: StadiumBorder(),
                            ),
                            child: Text(
                              'Start',
                              style: LumenType.text(
                                15,
                                weight: 680,
                                color: const Color(0xFF3B2470),
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _in(
                4,
                Tag(
                  'R26.5',
                  'Section with list',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'This week',
                            style: LumenType.display(
                              22,
                              weight: 700,
                              color: c.ink,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'See all',
                            style: LumenType.text(
                              14,
                              weight: 620,
                              color: c.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: ShapeDecoration(
                          color: c.surface,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(26),
                            side: BorderSide(color: c.hairline),
                          ),
                        ),
                        child: Column(
                          children: <Widget>[
                            for (final (int i, String t, String s, IconData ic)
                                in <(int, String, String, IconData)>[
                                  (
                                    0,
                                    'Push day',
                                    'Mon · 58 min · 6.2 t lifted',
                                    Icons.fitness_center_rounded,
                                  ),
                                  (
                                    1,
                                    'Easy run',
                                    'Wed · 5.1 km · 5:42 / km',
                                    Icons.directions_run_rounded,
                                  ),
                                  (
                                    2,
                                    'Mobility',
                                    'Thu · 20 min',
                                    Icons.self_improvement_rounded,
                                  ),
                                ]) ...<Widget>[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  indent: 66,
                                  color: c.hairline,
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  12,
                                  12,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: ShapeDecoration(
                                        color: c.accent.withValues(alpha: 0.16),
                                        shape: const CircleBorder(),
                                      ),
                                      child: Icon(
                                        ic,
                                        size: 20,
                                        color: c.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            t,
                                            style: LumenType.text(
                                              15.5,
                                              weight: 620,
                                              color: c.ink,
                                            ),
                                          ),
                                          Text(
                                            s,
                                            style: LumenType.text(
                                              13,
                                              color: c.inkMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: c.inkFaint,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: safe.top + 44,
            left: 16,
            right: 16,
            child: const ScreenBar(number: 26),
          ),
          // Navigation floats above the content, as glass.
          Positioned(
            left: 0,
            right: 0,
            bottom: safe.bottom + 16,
            child: Center(
              child: Tag(
                'R26.6',
                'Floating glass toolbar',
                child: SizedBox(
                  height: 64,
                  width: 280,
                  child: Glass(
                    radius: 32,
                    style: GlassStyle(
                      blur: 14,
                      tint: 0.36,
                      refraction: 26,
                      bevel: 18,
                      fallbackColor: c.surfaceHigh,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        for (final (int i, IconData ic) in <(int, IconData)>[
                          (0, Icons.home_rounded),
                          (1, Icons.calendar_month_rounded),
                          (2, Icons.show_chart_rounded),
                          (3, Icons.person_rounded),
                        ])
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() => _tool = i);
                              Haptics.tick();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 52,
                              height: 44,
                              decoration: ShapeDecoration(
                                color: _tool == i
                                    ? c.glassInk.withValues(alpha: 0.9)
                                    : Colors.transparent,
                                shape: const StadiumBorder(),
                              ),
                              child: Icon(
                                ic,
                                size: 22,
                                color: _tool == i
                                    ? (c.dark
                                          ? const Color(0xFF14161B)
                                          : Colors.white)
                                    : c.glassInk,
                              ),
                            ),
                          ),
                      ],
                    ),
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

class _Ring extends CustomPainter {
  const _Ring(this.v, this.color, this.track);
  final double v;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = (Offset.zero & size).deflate(7);
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
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

class _Bars extends CustomPainter {
  const _Bars(this.v);
  final List<double> v;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width / v.length;
    for (int i = 0; i < v.length; i++) {
      final double h = size.height * v[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * w + 2, size.height - h, w - 4, h),
          const Radius.circular(4),
        ),
        Paint()
          ..color = Colors.white.withValues(
            alpha: i == v.length - 1 ? 1 : 0.45,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_Bars old) => false;
}
