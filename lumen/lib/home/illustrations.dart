import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// Static vignettes for the home cards. Each hints at its room.
class RoomArt extends CustomPainter {
  const RoomArt(this.kind, this.hue, this.colors, {this.dim = false});
  final int kind;
  final Color hue;
  final LumenColors colors;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final double a = dim ? 0.55 : 1;
    switch (kind) {
      case 0:
        _glass(canvas, size);
      case 1:
        _spring(canvas, size, a);
      case 2:
        _morph(canvas, size, a);
      case 3:
        _flow(canvas, size, a);
      case 4:
        _shader(canvas, size, a);
      case 5:
        _details(canvas, size, a);
      case 6:
        _disco(canvas, size);
    }
  }

  void _blob(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45),
    );
  }

  void _glass(Canvas canvas, Size s) {
    _blob(
      canvas,
      Offset(s.width * 0.80, s.height * 0.20),
      s.height * 0.34,
      const Color(0xFFFF6B4A).withValues(alpha: 0.95),
    );
    _blob(
      canvas,
      Offset(s.width * 0.52, s.height * 0.42),
      s.height * 0.26,
      const Color(0xFF7B5CFF).withValues(alpha: 0.85),
    );
    _blob(
      canvas,
      Offset(s.width * 0.96, s.height * 0.62),
      s.height * 0.24,
      const Color(0xFF19C9B0).withValues(alpha: 0.8),
    );
    _blob(
      canvas,
      Offset(s.width * 0.66, s.height * 0.08),
      s.height * 0.14,
      const Color(0xFFFFC043).withValues(alpha: 0.9),
    );

    // A pill of glass with a lens in it.
    final Rect pill = Rect.fromLTWH(
      s.width * 0.40,
      s.height * 0.26,
      s.width * 0.52,
      56,
    );
    final RRect rr = RRect.fromRectAndRadius(pill, const Radius.circular(28));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = Colors.white.withValues(alpha: colors.dark ? 0.12 : 0.34),
    );
    canvas.drawRRect(
      rr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.75),
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.45),
          ],
        ).createShader(pill),
    );
    final Rect lens = Rect.fromLTWH(pill.left + 5, pill.top + 5, 74, 46);
    final RRect lr = RRect.fromRectAndRadius(lens, const Radius.circular(23));
    canvas.drawRRect(lr, Paint()..color = Colors.white.withValues(alpha: 0.22));
    canvas.drawRRect(
      lr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.8),
    );
    for (int i = 1; i < 4; i++) {
      canvas.drawCircle(
        Offset(pill.left + 42 + i * (pill.width - 84) / 3 + 14, pill.center.dy),
        4,
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
    }
    canvas.drawCircle(lens.center, 5, Paint()..color = Colors.white);
  }

  void _spring(Canvas canvas, Size s, double a) {
    final double x0 = s.width * 0.14, x1 = s.width * 0.88;
    final double base = s.height * 0.30, amp = s.height * 0.20;
    canvas.drawLine(
      Offset(x0, base),
      Offset(x1, base),
      Paint()
        ..color = colors.ink.withValues(alpha: 0.10)
        ..strokeWidth = 1,
    );
    final Path p = Path();
    for (int i = 0; i <= 80; i++) {
      final double t = i / 80;
      final double y = base + amp * math.exp(-4.2 * t) * math.cos(17 * t);
      i == 0 ? p.moveTo(x0, y) : p.lineTo(x0 + (x1 - x0) * t, y);
    }
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = hue.withValues(alpha: a),
    );
    canvas.drawCircle(
      Offset(x1, base),
      6,
      Paint()..color = hue.withValues(alpha: a),
    );
  }

  Path _cookie(Offset c, double r, int lobes, double depth) {
    final Path p = Path();
    for (int i = 0; i <= 120; i++) {
      final double th = i / 120 * math.pi * 2;
      final double rr = r * (1 + depth * math.cos(lobes * th));
      final Offset o = c + Offset(math.cos(th), math.sin(th)) * rr;
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  void _morph(Canvas canvas, Size s, double a) {
    final Offset c = Offset(s.width * 0.70, s.height * 0.27);
    final double r = s.height * 0.17;
    canvas.drawCircle(
      c.translate(-r * 0.9, 0),
      r * 0.9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = hue.withValues(alpha: 0.35 * a),
    );
    canvas.drawPath(
      _cookie(c, r, 8, 0.11),
      Paint()..color = hue.withValues(alpha: a),
    );
  }

  void _flow(Canvas canvas, Size s, double a) {
    final Rect small = Rect.fromLTWH(s.width - 54, 16, 38, 28);
    for (int i = 3; i >= 0; i--) {
      final Rect r = Rect.lerp(
        small,
        Rect.fromLTWH(s.width * 0.42, 16, s.width * 0.58 - 16, s.height - 32),
        i / 3,
      )!;
      final RRect rr = RRect.fromRectAndRadius(r, Radius.circular(9 + i * 3));
      if (i == 0) {
        canvas.drawRRect(rr, Paint()..color = hue.withValues(alpha: a));
      } else {
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = hue.withValues(alpha: (0.5 - i * 0.13) * a),
        );
      }
    }
  }

  void _shader(Canvas canvas, Size s, double a) {
    final Offset c = Offset(s.width * 0.72, s.height * 0.26);
    for (int i = 0; i < 7; i++) {
      canvas.drawCircle(
        c,
        10.0 + i * 15,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 - i * 0.5
          ..color = Color.lerp(
            hue,
            const Color(0xFF7B5CFF),
            i / 6,
          )!.withValues(alpha: (1 - i / 7.5) * a),
      );
    }
  }

  void _details(Canvas canvas, Size s, double a) {
    double x = s.width - 16;
    for (final (double w, double al) in <(double, double)>[
      (800, 1),
      (500, 0.6),
      (200, 0.35),
    ]) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: 'a',
          style: LumenType.display(
            54,
            weight: w,
            color: hue.withValues(alpha: al * a),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      x -= tp.width;
      tp.paint(canvas, Offset(x, 2));
      x -= 2;
      tp.dispose();
    }
  }

  void _disco(Canvas canvas, Size s) {
    final Offset c = Offset(s.width * 0.80, s.height * 0.46);
    final double r = s.height * 0.34;
    final math.Random rnd = math.Random(7);
    // Light spots thrown on the wall.
    for (int i = 0; i < 46; i++) {
      final double a = rnd.nextDouble() * math.pi * 2;
      final double d = r * (1.3 + rnd.nextDouble() * 2.4);
      final Offset p = c + Offset(math.cos(a), math.sin(a)) * d;
      final Color col = HSVColor.fromAHSV(
        1,
        rnd.nextDouble() * 360,
        0.45,
        1,
      ).toColor();
      canvas.drawCircle(
        p,
        1.2 + rnd.nextDouble() * 2.2,
        Paint()..color = col.withValues(alpha: colors.dark ? 0.7 : 0.55),
      );
    }
    canvas.drawLine(
      Offset(c.dx, 0),
      Offset(c.dx, c.dy - r),
      Paint()
        ..color = colors.inkFaint
        ..strokeWidth = 1,
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF3A3648));
    const double tile = 7;
    for (double y = c.dy - r; y < c.dy + r; y += tile) {
      for (double x = c.dx - r; x < c.dx + r; x += tile) {
        final double b = rnd.nextDouble();
        final double shade =
            1 -
            ((Offset(x, y) - c.translate(-r * 0.35, -r * 0.4)).distance /
                (r * 2.2));
        final Color col = b > 0.93
            ? Colors.white
            : Color.lerp(
                const Color(0xFF4A4658),
                const Color(0xFFE8E4F4),
                (shade * (0.6 + 0.4 * b)).clamp(0.0, 1.0),
              )!;
        canvas.drawRect(
          Rect.fromLTWH(x + 0.5, y + 0.5, tile - 1, tile - 1),
          Paint()..color = col,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RoomArt old) =>
      old.kind != kind ||
      old.hue != hue ||
      old.colors != colors ||
      old.dim != dim;
}
