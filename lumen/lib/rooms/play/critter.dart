import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A small round creature drawn from scratch: a soft body, two eyes that can
/// look somewhere, a mouth that opens, and two feet. Used by both games.
class CritterPainter extends CustomPainter {
  const CritterPainter({
    required this.color,
    this.mouth = 0,
    this.look = Offset.zero,
    this.squash = 0,
    this.happy = 0,
  });
  final Color color;

  /// 0 closed, 1 wide open.
  final double mouth;

  /// Where the eyes look, each axis -1..1.
  final Offset look;

  /// -1 squashed flat, 0 round, 1 stretched tall.
  final double squash;
  final double happy;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;
    final Offset c = Offset(w / 2, h * 0.56);
    final double rx = w * 0.40 * (1 - squash * 0.14),
        ry = h * 0.38 * (1 + squash * 0.18);
    // Feet.
    final Paint foot = Paint()..color = Color.lerp(color, Colors.black, 0.35)!;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - rx * 0.45, c.dy + ry * 0.94),
        width: rx * 0.5,
        height: ry * 0.24,
      ),
      foot,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx + rx * 0.45, c.dy + ry * 0.94),
        width: rx * 0.5,
        height: ry * 0.24,
      ),
      foot,
    );
    // Body, with a tuft on top.
    final Rect body = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
    canvas.drawOval(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.5),
          radius: 1.1,
          colors: <Color>[
            Color.lerp(color, Colors.white, 0.4)!,
            color,
            Color.lerp(color, Colors.black, 0.25)!,
          ],
          stops: const <double>[0, 0.55, 1],
        ).createShader(body),
    );
    final Path tuft = Path()
      ..moveTo(c.dx - rx * 0.12, c.dy - ry * 0.96)
      ..quadraticBezierTo(
        c.dx - rx * 0.05,
        c.dy - ry * 1.4,
        c.dx + rx * 0.22,
        c.dy - ry * 1.3,
      )
      ..quadraticBezierTo(
        c.dx + rx * 0.08,
        c.dy - ry * 1.12,
        c.dx + rx * 0.14,
        c.dy - ry * 0.95,
      )
      ..close();
    canvas.drawPath(
      tuft,
      Paint()..color = Color.lerp(color, Colors.white, 0.25)!,
    );
    // Cheeks.
    final Paint cheek = Paint()
      ..color = const Color(0xFFFF8FA3).withValues(alpha: 0.35 + 0.35 * happy);
    canvas.drawCircle(
      Offset(c.dx - rx * 0.6, c.dy + ry * 0.12),
      rx * 0.14,
      cheek,
    );
    canvas.drawCircle(
      Offset(c.dx + rx * 0.6, c.dy + ry * 0.12),
      rx * 0.14,
      cheek,
    );
    // Eyes.
    for (final double side in <double>[-1, 1]) {
      final Offset e = Offset(c.dx + side * rx * 0.36, c.dy - ry * 0.16);
      if (happy > 0.6) {
        canvas.drawArc(
          Rect.fromCircle(center: e, radius: rx * 0.15),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = const Color(0xFF1B1B22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = rx * 0.07
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawCircle(e, rx * 0.19, Paint()..color = Colors.white);
        canvas.drawCircle(
          e + Offset(look.dx * rx * 0.07, look.dy * rx * 0.07),
          rx * 0.11,
          Paint()..color = const Color(0xFF1B1B22),
        );
        canvas.drawCircle(
          e +
              Offset(
                look.dx * rx * 0.07 - rx * 0.035,
                look.dy * rx * 0.07 - rx * 0.04,
              ),
          rx * 0.035,
          Paint()..color = Colors.white,
        );
      }
    }
    // Mouth.
    final Offset m = Offset(c.dx, c.dy + ry * 0.26);
    if (mouth > 0.08) {
      canvas.drawOval(
        Rect.fromCenter(
          center: m,
          width: rx * (0.3 + 0.22 * mouth),
          height: ry * 0.42 * mouth,
        ),
        Paint()..color = const Color(0xFF3A1420),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: m + Offset(0, ry * 0.1 * mouth),
          width: rx * 0.2,
          height: ry * 0.16 * mouth,
        ),
        Paint()..color = const Color(0xFFE5677C),
      );
    } else {
      canvas.drawArc(
        Rect.fromCenter(
          center: m - Offset(0, ry * 0.08),
          width: rx * 0.36,
          height: ry * 0.26,
        ),
        0.15 * math.pi,
        0.7 * math.pi,
        false,
        Paint()
          ..color = const Color(0xFF3A1420)
          ..style = PaintingStyle.stroke
          ..strokeWidth = rx * 0.06
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(CritterPainter old) =>
      old.color != color ||
      old.mouth != mouth ||
      old.look != look ||
      old.squash != squash ||
      old.happy != happy;
}

/// Bits of coloured paper thrown from a point. [t] runs 0..1.
void paintConfetti(
  Canvas canvas,
  Offset from,
  double t,
  int seed, {
  double reach = 260,
}) {
  if (t <= 0 || t >= 1) {
    return;
  }
  final math.Random r = math.Random(seed);
  const List<Color> cols = <Color>[
    Color(0xFFF5B301),
    Color(0xFFFF6B4A),
    Color(0xFF8E7CFF),
    Color(0xFF2ED3B7),
    Color(0xFF4FB8FF),
  ];
  final double k = 1 - math.pow(1 - t, 3).toDouble();
  for (int i = 0; i < 54; i++) {
    final double a = r.nextDouble() * math.pi * 2;
    final Offset p =
        from +
        Offset(math.cos(a), math.sin(a)) *
            (reach * (0.35 + r.nextDouble() * 0.65)) *
            k +
        Offset(0, 120 * t * t);
    final double w = 5 + r.nextDouble() * 6;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(a + t * (4 + r.nextDouble() * 6));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.5),
        const Radius.circular(1.5),
      ),
      Paint()
        ..color = cols[i % cols.length].withValues(
          alpha: (1 - t * t).clamp(0.0, 1.0),
        ),
    );
    canvas.restore();
  }
}
