import 'package:material_ui/material_ui.dart';

import '../core/springs.dart';

/// A [Positioned] whose place and size are driven by springs: give it a new
/// rectangle and it travels there, keeping its speed if the target changes
/// on the way.
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
  SpringValue _make(double v) =>
      SpringValue(this, value: v, settleDistance: 0.5, settleVelocity: 10);
  late final SpringValue _x = _make(widget.left);
  late final SpringValue _y = _make(widget.top);
  late final SpringValue _w = _make(widget.width);
  late final SpringValue _h = _make(widget.height);

  @override
  void didUpdateWidget(SpringPositioned old) {
    super.didUpdateWidget(old);
    final SpringDescription s = widget.spring ?? Motions.expressive;
    if (old.left != widget.left) {
      _x.animateTo(widget.left, spring: s);
    }
    if (old.top != widget.top) {
      _y.animateTo(widget.top, spring: s);
    }
    if (old.width != widget.width) {
      _w.animateTo(widget.width, spring: s);
    }
    if (old.height != widget.height) {
      _h.animateTo(widget.height, spring: s);
    }
  }

  @override
  void dispose() {
    for (final SpringValue s in <SpringValue>[_x, _y, _w, _h]) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_x, _y, _w, _h]),
      builder: (BuildContext context, Widget? child) => Positioned(
        left: _x.value,
        top: _y.value,
        width: _w.value.clamp(1.0, 4000.0),
        height: _h.value.clamp(1.0, 4000.0),
        child: child!,
      ),
      child: widget.child,
    );
  }
}
