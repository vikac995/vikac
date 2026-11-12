import 'package:flutter/widgets.dart';

import '../core/springs.dart';

/// Press feedback. The squeeze starts on pointer-down (not after the tap is
/// recognised) and releases with a small overshoot.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.95,
    this.builder,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  /// Optional: build with the press amount (0 to 1, may overshoot slightly).
  final Widget Function(BuildContext context, double pressed, Widget child)?
  builder;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final SpringValue _press = SpringValue(this);

  void _down(PointerDownEvent _) {
    if (widget.onTap == null) {
      return;
    }
    // The initial velocity makes the first frame visibly move.
    _press.animateTo(1, spring: Motions.spatialFast, velocity: 14);
  }

  void _release() => _press.animateTo(0, spring: Motions.expressiveFast);

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapCancel: _release,
        child: ListenableBuilder(
          listenable: _press,
          builder: (BuildContext context, Widget? child) {
            final double p = _press.value;
            if (widget.builder != null) {
              return widget.builder!(context, p, child!);
            }
            return Transform.scale(
              scale: 1 - (1 - widget.scale) * p,
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
