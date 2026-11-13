import 'package:material_ui/material_ui.dart';

import '../core/springs.dart';

/// A [Positioned] whose place is driven by springs: give it a new left/top
/// and it travels there, keeping its speed if the target changes on the way.
class SpringPositioned extends StatefulWidget {
  const SpringPositioned({
    super.key,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.child,
    this.spring,
  });
  final double left, top, width, height;
  final Widget child;
  final SpringDescription? spring;

  @override
  State<SpringPositioned> createState() => _SpringPositionedState();
}

class _SpringPositionedState extends State<SpringPositioned>
    with TickerProviderStateMixin {
  late final SpringValue _x = SpringValue(
    this,
    value: widget.left,
    settleDistance: 0.5,
    settleVelocity: 10,
  );
  late final SpringValue _y = SpringValue(
    this,
    value: widget.top,
    settleDistance: 0.5,
    settleVelocity: 10,
  );

  @override
  void didUpdateWidget(SpringPositioned old) {
    super.didUpdateWidget(old);
    if (old.left != widget.left) {
      _x.animateTo(widget.left, spring: widget.spring ?? Motions.expressive);
    }
    if (old.top != widget.top) {
      _y.animateTo(widget.top, spring: widget.spring ?? Motions.expressive);
    }
  }

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_x, _y]),
      builder: (BuildContext context, Widget? child) => Positioned(
        left: _x.value,
        top: _y.value,
        width: widget.width,
        height: widget.height,
        child: child!,
      ),
      child: widget.child,
    );
  }
}
