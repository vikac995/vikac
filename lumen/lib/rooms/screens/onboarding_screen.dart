import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/shapes.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/tag.dart';

const List<(String, String, List<Color>)>
_steps = <(String, String, List<Color>)>[
  (
    'Track what matters',
    'Workouts, food and weight in one place. Log a set in two taps.',
    <Color>[Color(0xFFFFA14A), Color(0xFFFF6B4A)],
  ),
  (
    'See it add up',
    'Weekly trends instead of daily noise, so one bad day stays one bad day.',
    <Color>[Color(0xFF8E7CFF), Color(0xFF4E6CC4)],
  ),
  (
    'Make it yours',
    'Pick the three things you want on your home screen. Change them any time.',
    <Color>[Color(0xFF2ED3B7), Color(0xFF2F978F)],
  ),
];

/// Room 29. A first-run flow: few steps, one idea each, a picture that
/// changes with the swipe, a clear way to skip, and a real ending.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final SpringValue _page = SpringValue(
    this,
    spring: Motions.expressive,
    settleDistance: 0.01,
    settleVelocity: 0.2,
  );
  late final SpringValue _done = SpringValue(this, spring: Motions.expressive);
  double _dragFrom = 0, _dragDx = 0, _width = 300;
  bool _finished = false;

  int get _index => _page.target.round().clamp(0, _steps.length - 1);

  @override
  void dispose() {
    _page.dispose();
    _done.dispose();
    super.dispose();
  }

  void _go(int i, {double? velocity}) {
    final int next = i.clamp(0, _steps.length - 1);
    _page.onSettle = Haptics.tick;
    _page.animateTo(next.toDouble(), velocity: velocity);
    setState(() {});
  }

  void _finish() {
    setState(() => _finished = true);
    _done.onSettle = Haptics.settle;
    _done.animateTo(1);
  }

  void _restart() {
    _done.animateTo(0, spring: Motions.spatialFast);
    _page.jumpTo(0);
    setState(() => _finished = false);
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final bool last = _index == _steps.length - 1;
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              0,
              safe.top + 108,
              0,
              safe.bottom + 20,
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                _width = box.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    _page.jumpTo(_page.value);
                    _dragFrom = _page.value;
                    _dragDx = 0;
                  },
                  onHorizontalDragUpdate: (DragUpdateDetails d) {
                    _dragDx += d.delta.dx;
                    double p = _dragFrom - _dragDx / _width;
                    // Past the first and last step the page resists.
                    if (p < 0) {
                      p *= 0.3;
                    } else if (p > _steps.length - 1) {
                      p = _steps.length - 1 + (p - (_steps.length - 1)) * 0.3;
                    }
                    _page.jumpTo(p);
                  },
                  onHorizontalDragEnd: (DragEndDetails d) {
                    final double v = -d.velocity.pixelsPerSecond.dx / _width;
                    _go((_page.value + v * 0.18).round(), velocity: v);
                  },
                  child: ListenableBuilder(
                    listenable: _page,
                    builder: (BuildContext context, Widget? _) {
                      final double p = _page.value;
                      final int a = p.floor().clamp(0, _steps.length - 1),
                          b = (a + 1).clamp(0, _steps.length - 1);
                      final double t = (p - a).clamp(0.0, 1.0);
                      return Column(
                        children: <Widget>[
                          Expanded(
                            child: Tag(
                              'R29.1',
                              'Illustration that morphs with the swipe',
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: _Art(
                                  p,
                                  Color.lerp(
                                    _steps[a].$3[0],
                                    _steps[b].$3[0],
                                    t,
                                  )!,
                                  Color.lerp(
                                    _steps[a].$3[1],
                                    _steps[b].$3[1],
                                    t,
                                  )!,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 150,
                            child: Stack(
                              children: <Widget>[
                                for (int i = 0; i < _steps.length; i++)
                                  if ((i - p).abs() < 1)
                                    Positioned.fill(
                                      child: Opacity(
                                        opacity: (1 - (i - p).abs() * 1.6)
                                            .clamp(0.0, 1.0),
                                        child: Transform.translate(
                                          offset: Offset((i - p) * 70, 0),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 28,
                                            ),
                                            child: Column(
                                              children: <Widget>[
                                                Text(
                                                  _steps[i].$1,
                                                  textAlign: TextAlign.center,
                                                  style: LumenType.display(
                                                    32,
                                                    weight: 740,
                                                    color: c.ink,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  _steps[i].$2,
                                                  textAlign: TextAlign.center,
                                                  style: LumenType.text(
                                                    16,
                                                    color: c.inkMuted,
                                                    height: 1.45,
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
                          ),
                          Tag(
                            'R29.2',
                            'Progress dots',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                for (int i = 0; i < _steps.length; i++)
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    width:
                                        8 +
                                        20 *
                                            (1 - (i - p).abs()).clamp(0.0, 1.0),
                                    height: 8,
                                    decoration: ShapeDecoration(
                                      color: Color.lerp(
                                        c.ink.withValues(alpha: 0.18),
                                        c.accent,
                                        (1 - (i - p).abs()).clamp(0.0, 1.0),
                                      ),
                                      shape: const StadiumBorder(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Tag(
                              'R29.3',
                              'Skip and continue',
                              child: Row(
                                children: <Widget>[
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _finish,
                                    child: SizedBox(
                                      width: 84,
                                      height: 56,
                                      child: Center(
                                        child: Text(
                                          'Skip',
                                          style: LumenType.text(
                                            16,
                                            weight: 620,
                                            color: c.inkMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Pressable(
                                      onTap: last
                                          ? _finish
                                          : () => _go(_index + 1),
                                      child: Container(
                                        height: 56,
                                        alignment: Alignment.center,
                                        decoration: ShapeDecoration(
                                          color: c.accent,
                                          shape: const StadiumBorder(),
                                        ),
                                        child: Text(
                                          last ? 'Get started' : 'Continue',
                                          style: LumenType.text(
                                            16.5,
                                            weight: 680,
                                            color: c.onAccent,
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (_finished)
            Positioned.fill(
              child: ListenableBuilder(
                listenable: _done,
                builder: (BuildContext context, Widget? _) {
                  final double v = _done.value;
                  return ColoredBox(
                    color: c.bg.withValues(alpha: v.clamp(0.0, 1.0)),
                    child: Opacity(
                      opacity: v.clamp(0.0, 1.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Transform.scale(
                            scale: v,
                            child: Container(
                              width: 112,
                              height: 112,
                              decoration: const ShapeDecoration(
                                color: Color(0xFF2FA84F),
                                shape: CircleBorder(),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "You're set",
                            style: LumenType.display(
                              34,
                              weight: 740,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'That is the whole setup. Everything else can wait.',
                            style: LumenType.text(15.5, color: c.inkMuted),
                          ),
                          const SizedBox(height: 26),
                          Pressable(
                            onTap: _restart,
                            child: Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                              ),
                              alignment: Alignment.center,
                              decoration: ShapeDecoration(
                                shape: StadiumBorder(
                                  side: BorderSide(color: c.inkFaint),
                                ),
                              ),
                              child: Text(
                                'Show it again',
                                style: LumenType.text(
                                  15,
                                  weight: 640,
                                  color: c.ink,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          Positioned(
            top: safe.top + 44,
            left: 16,
            right: 16,
            child: const ScreenBar(number: 29),
          ),
        ],
      ),
    );
  }
}

class _Art extends CustomPainter {
  const _Art(this.p, this.a, this.b);
  final double p;
  final Color a, b;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = math.min(size.width, size.height) * 0.34;
    // Three shapes from the library, one per step; the swipe morphs between them.
    final double v = (p * 2 + 1).clamp(0.0, 6.9);
    final Path back = ShapeLib.at(
      ShapeLib.gallery,
      v + 2,
      c.translate(r * 0.42, -r * 0.2),
      r * 0.72,
      -p * 0.5,
    );
    canvas.drawPath(back, Paint()..color = b.withValues(alpha: 0.28));
    final Path front = ShapeLib.at(ShapeLib.gallery, v, c, r, p * 0.6);
    canvas.drawPath(
      front,
      Paint()
        ..shader = ui.Gradient.linear(
          c.translate(-r, -r),
          c.translate(r, r),
          <Color>[a, b],
        ),
    );
    canvas.save();
    canvas.clipPath(front);
    canvas.drawCircle(
      c.translate(-r * 0.4, -r * 0.5),
      r * 0.7,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Art old) => old.p != p || old.a != a || old.b != b;
}
