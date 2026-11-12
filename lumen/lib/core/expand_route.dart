import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import 'springs.dart';

/// A screen that grows out of the thing that was tapped, on a spring.
/// The page itself is never scaled or faded as a layer (that would break
/// glass inside it); it is revealed by an expanding clip.
class ExpandRoute<T> extends PageRoute<T> {
  ExpandRoute({
    required this.builder,
    required this.origin,
    required this.originColor,
    this.originRadius = 32,
  });

  final WidgetBuilder builder;
  final Rect origin;
  final Color originColor;
  final double originRadius;

  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.95,
  );

  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  @override
  bool get maintainState => true;
  @override
  bool get opaque => true;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 450);

  @override
  Simulation createSimulation({required bool forward}) {
    return SpringSimulation(
      Motion.reduced ? Motions.reduced : _spring,
      controller!.value,
      forward ? 1 : 0,
      Motion.reduced ? 0 : controller!.velocity,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double t = animation.value.clamp(0.0, 1.0);
        final Rect full = Offset.zero & MediaQuery.sizeOf(context);
        final Rect rect = Rect.lerp(origin, full, t)!;
        final double radius = lerpDouble(originRadius, 0, t * t)!;
        final double veil = (1 - t / 0.55).clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (t < 1)
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45 * t),
                ),
              ),
            ClipRSuperellipse(
              clipper: _RectClipper(rect, radius),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  child!,
                  if (veil > 0)
                    IgnorePointer(
                      child: ColoredBox(
                        color: originColor.withValues(alpha: veil),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}

class _RectClipper extends CustomClipper<RSuperellipse> {
  const _RectClipper(this.rect, this.radius);
  final Rect rect;
  final double radius;

  @override
  RSuperellipse getClip(Size size) =>
      RSuperellipse.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  Rect getApproximateClipRect(Size size) => rect;

  @override
  bool shouldReclip(_RectClipper oldClipper) =>
      oldClipper.rect != rect || oldClipper.radius != radius;
}

/// A curve shaped like a critically damped spring, for the few framework
/// animations that only accept curves (the theme cross-fade).
class SpringCurve extends Curve {
  const SpringCurve();
  @override
  double transformInternal(double t) {
    final double x = t * 9;
    return 1 - (1 + x) * math.exp(-x);
  }
}
