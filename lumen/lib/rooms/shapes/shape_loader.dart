import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/shapes.dart';
import '../../core/springs.dart';

/// Loading indicator: spins while stepping through shapes, each step on a
/// spring with a little overshoot.
class ShapeLoader extends StatefulWidget {
  const ShapeLoader({super.key, required this.size, required this.color});
  final double size;
  final Color color;

  @override
  State<ShapeLoader> createState() => _ShapeLoaderState();
}

class _ShapeLoaderState extends State<ShapeLoader>
    with TickerProviderStateMixin {
  static final SpringDescription _step = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 520,
    ratio: 0.6,
  );
  late final SpringValue _i = SpringValue(this, spring: _step);
  final ValueNotifier<double> _spin = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((Duration e) {
    _spin.value = e.inMicroseconds / 1e6 * (Motion.reduced ? 0.6 : 2.1);
  });
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    _timer = Timer.periodic(
      const Duration(milliseconds: 650),
      (_) => _i.animateTo(_i.target + 1),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker.dispose();
    _i.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: CustomPaint(painter: _LoaderPainter(_i, _spin, widget.color)),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  _LoaderPainter(this.i, this.spin, this.color)
    : super(repaint: Listenable.merge(<Listenable>[i, spin]));
  final SpringValue i;
  final ValueNotifier<double> spin;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path p = ShapeLib.at(
      ShapeLib.loader,
      i.value,
      size.center(Offset.zero),
      size.shortestSide / 2 * 0.86,
      spin.value + i.value * math.pi / 3,
    );
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LoaderPainter old) => old.color != color;
}
