import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

/// Motion tokens. Two families, as in Material 3 Expressive:
/// spatial springs move things and may overshoot; effects springs change
/// opacity and colour and never bounce.
abstract final class Motions {
  static SpringDescription _s(double stiffness, double ratio) =>
      SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: stiffness,
        ratio: ratio,
      );

  // Expressive: visible overshoot, for hero moments.
  static final SpringDescription expressiveFast = _s(800, 0.6);
  static final SpringDescription expressive = _s(380, 0.7);
  static final SpringDescription expressiveSlow = _s(200, 0.75);

  // Standard: almost no overshoot, for everyday feedback.
  static final SpringDescription spatialFast = _s(1400, 0.9);
  static final SpringDescription spatial = _s(700, 0.9);
  static final SpringDescription spatialSlow = _s(300, 0.9);

  // Effects: critically damped.
  static final SpringDescription effectsFast = _s(3800, 1);
  static final SpringDescription effects = _s(1600, 1);
  static final SpringDescription effectsSlow = _s(800, 1);

  /// Tracks a finger: stiff enough to feel attached, soft enough to show weight.
  static final SpringDescription follow = _s(2600, 0.85);

  /// Used for everything when reduced motion is on: arrives in a fraction of
  /// the normal time with no overshoot.
  static final SpringDescription reduced = _s(9000, 1);
}

/// Global motion preference, set from settings.
abstract final class Motion {
  static bool reduced = false;
}

/// A value driven by a spring. Retargeting mid-flight keeps the current
/// velocity, so every animation built on this is interruptible.
class SpringValue extends ChangeNotifier implements ValueListenable<double> {
  SpringValue(
    TickerProvider vsync, {
    double value = 0,
    SpringDescription? spring,
    this.settleDistance = 0.004,
    this.settleVelocity = 0.05,
    this.onSettle,
  }) : _value = value,
       _target = value,
       spring = spring ?? Motions.spatial {
    _ticker = vsync.createTicker(_tick);
  }

  SpringDescription spring;

  /// How close to the target counts as "arrived" for [onSettle]. The spring
  /// itself keeps running to a much tighter tolerance.
  final double settleDistance;
  final double settleVelocity;

  /// Fires once per run when the value has perceptibly come to rest.
  VoidCallback? onSettle;

  late final Ticker _ticker;
  SpringSimulation? _sim;
  Duration _last = Duration.zero;
  Duration _start = Duration.zero;
  double _value;
  double _velocity = 0;
  double _target;
  bool _settled = true;

  @override
  double get value => _value;
  double get velocity => _velocity;
  double get target => _target;
  bool get isAnimating => _ticker.isActive;

  void animateTo(double target, {SpringDescription? spring, double? velocity}) {
    _target = target;
    final SpringDescription s = Motion.reduced
        ? Motions.reduced
        : (spring ?? this.spring);
    final double v = Motion.reduced ? 0 : (velocity ?? _velocity);
    _velocity = v;
    _sim = SpringSimulation(
      s,
      _value,
      target,
      v,
      tolerance: const Tolerance(distance: 1e-4, velocity: 1e-3),
    );
    _settled = false;
    if (_ticker.isActive) {
      _start = _last;
    } else {
      _start = Duration.zero;
      _last = Duration.zero;
      _ticker.start();
    }
  }

  /// Sets the value directly, for example while a finger holds it.
  void jumpTo(double value, {double velocity = 0}) {
    _ticker.stop();
    _sim = null;
    _settled = true;
    _target = value;
    _velocity = velocity;
    if (_value != value) {
      _value = value;
      notifyListeners();
    }
  }

  void _tick(Duration elapsed) {
    _last = elapsed;
    final SpringSimulation sim = _sim!;
    final double t =
        (elapsed - _start).inMicroseconds / Duration.microsecondsPerSecond;
    _value = sim.x(t);
    _velocity = sim.dx(t);
    if (!_settled &&
        (_value - _target).abs() <= settleDistance &&
        _velocity.abs() <= settleVelocity) {
      _settled = true;
      onSettle?.call();
    }
    if (sim.isDone(t)) {
      _value = _target;
      _velocity = 0;
      _ticker.stop();
      if (!_settled) {
        _settled = true;
        onSettle?.call();
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
