import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/panel.dart';
import '../../widgets/room_header.dart';
import '../details/small_things.dart';

/// Room 23. Entering numbers without a keyboard: a ruler for weight, steppers
/// that repeat while held, and the rows of a workout set.
class InputsRoom extends StatefulWidget {
  const InputsRoom({super.key});

  @override
  State<InputsRoom> createState() => _InputsRoomState();
}

class _InputsRoomState extends State<InputsRoom> {
  double _weight = 81.5;
  final List<int> _kg = <int>[80, 80, 75];
  final List<int> _reps = <int>[8, 8, 6];
  final List<bool> _done = <bool>[false, false, false];

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final bool all = _done.every((bool d) => d);
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 23,
          title: 'Inputs',
          hint:
              'Pattern: numbers people enter every day should not need a keyboard. '
              'Drag the ruler or flick it. Hold a stepper to run. Tick the sets.',
        ),
        const SectionLabel('Weight ruler'),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    _weight.toStringAsFixed(1),
                    style: LumenType.display(
                      54,
                      weight: 700,
                      color: c.ink,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7, left: 6),
                    child: Text(
                      'kg',
                      style: LumenType.text(17, color: c.inkMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Ruler(
                value: _weight,
                min: 30,
                max: 200,
                step: 0.5,
                onChanged: (double v) => setState(() => _weight = v),
              ),
            ],
          ),
        ),
        const SectionLabel(
          'A workout set',
          detail: 'Last time is shown, already filled in. Change only what changed.',
        ),
        Panel(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  SizedBox(
                    width: 30,
                    child: Text(
                      'Set',
                      style: LumenType.text(12, weight: 600, color: c.inkFaint),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'kg',
                        style: LumenType.text(
                          12,
                          weight: 600,
                          color: c.inkFaint,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'reps',
                        style: LumenType.text(
                          12,
                          weight: 600,
                          color: c.inkFaint,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 52),
                ],
              ),
              for (int i = 0; i < 3; i++)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _done[i] ? 0.55 : 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${i + 1}',
                            style: LumenType.text(
                              16,
                              weight: 650,
                              color: c.ink,
                            ),
                          ),
                        ),
                        Expanded(
                          child: NumberStepper(
                            value: _kg[i],
                            step: 5,
                            min: 0,
                            max: 300,
                            onChanged: (int v) => setState(() => _kg[i] = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: NumberStepper(
                            value: _reps[i],
                            step: 1,
                            min: 0,
                            max: 50,
                            onChanged: (int v) => setState(() => _reps[i] = v),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _Tick(
                          done: _done[i],
                          onTap: () => setState(() => _done[i] = !_done[i]),
                        ),
                      ],
                    ),
                  ),
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: all
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF2FA84F),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Set done: ${_kg.reduce((int a, int b) => a + b) > 0 ? '${List<int>.generate(3, (int i) => _kg[i] * _reps[i]).reduce((int a, int b) => a + b)} kg lifted' : 'bodyweight'}',
                                style: LumenType.text(
                                  14.5,
                                  weight: 600,
                                  color: c.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A horizontal ruler. Drag it under the fixed marker; it clicks at every
/// step, coasts when flicked and settles on a step.
class Ruler extends StatefulWidget {
  const Ruler({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });
  final double value, min, max, step;
  final ValueChanged<double> onChanged;

  @override
  State<Ruler> createState() => _RulerState();
}

class _RulerState extends State<Ruler> with TickerProviderStateMixin {
  static const double _pxPerStep = 14;
  late double _pos =
      widget.value / widget.step; // in steps, fractional while moving
  late int _lastStep = _pos.round();
  late final Ticker _fling = createTicker(_onFling);
  FrictionSimulation? _sim;
  Duration _flingStart = Duration.zero;
  late final SpringValue _snap =
      SpringValue(
        this,
        spring: Motions.spatialFast,
        settleDistance: 0.02,
        settleVelocity: 0.5,
      )..addListener(() {
        if (_snapping) {
          _set(_snap.value);
        }
      });
  bool _snapping = false;

  double get _lo => widget.min / widget.step;
  double get _hi => widget.max / widget.step;

  void _set(double pos) {
    setState(() => _pos = pos);
    final int s = pos.round().clamp(_lo.round(), _hi.round());
    if (s != _lastStep) {
      _lastStep = s;
      Haptics.tick();
      widget.onChanged(s * widget.step);
    }
  }

  void _settle(double velocity) {
    _snapping = true;
    _snap.jumpTo(_pos);
    _snap.animateTo(
      _pos.round().clamp(_lo.round(), _hi.round()).toDouble(),
      velocity: velocity,
    );
  }

  void _onFling(Duration e) {
    if (_flingStart == Duration.zero) {
      _flingStart = e;
    }
    final double t = (e - _flingStart).inMicroseconds / 1e6;
    final double x = _sim!.x(t);
    if (x <= _lo || x >= _hi || _sim!.dx(t).abs() < 2.5) {
      _fling.stop();
      _set(x.clamp(_lo, _hi));
      _settle(_sim!.dx(t));
      return;
    }
    _set(x);
  }

  @override
  void dispose() {
    _fling.dispose();
    _snap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Semantics(
      slider: true,
      value: '${widget.value}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          _fling.stop();
          _snapping = false;
        },
        onHorizontalDragUpdate: (DragUpdateDetails d) {
          double next = _pos - d.delta.dx / _pxPerStep;
          // Past the ends the ruler resists.
          if (next < _lo || next > _hi) {
            next = _pos - d.delta.dx / _pxPerStep * 0.3;
          }
          _set(next);
        },
        onHorizontalDragEnd: (DragEndDetails d) {
          final double v = -d.velocity.pixelsPerSecond.dx / _pxPerStep;
          if (v.abs() < 6 || _pos < _lo || _pos > _hi) {
            _settle(v * 0.2);
            return;
          }
          _sim = FrictionSimulation(0.012, _pos, v);
          _flingStart = Duration.zero;
          _fling.start();
        },
        child: SizedBox(
          height: 74,
          width: double.infinity,
          child: CustomPaint(
            painter: _RulerPainter(_pos, widget.step, _lo, _hi, _pxPerStep, c),
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  const _RulerPainter(this.pos, this.step, this.lo, this.hi, this.px, this.c);
  final double pos, step, lo, hi, px;
  final LumenColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final double mid = size.width / 2;
    final int from = (pos - mid / px).floor() - 1,
        to = (pos + mid / px).ceil() + 1;
    final int perUnit = (1 / step).round();
    for (int s = from; s <= to; s++) {
      if (s < lo || s > hi) {
        continue;
      }
      final double x = mid + (s - pos) * px;
      final bool major = s % (perUnit * 5) == 0, unit = s % perUnit == 0;
      // Ticks fade toward the edges.
      final double a = (1 - ((x - mid).abs() / mid)).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(x, 0),
        Offset(
          x,
          major
              ? 34
              : unit
              ? 24
              : 14,
        ),
        Paint()
          ..strokeWidth = major ? 2.5 : 1.5
          ..strokeCap = StrokeCap.round
          ..color = c.ink.withValues(
            alpha:
                (major
                    ? 0.9
                    : unit
                    ? 0.5
                    : 0.25) *
                a,
          ),
      );
      if (major) {
        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: '${(s * step).round()}',
            style: LumenType.text(
              12,
              weight: 600,
              color: c.inkMuted.withValues(alpha: a),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, 42));
        tp.dispose();
      }
    }
    // The fixed marker.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(mid, 22), width: 4, height: 48),
        const Radius.circular(2),
      ),
      Paint()..color = c.accent,
    );
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.pos != pos || old.c != c;
}

