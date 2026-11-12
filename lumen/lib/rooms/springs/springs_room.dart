import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/room_header.dart';

class _Preset {
  const _Preset(this.name, this.stiffness, this.ratio);
  final String name;
  final double stiffness;
  final double ratio;
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: stiffness,
    ratio: ratio,
  );
}

const List<_Preset> _presets = <_Preset>[
  _Preset('Bouncy', 260, 0.42),
  _Preset('Natural', 420, 0.72),
  _Preset('Snappy', 1100, 0.92),
  _Preset('Gentle', 120, 1.0),
];

/// The classic way: a fixed duration and an easing curve. Every new target
/// restarts it from rest, which is the point of the comparison.
const Duration _curveDuration = Duration(milliseconds: 420);
const Curve _curve = Curves.easeInOutCubic;
const double _ballRadius = 24;

/// Room 02. One ball animated with a curve, one with a spring. Both get the
/// same input: tap to move the target, drag to move the target continuously,
/// grab a ball to hold both, throw to release.
class SpringsRoom extends StatefulWidget {
  const SpringsRoom({super.key});

  @override
  State<SpringsRoom> createState() => _SpringsRoomState();
}

class _SpringsRoomState extends State<SpringsRoom>
    with TickerProviderStateMixin {
  int _preset = 0;
  int _plotFrom = 0;
  Offset _anchor = const Offset(0.5, 0.5);

  late final SpringValue _sx = SpringValue(
    this,
    value: 0.5,
    settleDistance: 0.006,
    settleVelocity: 0.08,
  );
  late final SpringValue _sy = SpringValue(
    this,
    value: 0.5,
    settleDistance: 0.006,
    settleVelocity: 0.08,
  );
  late final AnimationController _curveCtl = AnimationController(
    vsync: this,
    duration: _curveDuration,
  );
  Offset _curveFrom = const Offset(0.5, 0.5);
  Offset _curveTo = const Offset(0.5, 0.5);

  bool _holding = false;
  bool _dragTarget = false;
  Offset _heldS = Offset.zero, _heldC = Offset.zero;
  Offset _gS = Offset.zero, _gC = Offset.zero;
  late final SpringValue _lift = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _plotT = SpringValue(
    this,
    value: 1,
    spring: Motions.spatial,
  );

  Size _panel = const Size(1, 1);
  final _Trail _trail = _Trail();
  late final Ticker _sampler = createTicker(_sample);
  int _still = 0;
  int _settles = 0;

  Offset get _springPos => _holding ? _heldS : Offset(_sx.value, _sy.value);
  Offset get _curvePos => _holding
      ? _heldC
      : Offset.lerp(_curveFrom, _curveTo, _curve.transform(_curveCtl.value))!;
  bool get _moving =>
      _holding || _sx.isAnimating || _sy.isAnimating || _curveCtl.isAnimating;

  @override
  void initState() {
    super.initState();
    _trail.reset(_springPos, _curvePos);
  }

  @override
  void dispose() {
    _sampler.dispose();
    _sx.dispose();
    _sy.dispose();
    _curveCtl.dispose();
    _lift.dispose();
    _plotT.dispose();
    _trail.dispose();
    super.dispose();
  }

  void _kick() {
    _still = 0;
    if (!_sampler.isActive) {
      _sampler.start();
    }
  }

  void _sample(Duration _) {
    _trail.push(_springPos, _curvePos, _anchor);
    if (!_moving && _trail.collapsed) {
      if (++_still > 2) {
        _sampler.stop();
      }
    } else {
      _still = 0;
    }
  }

  Offset _norm(Offset local) =>
      Offset(local.dx / _panel.width, local.dy / _panel.height);

  Offset _clamp(Offset p) {
    final double mx = (_ballRadius + 6) / _panel.width,
        my = (_ballRadius + 6) / _panel.height;
    return Offset(p.dx.clamp(mx, 1 - mx), p.dy.clamp(my, 1 - my));
  }

  double _distPx(Offset a, Offset b) => Offset(
    (a.dx - b.dx) * _panel.width,
    (a.dy - b.dy) * _panel.height,
  ).distance;

  void _goSpring({Offset? velocity}) {
    _settles = 2;
    void settled() {
      if (--_settles == 0) {
        Haptics.tick();
      }
    }

    _sx.onSettle = settled;
    _sy.onSettle = settled;
    final SpringDescription s = _presets[_preset].spring;
    _sx.animateTo(_anchor.dx, spring: s, velocity: velocity?.dx);
    _sy.animateTo(_anchor.dy, spring: s, velocity: velocity?.dy);
  }

  void _goCurve({Offset? from}) {
    _curveFrom = from ?? _curvePos;
    _curveTo = _anchor;
    _curveCtl.duration = Motion.reduced
        ? const Duration(milliseconds: 80)
        : _curveDuration;
    _curveCtl.forward(from: 0);
  }

  void _setTarget(Offset local) {
    _anchor = _clamp(_norm(local));
    _goCurve();
    _goSpring();
    _kick();
  }

  void _panStart(Offset local, bool springPanel) {
    final Offset p = _norm(local);
    final Offset ball = springPanel ? _springPos : _curvePos;
    if (_distPx(p, ball) < _ballRadius + 28) {
      // Catch both balls exactly where they are, mid-flight or not.
      _heldS = _springPos;
      _heldC = _curvePos;
      _gS = _heldS - p;
      _gC = _heldC - p;
      _sx.jumpTo(_heldS.dx);
      _sy.jumpTo(_heldS.dy);
      _curveCtl.stop();
      _holding = true;
      _lift.animateTo(1, velocity: 8);
      _kick();
    } else {
      _dragTarget = true;
      _setTarget(local);
    }
  }

  void _panUpdate(Offset local) {
    if (_holding) {
      final Offset p = _norm(local);
      _heldS = _clamp(p + _gS);
      _heldC = _clamp(p + _gC);
      _kick();
    } else if (_dragTarget) {
      _setTarget(local);
    }
  }

  void _panEnd(Velocity v) {
    if (_holding) {
      final Offset vel = Offset(
        v.pixelsPerSecond.dx / _panel.width,
        v.pixelsPerSecond.dy / _panel.height,
      );
      final Offset heldS = _heldS, heldC = _heldC;
      _holding = false;
      _sx.jumpTo(heldS.dx);
      _sy.jumpTo(heldS.dy);
      _goSpring(velocity: vel);
      _goCurve(from: heldC);
      _lift.animateTo(0);
      _kick();
    }
    _dragTarget = false;
  }

  void _choosePreset(int i) {
    if (i == _preset) {
      return;
    }
    setState(() {
      _plotFrom = _preset;
      _preset = i;
    });
    _plotT.jumpTo(0);
    _plotT.animateTo(1);
    // Replay so the difference is visible at once.
    _anchor = Offset(
      _anchor.dx < 0.5 ? 0.78 : 0.22,
      _anchor.dy < 0.5 ? 0.7 : 0.3,
    );
    _anchor = _clamp(_anchor);
    _goCurve();
    _goSpring();
    _kick();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const RoomHeader(
              number: 2,
              title: 'Springs',
              hint: 'Tap to move the target, or drag it around. Grab a ball, then throw it. Tap again mid-flight.',
            ),
            const SizedBox(height: 14),
            Expanded(child: _panelView(c, spring: false)),
            const SizedBox(height: 10),
            Expanded(child: _panelView(c, spring: true)),
            const SizedBox(height: 12),
            _controls(c),
          ],
        ),
      ),
    );
  }

  Widget _panelView(LumenColors c, {required bool spring}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        _panel = Size(box.maxWidth, box.maxHeight);
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: c.surface,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: c.hairline),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              RepaintBoundary(
                child: CustomPaint(
                  painter: _PanelPainter(this, spring: spring, colors: c),
                ),
              ),
              Positioned(
                left: 16,
                top: 14,
                child: IgnorePointer(
                  child: Row(
                    children: <Widget>[
                      Text(
                        spring ? 'SPRING' : 'CURVE',
                        style: LumenType.label(
                          color: spring ? c.accent : c.inkMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        spring ? _presets[_preset].name : '420 ms, ease in-out',
                        style: LumenType.text(
                          12,
                          color: c.inkFaint,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (TapUpDetails d) => _setTarget(d.localPosition),
                onPanStart: (DragStartDetails d) =>
                    _panStart(d.localPosition, spring),
                onPanUpdate: (DragUpdateDetails d) =>
                    _panUpdate(d.localPosition),
                onPanEnd: (DragEndDetails d) => _panEnd(d.velocity),
                onPanCancel: () => _panEnd(Velocity.zero),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _controls(LumenColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      decoration: ShapeDecoration(
        color: c.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: c.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Segmented<int>(
            values: const <int>[0, 1, 2, 3],
            labels: _presets.map((_Preset p) => p.name).toList(),
            value: _preset,
            onChanged: _choosePreset,
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 74,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _PlotPainter(
                  from: _presets[_plotFrom].spring,
                  to: _presets[_preset].spring,
                  t: _plotT,
                  colors: c,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent positions of both balls, for the motion trails.
class _Trail extends ChangeNotifier {
  static const int length = 26;
  final List<Offset> s = <Offset>[];
  final List<Offset> c = <Offset>[];
  Offset anchor = const Offset(0.5, 0.5);

  void reset(Offset sp, Offset cp) {
    s
      ..clear()
      ..add(sp);
    c
      ..clear()
      ..add(cp);
  }

  void push(Offset sp, Offset cp, Offset a) {
    anchor = a;
    s.add(sp);
    c.add(cp);
    if (s.length > length) {
      s.removeAt(0);
    }
    if (c.length > length) {
      c.removeAt(0);
    }
    notifyListeners();
  }

  bool get collapsed {
    bool same(List<Offset> l) =>
        l.every((Offset o) => (o - l.last).distanceSquared < 1e-9);
    return same(s) && same(c);
  }
}

class _PanelPainter extends CustomPainter {
  _PanelPainter(this.room, {required this.spring, required this.colors})
    : super(repaint: Listenable.merge(<Listenable>[room._trail, room._lift]));

  final _SpringsRoomState room;
  final bool spring;
  final LumenColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final LumenColors c = colors;
    // Dot grid, so motion reads against something.
    final Paint dot = Paint()..color = c.ink.withValues(alpha: 0.07);
    for (double y = 28; y < size.height; y += 28) {
      for (double x = 28; x < size.width; x += 28) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }

    Offset px(Offset n) => Offset(n.dx * size.width, n.dy * size.height);
    final Offset anchor = px(room._trail.anchor);
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = c.ink.withValues(alpha: 0.22);
    canvas.drawCircle(anchor, _ballRadius + 6, ring);
    canvas.drawLine(anchor.translate(-5, 0), anchor.translate(5, 0), ring);
    canvas.drawLine(anchor.translate(0, -5), anchor.translate(0, 5), ring);

    final Color ballColor = spring
        ? c.accent
        : (c.dark ? const Color(0xFFB8BCC8) : const Color(0xFF5B5E68));
    final List<Offset> pts = spring ? room._trail.s : room._trail.c;
    for (int i = 1; i < pts.length; i++) {
      final double k = i / pts.length;
      canvas.drawLine(
        px(pts[i - 1]),
        px(pts[i]),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3 + 9 * k
          ..color = ballColor.withValues(alpha: 0.5 * k * k),
      );
    }

    final Offset ball = px(spring ? room._springPos : room._curvePos);
    final double lift = room._lift.value;
    final double r = _ballRadius * (1 + 0.12 * lift);
    canvas.drawCircle(
      ball.translate(0, 4 + 6 * lift),
      r,
      Paint()
        ..color = c.shadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 6 * lift),
    );
    canvas.drawCircle(ball, r, Paint()..color = ballColor);
    canvas.drawCircle(
      ball.translate(-r * 0.28, -r * 0.32),
      r * 0.34,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.2),
    );
  }

  @override
  bool shouldRepaint(_PanelPainter old) =>
      old.spring != spring || old.colors != colors;
}

/// Position over time for one move: the curve against the chosen spring.
class _PlotPainter extends CustomPainter {
  _PlotPainter({
    required this.from,
    required this.to,
    required this.t,
    required this.colors,
  }) : super(repaint: t);
  final SpringDescription from;
  final SpringDescription to;
  final SpringValue t;
  final LumenColors colors;

  static const double _span = 1.3; // seconds shown

  @override
  void paint(Canvas canvas, Size size) {
    final LumenColors c = colors;
    const double top = 8, bottom = 18;
    final double h = size.height - top - bottom;
    double y(double v) => top + h - (v / 1.32) * h;
    double x(double s) => s / _span * size.width;

    final Paint guide = Paint()
      ..color = c.ink.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y(1)), Offset(size.width, y(1)), guide);
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), guide);

    final SpringSimulation a = SpringSimulation(from, 0, 1, 0);
    final SpringSimulation b = SpringSimulation(to, 0, 1, 0);
    final double k = t.value;
    final Path spring = Path(), curve = Path();
    for (int i = 0; i <= 120; i++) {
      final double s = i / 120 * _span;
      final double sv = lerpDouble(a.x(s), b.x(s), k)!;
      final double cv = _curve.transform(math.min(s / 0.42, 1));
      if (i == 0) {
        spring.moveTo(x(s), y(sv));
        curve.moveTo(x(s), y(cv));
      } else {
        spring.lineTo(x(s), y(sv));
        curve.lineTo(x(s), y(cv));
      }
    }
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      curve,
      line
        ..color = c.inkFaint
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      spring,
      line
        ..color = c.accent
        ..strokeWidth = 2.6,
    );

    void label(String text, Color color, double dx) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: text,
          style: LumenType.text(11, weight: 560, color: color, height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(dx, size.height - tp.height));
      tp.dispose();
    }

    label('Position over 1.3 s', c.inkFaint, 0);
    label('Curve', c.inkMuted, size.width - 96);
    label('Spring', c.accent, size.width - 46);
  }

  @override
  bool shouldRepaint(_PlotPainter old) =>
      old.from != from || old.to != to || old.colors != colors;
}
