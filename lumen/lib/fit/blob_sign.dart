import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The looks the Blob's sign can have, chosen in the Blob panel. The first is the fan of stems
/// and dots (drawn where it always was); the others are drawn here. Android draws the same
/// ones for the floating blob, from the same numbers: change one, change the other.
abstract final class BlobSign {
  /// By its number: 1 pearls, 2 rays, 3 petals. (There was a fan of stems, 0; it is gone.)
  static const List<String> names = <String>['', 'Pearls', 'Rays', 'Petals'];

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

  /// The blobs' colours as petals round a quiet white point in the very middle of the glass,
  /// nearly filling it.
  static void _petals(
    Canvas canvas,
    double u,
    int n,
    List<Color> colours,
    double a,
    double seen,
  ) {
    final double step = n == 1 ? 0 : 2 * math.pi / n;
    for (int k = 0; k < n; k++) {
      canvas
        ..save()
        ..rotate(a + (k - (n - 1) / 2) * step)
        ..drawOval(
          Rect.fromLTRB(1 * u, -9.5 * u, 25 * u, 9.5 * u),
          // A little softer than the blob's own colour, and seen through.
          Paint()
            ..color = Color.lerp(
              colours[k],
              Colors.white,
              0.14,
            )!.withValues(alpha: 0.76 * seen),
        )
        ..restore();
    }
    canvas
      ..drawCircle(
        Offset.zero,
        6.5 * u,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: 0.35 * seen),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 6.5 * u)),
      )
      ..drawCircle(
        Offset.zero,
        2.4 * u,
        Paint()..color = Colors.white.withValues(alpha: 0.85 * seen),
      );
  }
}

/// One of the looks, drawn small, for choosing among them.
class BlobSignPreview extends CustomPainter {
  const BlobSignPreview(this.look, this.colours);
  final int look;
  final List<Color> colours;

  @override
  void paint(Canvas canvas, Size size) =>
      BlobSign.paint(canvas, size, look, colours);

  @override
  bool shouldRepaint(BlobSignPreview old) =>
      old.look != look || old.colours.length != colours.length;
}
