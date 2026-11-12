import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'frame_stats.dart';
import 'haptics.dart';
import 'springs.dart';

/// How a screen relates to the thing that opened it.
enum RouteMorph {
  /// The screen stays still and a window into it grows from the origin.
  reveal,

  /// The screen itself grows out of the origin, like a card becoming a page.
  container,
}

/// A screen that opens from what was tapped and closes back into it, on
/// springs. With gesture navigation the screen follows the finger during the
/// back swipe (predictive back) and can be cancelled halfway; with the back
/// button it closes on the same spring.
class ExpandRoute<T> extends PageRoute<T> {
  ExpandRoute({
    required this.builder,
    required this.origin,
    required this.originColor,
    this.originRadius = 32,
    this.morph = RouteMorph.reveal,
    this.originBuilder,
    this.onLanded,
  });

  final WidgetBuilder builder;
  final Rect origin;
  final Color originColor;
  final double originRadius;
  final RouteMorph morph;

  /// For [RouteMorph.container]: paints the original card, which fades out
  /// as the page grows and back in as it lands.
  final WidgetBuilder? originBuilder;

  /// Called once the screen has fully closed.
  final VoidCallback? onLanded;

  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.92,
  );
  static const double _gestureRadius = 34;

  // Back gesture state.
  final ValueNotifier<double> _back = ValueNotifier<double>(0);
  SpringValue? _backSpring;
  Offset _touch0 = Offset.zero;
  Offset _touch = Offset.zero;
  SwipeEdge _edge = SwipeEdge.left;
  bool _gesturing = false;
  Rect? _released;
  double _releasedProgress = 0;
  Size _screen = Size.zero;

  /// Everything that moves this screen: open/close and the back gesture.
  late final Listenable motion = Listenable.merge(<Listenable>[
    animation!,
    _back,
  ]);

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
  void install() {
    super.install();
    int missedAtStart = 0;
    controller!.addStatusListener((AnimationStatus s) {
      if (s == AnimationStatus.forward || s == AnimationStatus.reverse) {
        missedAtStart = FrameStats.instance.missed;
      }
      if (s == AnimationStatus.completed || s == AnimationStatus.dismissed) {
        final String what = s == AnimationStatus.completed ? 'Open' : 'Close';
        // Frame timings arrive in batches, so wait for the last ones.
        Future<void>.delayed(const Duration(milliseconds: 700), () {
          FrameStats.instance.note(
            '$what: ${FrameStats.instance.missed - missedAtStart} missed frames',
          );
        });
      }
      if (s == AnimationStatus.dismissed) {
        Haptics.settle();
        onLanded?.call();
      }
    });
  }

  @override
  void dispose() {
    _backSpring?.dispose();
    _back.dispose();
    super.dispose();
  }

  @override
  Simulation createSimulation({required bool forward}) {
    final Simulation spring = SpringSimulation(
      Motion.reduced ? Motions.reduced : _spring,
      controller!.value,
      forward ? 1 : 0,
      Motion.reduced ? 0 : controller!.velocity,
    );
    // The first frame of a transition is the expensive one (the new screen is
    // built and drawn for the first time). Holding still for three frames
    // lets that cost land while nothing is moving, so it cannot show as a
    // hitch. A gesture that has already moved the screen continues at once.
    final bool moving = controller!.isAnimating || _released != null;
    return moving ? spring : _Delayed(spring, 0.025);
  }

  SpringValue get _spring2 {
    return _backSpring ??= SpringValue(navigator!, spring: Motions.spatialFast)
      ..addListener(() => _back.value = _backSpring!.value);
  }

  bool _startBack(PredictiveBackEvent e) {
    if (e.isButtonEvent ||
        !isCurrent ||
        !popGestureEnabled ||
        controller!.isAnimating) {
      return false;
    }
    _gesturing = true;
    _released = null;
    _touch0 = _touch = e.touchOffset ?? Offset.zero;
    _edge = e.swipeEdge;
    _backSpring?.jumpTo(_back.value);
    _back.value = e.progress;
    // Let the screen underneath show while this one shrinks.
    overlayEntries.first.opaque = false;
    return true;
  }

  void _updateBack(PredictiveBackEvent e) {
    if (!_gesturing) {
      return;
    }
    _touch = e.touchOffset ?? _touch;
    _back.value = e.progress;
  }

  void _cancelBack() {
    if (!_gesturing) {
      return;
    }
    _gesturing = false;
    final SpringValue s = _spring2;
    s.jumpTo(_back.value);
    s.onSettle = () {
      if (isCurrent && !_gesturing && controller!.isCompleted) {
        overlayEntries.first.opaque = true;
      }
    };
    s.animateTo(0, spring: Motions.expressiveFast);
  }

  void _commitBack() {
    if (!_gesturing) {
      return;
    }
    _gesturing = false;
    _releasedProgress = _back.value;
    _released = _gestureRect(_screen, _releasedProgress);
    _back.value = 0;
    navigator?.pop();
  }

  Rect _gestureRect(Size size, double p) {
    final Rect full = Offset.zero & size;
    final double k = 1 - 0.12 * p;
    final double dir = _edge == SwipeEdge.left ? 1 : -1;
    final double dy = ((_touch.dy - _touch0.dy) * 0.2).clamp(-56.0, 56.0);
    return Rect.fromCenter(
      center: full.center + Offset(dir * 26 * p, dy * math.min(p * 3, 1)),
      width: size.width * k,
      height: size.height * k,
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
    return _BackGestureObserver(
      route: this,
      child: AnimatedBuilder(
        animation: motion,
        builder: (BuildContext context, Widget? child) {
          final Size size = MediaQuery.sizeOf(context);
          _screen = size;
          final Rect full = Offset.zero & size;
          final double t = animation.value.clamp(0.0, 1.06);
          final double p = _back.value;

          final Rect? released = _released;
          final Rect endRect = released ?? full;
          final double endRadius = released != null
              ? _gestureRadius * _releasedProgress
              : 0;
          final Rect fit = Rect.fromLTWH(
            origin.left,
            origin.top,
            origin.width,
            size.height * origin.width / size.width,
          );
          final Rect startFrame = morph == RouteMorph.container ? fit : endRect;

          Rect frame = Rect.lerp(startFrame, endRect, t)!;
          Rect clip = Rect.lerp(origin, endRect, t)!;
          double radius = lerpDouble(
            originRadius,
            endRadius,
            released != null ? t : t * t,
          )!;
          double scrim =
              0.45 *
              t.clamp(0.0, 1.0) *
              (1 - 0.6 * (released != null ? _releasedProgress : 0));
          if (released == null && p > 0) {
            frame = clip = _gestureRect(size, p);
            radius = _gestureRadius * p;
            scrim = 0.45 * (1 - 0.6 * p);
          }

          final double k = frame.width / size.width;
          final double veil = morph == RouteMorph.reveal
              ? (1 - t / 0.55).clamp(0.0, 1.0)
              : 0;
          final double cover =
              morph == RouteMorph.container && originBuilder != null
              ? (1 - t / 0.42).clamp(0.0, 1.0)
              : 0;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              IgnorePointer(
                child: ColoredBox(color: Colors.black.withValues(alpha: scrim)),
              ),
              ClipRSuperellipse(
                clipper: _RectClipper(clip, radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Transform(
                      transform: Matrix4.translationValues(
                        frame.left,
                        frame.top,
                        0,
                      )..scaleByDouble(k, k, 1, 1),
                      child: child,
                    ),
                    if (veil > 0)
                      IgnorePointer(
                        child: ColoredBox(
                          color: originColor.withValues(alpha: veil),
                        ),
                      ),
                    if (cover > 0)
                      Positioned(
                        left: clip.left,
                        top: clip.top,
                        width: origin.width,
                        height: origin.height,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: cover,
                            child: Transform.scale(
                              scale: clip.width / origin.width,
                              alignment: Alignment.topLeft,
                              child: originBuilder!(context),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
        child: child,
      ),
    );
  }
}

class _BackGestureObserver extends StatefulWidget {
  const _BackGestureObserver({required this.route, required this.child});
  final ExpandRoute<dynamic> route;
  final Widget child;

  @override
  State<_BackGestureObserver> createState() => _BackGestureObserverState();
}

class _BackGestureObserverState extends State<_BackGestureObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) =>
      widget.route._startBack(backEvent);

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) =>
      widget.route._updateBack(backEvent);

  @override
  void handleCommitBackGesture() => widget.route._commitBack();

  @override
  void handleCancelBackGesture() => widget.route._cancelBack();

  @override
  Widget build(BuildContext context) => widget.child;
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

/// Holds [inner] at its start for [delay] seconds.
class _Delayed extends Simulation {
  _Delayed(this.inner, this.delay);
  final Simulation inner;
  final double delay;

  @override
  double x(double time) => inner.x(math.max(0, time - delay));
  @override
  double dx(double time) => time < delay ? 0 : inner.dx(time - delay);
  @override
  bool isDone(double time) => time >= delay && inner.isDone(time - delay);
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