/// Minus, a rolling number, plus. Hold a button and it repeats, slowly at
/// first, then fast.
class NumberStepper extends StatefulWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final int value, step, min, max;
  final ValueChanged<int> onChanged;

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  Timer? _repeat;
  int _runs = 0;

  void _bump(int dir) {
    final int next = (widget.value + dir * widget.step).clamp(
      widget.min,
      widget.max,
    );
    if (next == widget.value) {
      Haptics.thud(); // an end stop
      _stop();
      return;
    }
    Haptics.tick();
    widget.onChanged(next);
  }

  void _hold(int dir) {
    _bump(dir);
    _runs = 0;
    void again() {
      _runs++;
      _bump(dir);
      _repeat = Timer(
        Duration(
          milliseconds: _runs < 4
              ? 160
              : _runs < 12
              ? 80
              : 40,
        ),
        again,
      );
    }

    _repeat = Timer(const Duration(milliseconds: 420), again);
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    Widget btn(IconData icon, int dir) => Listener(
      onPointerDown: (_) => _hold(dir),
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: SizedBox(
        width: 40,
        height: 48,
        child: Center(child: Icon(icon, size: 20, color: c.ink)),
      ),
    );
    return Container(
      height: 48,
      decoration: ShapeDecoration(
        color: c.ink.withValues(alpha: 0.07),
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: <Widget>[
          btn(Icons.remove_rounded, -1),
          Expanded(
            child: Center(
              child: Odometer(
                value: widget.value,
                digits: 3,
                style: LumenType.text(
                  17,
                  weight: 680,
                  color: c.ink,
                  height: 1.2,
                ),
              ),
            ),
          ),
          btn(Icons.add_rounded, 1),
        ],
      ),
    );
  }
}

class _Tick extends StatefulWidget {
  const _Tick({required this.done, required this.onTap});
  final bool done;
  final VoidCallback onTap;

  @override
  State<_Tick> createState() => _TickState();
}

class _TickState extends State<_Tick> with SingleTickerProviderStateMixin {
  late final SpringValue _v = SpringValue(
    this,
    value: widget.done ? 1 : 0,
    spring: Motions.expressiveFast,
  );

  @override
  void didUpdateWidget(_Tick old) {
    super.didUpdateWidget(old);
    if (old.done != widget.done) {
      _v.onSettle = widget.done ? Haptics.settle : null;
      _v.animateTo(widget.done ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Semantics(
      button: true,
      toggled: widget.done,
      label: 'Set done',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: ListenableBuilder(
              listenable: _v,
              builder: (BuildContext context, Widget? _) {
                final double on = _v.value.clamp(0.0, 1.0);
                return Container(
                  width: 36,
                  height: 36,
                  decoration: ShapeDecoration(
                    color: Color.lerp(
                      c.ink.withValues(alpha: 0.07),
                      const Color(0xFF2FA84F),
                      on,
                    ),
                    shape: const CircleBorder(),
                  ),
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * _v.value,
                    child: Icon(
                      Icons.check_rounded,
                      size: 22,
                      color: Color.lerp(c.inkFaint, Colors.white, on),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
