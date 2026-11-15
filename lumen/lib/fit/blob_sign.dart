import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The looks the Blob's sign can have, chosen in the Blob panel. The first is the fan of stems
/// and dots (drawn where it always was); the others are drawn here. Android draws the same
/// ones for the floating blob, from the same numbers: change one, change the other.
abstract final class BlobSign {
  static const List<String> names = <String>['Fan', 'Pearls', 'Rays', 'Petals'];

  static const List<double> _pearl = <double>[6.0, 5.4, 4.8, 4.3, 3.9];
  static const List<double> _spread = <double>[0, 52, 40, 31, 26];

  /// Draws look [look] (1 to 3) in a square of 38 units ([size] wide), for blobs of these
  /// [colours], pointing along [angle] (radians; straight up by default). [fold] is how far it
  /// has folded away: 0 there, 1 gone.
  static void paint(
    Canvas canvas,
    Size size,
    int look,
    List<Color> colours, {
    double angle = -math.pi / 2,
    double fold = 0,
  }) {
    final int n = colours.length.clamp(0, 5);
    if (n == 0 || fold >= 0.999) {
      return;
    }
    final double u = size.width / 38;
    final double seen = (1 - fold * fold).clamp(0.0, 1.0);
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(1 - 0.7 * fold);
    switch (look) {
      case 1:
        _pearls(canvas, u, n, colours, angle, seen);
      case 2:
        _rays(canvas, u, n, colours, angle, seen);
      default:
        _petals(canvas, u, n, colours, angle, seen);
    }
    canvas.restore();
  }

  /// A white point, Prism, and the blobs around it as small lit pearls on the side they come
  /// out from. Each throws a little of its colour into the glass.
  static void _pearls(
    Canvas canvas,
    double u,
    int n,
    List<Color> colours,
    double a,
    double seen,
  ) {
    final double back = (n == 1 ? 6.0 : 10.0) * u,
        reach = (n == 1 ? 14.0 : 21.0) * u,
        r = _pearl[n - 1] * u,
        step = _spread[n - 1] * math.pi / 180;
    final Offset core = Offset(-back * math.cos(a), -back * math.sin(a));
    final List<Offset> at = <Offset>[
      for (int k = 0; k < n; k++)
        core +
            Offset(
                  math.cos(a + (k - (n - 1) / 2) * step),
                  math.sin(a + (k - (n - 1) / 2) * step),
                ) *
                reach,
    ];
    for (int k = 0; k < n; k++) {
      canvas.drawCircle(
        at[k],
        r * 2.3,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              colours[k].withValues(alpha: 0.5 * seen),
              colours[k].withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: at[k], radius: r * 2.3)),
      );
    }
    canvas.drawCircle(
      core,
      10 * u,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.45 * seen),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: core, radius: 10 * u)),
    );
    canvas.drawCircle(
      core,
      (n == 1 ? 3.4 : 3.0) * u,
      Paint()..color = Colors.white.withValues(alpha: seen),
    );
    for (int k = 0; k < n; k++) {
      canvas.drawCircle(
        at[k],
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            radius: 0.75,
            colors: <Color>[
              Color.lerp(
                colours[k],
                Colors.white,
                0.55,
              )!.withValues(alpha: seen),
              colours[k].withValues(alpha: seen),
            ],
            stops: const <double>[0, 0.6],
          ).createShader(Rect.fromCircle(center: at[k], radius: r)),
      );
    }
  }

  /// White light into a prism, and out of it a ray in each blob's colour.
  static void _rays(
    Canvas canvas,
    double u,
    int n,
    List<Color> colours,
    double a,
    double seen,
  ) {
    // The light and the rays are drawn pointing right and turned to where they point. The
    // prism itself stays upright, whichever way that is.
    canvas
      ..save()
      ..rotate(a);
    final Paint white = Paint()
      ..color = Colors.white.withValues(alpha: seen)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(-16 * u, 2 * u),
      Offset(-5 * u, 0.5 * u),
      white..strokeWidth = 2.6 * u,
    );
    final double gap = (n == 1 ? 0.0 : (n <= 3 ? 5.4 : 4.1)) * u;
    for (int k = 0; k < n; k++) {
      canvas.drawLine(
        Offset(3 * u, 0),
        Offset(16 * u, (k - (n - 1) / 2) * gap),
        Paint()
          ..color = colours[k].withValues(alpha: seen)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (n <= 3 ? 2.8 : 2.3) * u,
      );
    }
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(-6.5 * u, 6 * u)
        ..lineTo(0, -7 * u)
        ..lineTo(6.5 * u, 6 * u)
        ..close(),
      Paint()..color = const Color(0xFF14181C).withValues(alpha: seen),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-6.5 * u, 6 * u)
        ..lineTo(0, -7 * u)
        ..lineTo(6.5 * u, 6 * u)
        ..close(),
      white..strokeWidth = 2.2 * u,
    );
  }

  /// The blobs' colours as petals laid over one another, opening the way the blobs do.
  static void _petals(
    Canvas canvas,
    double u,
    int n,
    List<Color> colours,
    double a,
    double seen,
  ) {
    final double back = (n == 1 ? 4.0 : 8.0) * u,
        step = (n <= 3 ? 46.0 : 36.0) * math.pi / 180;
    final Offset foot = Offset(-back * math.cos(a), -back * math.sin(a));
    for (int k = 0; k < n; k++) {
      final double t = a + (k - (n - 1) / 2) * step;
      canvas
        ..save()
        ..translate(foot.dx, foot.dy)
        ..rotate(t)
        ..drawOval(
          Rect.fromLTRB(0.5 * u, -5.4 * u, 19.5 * u, 5.4 * u),
          Paint()..color = colours[k].withValues(alpha: 0.8 * seen),
        )
        ..restore();
    }
    canvas.drawCircle(
      foot + Offset(math.cos(a), math.sin(a)) * 1.5 * u,
      2.2 * u,
      Paint()..color = Colors.white.withValues(alpha: seen),
    );
  }
}

/// One of the looks, drawn small, for choosing among them.
class BlobSignPreview extends CustomPainter {
  const BlobSignPreview(this.look, this.colours, this.fan);
  final int look;
  final List<Color> colours;

  /// Draws the first look, the fan, which lives with the button's own drawing.
  final void Function(Canvas canvas, Size size) fan;

  @override
  void paint(Canvas canvas, Size size) {
    if (look == 0) {
      fan(canvas, size);
    } else {
      BlobSign.paint(canvas, size, look, colours);
    }
  }

  @override
  bool shouldRepaint(BlobSignPreview old) =>
      old.look != look || old.colours.length != colours.length;
}
