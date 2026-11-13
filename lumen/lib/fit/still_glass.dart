import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'look.dart';

/// Glass that costs nothing. Real glass blurs whatever is behind it again on
/// every frame. But what is behind most of Prism is a still picture, so that
/// picture is blurred once and kept. A piece of still glass simply shows the
/// part of the blurred copy that lies behind it, with a tint and a lit rim.
/// The colours come through as they do with real glass; the one difference is
/// that moving content underneath is hidden by it, not blurred through it.
class StillGlass extends SingleChildRenderObjectWidget {
  const StillGlass({
    super.key,
    required this.radius,
    required this.tint,
    required this.rim,
    required this.stamp,
    super.child,
  });
  final double radius;
  final Color tint, rim;

  /// Changes when the blurred picture changes, so the glass redraws once.
  final int stamp;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderStillGlass(radius, tint, rim, stamp);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderStillGlass renderObject,
  ) {
    final RenderStillGlass r = renderObject;
    if (r.radius != radius ||
        r.tint != tint ||
        r.rim != rim ||
        r.stamp != stamp) {
      r
        ..radius = radius
        ..tint = tint
        ..rim = rim
        ..stamp = stamp
        ..markNeedsPaint();
    }
  }
}

class RenderStillGlass extends RenderProxyBox {
  RenderStillGlass(this.radius, this.tint, this.rim, this.stamp);
  double radius;
  Color tint, rim;
  int stamp;

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    final Rect box = offset & size;
    final RRect shape = RRect.fromRectAndRadius(box, Radius.circular(radius));
    final ui.Image? frost = Look.instance.frost;
    final Size screen = Look.instance.frostScreen;
    canvas
      ..save()
      ..clipRRect(shape);
    if (frost != null && screen.width > 0) {
      // Where this piece is on the screen decides which part of the picture it shows.
      final Offset at = localToGlobal(Offset.zero);
      final double sx = frost.width / screen.width,
          sy = frost.height / screen.height;
      canvas.drawImageRect(
        frost,
        Rect.fromLTWH(
          at.dx * sx,
          at.dy * sy,
          size.width * sx,
          size.height * sy,
        ),
        box,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    canvas
      ..drawRect(box, Paint()..color = tint)
      ..restore();
    // The rim: brightest along the top edge, as if lit from above, fading down the sides.
    canvas.drawRRect(
      shape.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = ui.Gradient.linear(box.topCenter, box.bottomCenter, <Color>[
          rim,
          rim.withValues(alpha: rim.a * 0.18),
        ]),
    );
    super.paint(context, offset);
  }
}
