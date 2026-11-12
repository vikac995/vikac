import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/room_header.dart';
import '../details/small_things.dart';

/// Room 08. Controls with physical character: a knob with detents you can
/// flick, and wheels that click as they turn.
class DialsRoom extends StatelessWidget {
  const DialsRoom({super.key});

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 32),
        children: <Widget>[
          const RoomHeader(
            number: 8,
            title: 'Dials',
            hint:
                'Trend: tactile controls are back. Not fake leather, but weight, notches and momentum '
                'you can feel through haptics. Turn the knob slowly, then flick it.',
          ),
          const SizedBox(height: 22),
          const Center(child: _Knob()),
          const SizedBox(height: 34),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text('ALARM', style: LumenType.label(color: c.inkFaint)),
          ),
          const _AlarmWheels(),
        ],
      ),
    );
  }
}

class _Knob extends StatefulWidget {
  const _Knob();

  @override
  State<_Knob> createState() => _KnobState();
}

class _KnobState extends State<_Knob> with TickerProviderStateMixin {
  static const double _sweep = 300 * math.pi / 180; // usable rotation
  static const int _steps = 40; // detents
  static const double _size = 250;

  double _angle = _sweep * 0.35; // 0 to _sweep
  double? _lastFinger;
  double _velocity = 0;
  Duration _lastT = Duration.zero;
  int _lastDetent = 14;
  final Stopwatch _clock = Stopwatch()..start();
  late final Ticker _fling = createTicker(_tickFling);
  FrictionSimulation? _sim;
  Duration _flingStart = Duration.zero;
  late final SpringValue _snap = SpringValue(
    this,
    spring: Motions.expressiveFast,
  )..addListener(_onSnap);
  bool _snapping = false;

  double get _value => (_angle / _sweep).clamp(0.0, 1.0);

  @override
  void dispose() {
    _fling.dispose();
    _snap.dispose();
    super.dispose();
  }

  double _fingerAngle(Offset local) {
    final Offset d = local - const Offset(_size / 2, _size / 2);
    return math.atan2(d.dy, d.dx);
  }

  void _setAngle(double a) {
    setState(() => _angle = a);
    final int detent = (_value * _steps).round();
    if (detent != _lastDetent) {
      _lastDetent = detent;
      if (detent == 0 || detent == _steps) {
        Haptics.thud();
      } else {
        Haptics.tick();
      }
    }
  }

  void _start(DragStartDetails d) {
    _fling.stop();
    _snapping = false;
    _snap.jumpTo(_angle);
    _lastFinger = _fingerAngle(d.localPosition);
    _velocity = 0;
    _lastT = _clock.elapsed;
  }

  void _update(DragUpdateDetails d) {
    final double f = _fingerAngle(d.localPosition);
    double delta = f - _lastFinger!;
    if (delta > math.pi) {
      delta -= 2 * math.pi;
    } else if (delta < -math.pi) {
      delta += 2 * math.pi;
    }
    _lastFinger = f;
    // Past the ends the knob resists, like a rubber stop.
    double next = _angle + delta;
    if (next < 0 || next > _sweep) {
      next = _angle + delta * 0.25;
    }
    final Duration now = _clock.elapsed;
    final double dt = (now - _lastT).inMicroseconds / 1e6;
    if (dt > 0) {
      _velocity = 0.7 * _velocity + 0.3 * (delta / dt);
    }
    _lastT = now;
    _setAngle(next);
  }

  void _end(DragEndDetails d) {
    if (_angle < 0 || _angle > _sweep || _velocity.abs() < 1.5) {
      _snapToDetent(_velocity * 0.1);
      return;
    }
    // Flicked: coast on friction, then settle into a notch.
    _sim = FrictionSimulation(0.02, _angle, _velocity.clamp(-40.0, 40.0));
    _flingStart = Duration.zero;
    _fling.start();
  }

  void _tickFling(Duration e) {
    if (_flingStart == Duration.zero) {
      _flingStart = e;
    }
    final double t = (e - _flingStart).inMicroseconds / 1e6;
    final FrictionSimulation sim = _sim!;
    final double a = sim.x(t);
    if (a < 0 || a > _sweep) {
      _fling.stop();
      _setAngle(a.clamp(0.0, _sweep));
      // Hits the stop and bounces back off it.
      _snapToDetent(-sim.dx(t) * 0.25);
      return;
    }
    _setAngle(a);
    if (sim.dx(t).abs() < 1.2) {
      _fling.stop();
      _snapToDetent(sim.dx(t));
    }
  }

  void _snapToDetent(double velocity) {
    final double target =
        ((_angle.clamp(0.0, _sweep) / _sweep * _steps).round() / _steps) *
        _sweep;
    _snapping = true;
    _snap.jumpTo(_angle);
    _snap.animateTo(target, velocity: velocity);
  }

