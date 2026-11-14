import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'look.dart';

/// Glass that costs nothing. Real glass blurs whatever is behind it again on
/// every frame. But what is behind most of Prism is a still picture, so that
/// picture is blurred once and kept. A piece of still glass shows the part of
/// the blurred copy that lies behind it, and then does what makes glass look
/// like glass: it bends the picture a little near its edge, catches light
/// along the top, and has a lit rim. The colours come through as they do with
/// real glass; the one difference is that moving content underneath is hidden
/// by it, not blurred through it.
///
/// This file has two forms of it: a widget, for things that stay put (the
/// bar and the lens in it), and a decoration, for cards.

/// Paints one piece of still glass into [canvas]. [at] is where the piece is on the screen.
void paintStillGlass(
  Canvas canvas,
  Path shape,
  Rect box,
  Offset at, {
  required Color tint,
  required Color rim,
  double magnify = 1,
  bool sharp = false,
  bool soft = false,
  double edge = 0,
  Color? flat,
}) {
  final Look look = Look.instance;
  final ui.Image? picture = sharp
      ? look.crisp
      : (soft ? look.soft ?? look.frost : look.frost);
  final Size screen = look.frostScreen;
  canvas
    ..save()
    ..clipPath(shape);
  if (picture == null || screen.width <= 0) {
    // No background to show (lights off, or not made yet): a plain surface.
    canvas.drawRect(box, Paint()..color = flat ?? tint.withValues(alpha: 1));
  } else {
    final double sx = picture.width / screen.width,
        sy = picture.height / screen.height;
    Rect slice(double zoom) {
      final Offset centre = at + Offset(box.width / 2, box.height / 2);
      return Rect.fromCenter(
        center: Offset(centre.dx * sx, centre.dy * sy),
        width: box.width * sx / zoom,
        height: box.height * sy / zoom,
      );
    }

    final Paint p = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(picture, slice(magnify), box, p);
    if (edge > 0) {
      // A band just inside the rim shows the picture slightly enlarged, as the curved edge of
      // a pane does. It is the same picture drawn a second time, only through a ring.
      canvas
        ..save()
        ..clipPath(
          Path.combine(
            PathOperation.difference,
            shape,
            shape
                .shift(Offset.zero)
                .transform(
                  (Matrix4.identity()
                        ..translateByDouble(box.center.dx, box.center.dy, 0, 1)
                        ..scaleByDouble(
                          1 - 2 * edge / box.width,
                          1 - 2 * edge / box.height,
                          1,
                          1,
                        )
                        ..translateByDouble(
                          -box.center.dx,
                          -box.center.dy,
                          0,
                          1,
                        ))
                      .storage,
                ),
          ),
        )
        ..drawImageRect(picture, slice(magnify * 1.14), box, p)
        ..drawRect(box, Paint()..color = const Color(0x0AFFFFFF))
        ..restore();
    }
    canvas.drawRect(box, Paint()..color = tint);
  }
  // Light caught along the top.
  canvas
    ..drawRect(
      Rect.fromLTWH(box.left, box.top, box.width, box.height * 0.5),
      Paint()
        ..shader = ui.Gradient.linear(box.topCenter, box.center, <Color>[
          rim.withValues(alpha: rim.a * 0.20),
          rim.withValues(alpha: 0),
        ]),
    )
    ..restore()
    // The rim: brightest along the top edge, fading down the sides.
    ..drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = ui.Gradient.linear(box.topCenter, box.bottomCenter, <Color>[
          rim,
          rim.withValues(alpha: rim.a * 0.16),
        ]),
    );
}

class StillGlass extends SingleChildRenderObjectWidget {
  const StillGlass({
    super.key,
    required this.radius,
    required this.tint,
    required this.rim,
    required this.stamp,
    this.magnify = 1,
    this.sharp = false,
    this.soft = false,
    this.edge = 0,
    super.child,
  });
  final double radius;
  final Color tint, rim;

  /// Above 1, what is behind looks enlarged, as through a lens.
  final double magnify;

  /// Shows the background as it is, not the blurred copy: clear glass, not frosted.
  final bool sharp;

  /// Shows the background softened only a little: clear glass, through which the lights
  /// behind it keep their shape.
  final bool soft;

  /// How wide the bent band inside the rim is. 0 for none.
  final double edge;

  /// Changes when the picture changes, so the glass redraws once.
  final int stamp;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderStillGlass(this);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderStillGlass renderObject,
  ) {
    final StillGlass old = renderObject.spec;
    renderObject.spec = this;
    if (old.radius != radius ||
        old.tint != tint ||
        old.rim != rim ||
        old.stamp != stamp ||
        old.magnify != magnify ||
        old.sharp != sharp ||
        old.soft != soft ||
        old.edge != edge) {
      renderObject.markNeedsPaint();
    }
  }
}

class RenderStillGlass extends RenderProxyBox {
  RenderStillGlass(this.spec);
  StillGlass spec;

  @override
  void paint(PaintingContext context, Offset offset) {
    final Rect box = offset & size;
    paintStillGlass(
      context.canvas,
      Path()
        ..addRRect(RRect.fromRectAndRadius(box, Radius.circular(spec.radius))),
      box,
      localToGlobal(Offset.zero),
      tint: spec.tint,
      rim: spec.rim,
      magnify: spec.magnify,
      sharp: spec.sharp,
      soft: spec.soft,
      edge: spec.edge,
    );
    super.paint(context, offset);
  }
}

/// A card made of still glass. Used like any other decoration.
///
/// A decoration is not told where on the screen it is, only where it is in
/// the picture being drawn. For the pages those are the same thing, because
/// each page is drawn from the top-left corner of the screen. (The list the
/// cards sit in must not give each card its own separate picture, or a card
/// would not be redrawn as it scrolls and its glass would show the wrong
/// part of the background.)
class PaneDecoration extends Decoration {
  const PaneDecoration({
    required this.radius,
    required this.tint,
    required this.rim,
    required this.flat,
    required this.stamp,
  });
  final double radius;
  final Color tint, rim, flat;
  final int stamp;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _PanePainter(this);

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) =>
      RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radius))
          .getOuterPath(rect);

  @override
  bool operator ==(Object other) =>
      other is PaneDecoration &&
      other.radius == radius &&
      other.tint == tint &&
      other.rim == rim &&
      other.flat == flat &&
      other.stamp == stamp;

  @override
  int get hashCode => Object.hash(radius, tint, rim, flat, stamp);
}

class _PanePainter extends BoxPainter {
  _PanePainter(this.d);
  final PaneDecoration d;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect box = offset & (configuration.size ?? Size.zero);
    // Where the drawing is being moved to (a pressed card is drawn slightly smaller, for one).
    final Offset at = MatrixUtils.transformPoint(
      Matrix4.fromFloat64List(canvas.getTransform()),
      offset,
    );
    paintStillGlass(
      canvas,
      RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(d.radius))
          .getOuterPath(box),
      box,
      at,
      tint: d.tint,
      rim: d.rim,
      flat: d.flat,
    );
  }
}