  void _onSnap() {
    if (_snapping) {
      _setAngle(_snap.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final int shown = (_value * 100).round();
    return Column(
      children: <Widget>[
        Semantics(
          slider: true,
          label: 'Volume',
          value: '$shown',
          child: GestureDetector(
            onPanStart: _start,
            onPanUpdate: _update,
            onPanEnd: _end,
            child: SizedBox.square(
              dimension: _size,
              child: CustomPaint(
                painter: _KnobPainter(_angle, _sweep, _steps, c),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Odometer(
              value: shown,
              digits: 3,
              style: LumenType.display(
                44,
                weight: 700,
                color: c.ink,
                height: 1,
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'volume',
                style: LumenType.text(14, color: c.inkMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KnobPainter extends CustomPainter {
  const _KnobPainter(this.angle, this.sweep, this.steps, this.c);
  final double angle;
  final double sweep;
  final int steps;
  final LumenColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset o = size.center(Offset.zero);
    final double rOuter = size.width / 2;
    final double rKnob = rOuter * 0.66;
    final double start = math.pi / 2 + (2 * math.pi - sweep) / 2; // bottom-left
    final double v = (angle / sweep).clamp(0.0, 1.0);

    // Scale: ticks, lit up to the current value.
    for (int i = 0; i <= steps; i++) {
      final double a = start + sweep * i / steps;
      final bool major = i % 5 == 0;
      final bool lit = i / steps <= v + 1e-6;
      final Offset d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        o + d * (rOuter - (major ? 18 : 13)),
        o + d * (rOuter - 4),
        Paint()
          ..strokeWidth = major ? 3 : 2
          ..strokeCap = StrokeCap.round
          ..color = lit ? c.accent : c.ink.withValues(alpha: 0.16),
      );
    }

    // Body: the light is fixed above, so the shading does not turn with it.
    canvas.drawCircle(
      o.translate(0, 10),
      rKnob,
      Paint()
        ..color = c.shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    final Rect body = Rect.fromCircle(center: o, radius: rKnob);
    canvas.drawCircle(
      o,
      rKnob,
      Paint()
        ..shader = ui.Gradient.linear(
          body.topCenter,
          body.bottomCenter,
          c.dark
              ? <Color>[const Color(0xFF3A3E49), const Color(0xFF1A1C22)]
              : <Color>[const Color(0xFFFFFFFF), const Color(0xFFDCD6CB)],
        ),
    );
    // Brushed metal: a sweep of light and dark that stays put.
    canvas.drawCircle(
      o,
      rKnob * 0.82,
      Paint()
        ..shader = ui.Gradient.sweep(
          o,
          <Color>[
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: c.dark ? 0.16 : 0.5),
            Colors.white.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: c.dark ? 0.25 : 0.08),
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: c.dark ? 0.16 : 0.5),
            Colors.white.withValues(alpha: 0.0),
          ],
          <double>[0, 0.12, 0.25, 0.5, 0.62, 0.75, 1],
        ),
    );
    // Knurled rim and the pointer turn with the knob.
    for (int i = 0; i < 72; i++) {
      final double a = angle + i / 72 * 2 * math.pi;
      final Offset d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        o + d * (rKnob - 5),
        o + d * rKnob,
        Paint()
          ..strokeWidth = 1.4
          ..color = (c.dark ? Colors.black : Colors.black).withValues(
            alpha: 0.22,
          ),
      );
    }
    canvas.drawCircle(
      o,
      rKnob,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: c.dark ? 0.1 : 0.7),
    );
    final double pa = start + angle;
    canvas.drawCircle(
      o + Offset(math.cos(pa), math.sin(pa)) * rKnob * 0.72,
      6,
      Paint()..color = c.accent,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter old) => old.angle != angle || old.c != c;
}

class _AlarmWheels extends StatefulWidget {
  const _AlarmWheels();

  @override
  State<_AlarmWheels> createState() => _AlarmWheelsState();
}

class _AlarmWheelsState extends State<_AlarmWheels> {
  int _h = 7, _m = 30;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    Widget wheel(int count, int initial, ValueChanged<int> onChanged) {
      return SizedBox(
        width: 96,
        child: ListWheelScrollView.useDelegate(
          controller: FixedExtentScrollController(initialItem: initial),
          itemExtent: 54,
          perspective: 0.004,
          diameterRatio: 1.25,
          squeeze: 1.0,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (int i) {
            // One click per number, like a ratchet.
            Haptics.tick();
            onChanged(i % count);
          },
          childDelegate: ListWheelChildLoopingListDelegate(
            children: <Widget>[
              for (int i = 0; i < count; i++)
                Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: LumenType.display(
                      40,
                      weight: 640,
                      color: c.ink,
                      height: 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Container(
          height: 230,
          decoration: ShapeDecoration(
            color: c.surface,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: c.hairline),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Selection band behind the centre row.
              Container(
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: ShapeDecoration(
                  color: c.ink.withValues(alpha: 0.06),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              ShaderMask(
                // Fade the wheels out toward the top and bottom edges.
                shaderCallback: (Rect r) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const <Color>[
                    Color(0x00000000),
                    Color(0xFF000000),
                    Color(0xFF000000),
                    Color(0x00000000),
                  ],
                  stops: const <double>[0, 0.3, 0.7, 1],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    wheel(24, 7, (int v) => setState(() => _h = v)),
                    Text(
                      ':',
                      style: LumenType.display(
                        40,
                        weight: 640,
                        color: c.inkMuted,
                      ),
                    ),
                    wheel(60, 30, (int v) => setState(() => _m = v)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(_untilText(), style: LumenType.text(13.5, color: c.inkMuted)),
      ],
    );
  }

  String _untilText() {
    final DateTime now = DateTime.now();
    DateTime at = DateTime(now.year, now.month, now.day, _h, _m);
    if (!at.isAfter(now)) {
      at = at.add(const Duration(days: 1));
    }
    final Duration d = at.difference(now);
    return 'Rings in ${d.inHours} h ${d.inMinutes % 60} min';
  }
}
