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
        _foil(canvas, size);
      case 7:
        _dial(canvas, size, a);
      case 8:
        _swatches(canvas, size, a);
      case 9:
        _pill(canvas, size, a);
      case 10:
        _chart(canvas, size, a);
      case 11:
        _access(canvas, size, a);
      case 12:
        _disco(canvas, size);
      default:
        if (kind >= 19) {
          _glyph(
            canvas,
            size,
            const <IconData>[
              Icons.speed_rounded,
              Icons.apps_rounded,
              Icons.bubble_chart_rounded,
              Icons.timer_outlined,
              Icons.straighten_rounded,
              Icons.rule_rounded,
              Icons.widgets_rounded,
              Icons.dashboard_rounded,
              Icons.article_rounded,
              Icons.auto_awesome_rounded,
              Icons.swipe_rounded,
              Icons.tune_rounded,
              Icons.dialpad_rounded,
              Icons.qr_code_scanner_rounded,
              Icons.grid_view_rounded,
              Icons.sort_by_alpha_rounded,
              Icons.emoji_events_rounded,
              Icons.palette_rounded,
              Icons.notifications_rounded,
              Icons.calendar_month_rounded,
              Icons.fitness_center_rounded,
              Icons.space_dashboard_rounded,
              Icons.swap_vert_rounded,
              Icons.task_alt_rounded,
              Icons.av_timer_rounded,
              Icons.album_rounded,
              Icons.show_chart_rounded,
              Icons.restaurant_rounded,
              Icons.play_circle_rounded,
              Icons.swap_horiz_rounded,
              Icons.edit_note_rounded,
            ][(kind - 19) % 31],
          );
        } else {
          _basic(canvas, size, kind - 13);
        }
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

  void _foil(Canvas canvas, Size s) {
    final Rect card = Rect.fromCenter(
      center: Offset(s.width * 0.74, s.height * 0.40),
      width: s.height * 0.46,
      height: s.height * 0.64,
    );
    canvas.save();
    canvas.translate(card.center.dx, card.center.dy);
    canvas.rotate(0.16);
    canvas.translate(-card.center.dx, -card.center.dy);
    final RRect rr = RRect.fromRectAndRadius(card, const Radius.circular(12));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF2A2140));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(
      card,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0x00FFFFFF),
            const Color(0xAAFF7AB6),
            const Color(0xAAFFE38A),
            const Color(0xAA7BF1C8),
            const Color(0xAA7AA8FF),
            const Color(0x00FFFFFF),
          ],
          stops: const <double>[0.15, 0.32, 0.45, 0.58, 0.72, 0.9],
        ).createShader(card),
    );
    canvas.restore();
    canvas.drawRRect(
      rr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.5),
    );
    canvas.restore();
  }

  void _dial(Canvas canvas, Size s, double a) {
    final Offset c = Offset(s.width * 0.68, s.height * 0.36);
    final double r = s.height * 0.22;
    for (int i = 0; i <= 20; i++) {
      final double ang = (-150 + i * 15) * math.pi / 180 - math.pi / 2;
      final Offset d = Offset(math.cos(ang), math.sin(ang));
      canvas.drawLine(
        c + d * (r + 6),
        c + d * (r + (i % 5 == 0 ? 14 : 10)),
        Paint()
          ..color = (i <= 13 ? hue : colors.inkFaint).withValues(alpha: a)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(c, r, Paint()..color = colors.surfaceHigh);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = colors.ink.withValues(alpha: 0.12),
    );
    final double pa = (-150 + 13 * 15) * math.pi / 180 - math.pi / 2;
    canvas.drawCircle(
      c + Offset(math.cos(pa), math.sin(pa)) * r * 0.7,
      4,
      Paint()..color = hue.withValues(alpha: a),
    );
  }

  void _swatches(Canvas canvas, Size s, double a) {
    const List<Color> cols = <Color>[
      Color(0xFF7BD389),
      Color(0xFF2E7D5B),
      Color(0xFFF2E3B3),
      Color(0xFFE88D67),
    ];
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(s.width * 0.42 + i * 22, s.height * 0.32),
        20,
        Paint()..color = cols[i].withValues(alpha: a),
      );
    }
  }

  void _pill(Canvas canvas, Size s, double a) {
    final RRect p = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s.width * 0.55, s.height * 0.22),
        width: s.width * 0.62,
        height: 30,
      ),
      const Radius.circular(15),
    );
    canvas.drawRRect(p, Paint()..color = Colors.black);
    canvas.drawRRect(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = colors.ink.withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      Offset(p.left + 16, p.center.dy),
      7,
      Paint()..color = const Color(0xFFFF9F0A).withValues(alpha: a),
    );
    for (int i = 0; i < 5; i++) {
      final double h = 6 + 8 * (0.5 + 0.5 * math.sin(i * 1.7));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(p.right - 40 + i * 6, p.center.dy),
            width: 3,
            height: h,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = hue.withValues(alpha: a),
      );
    }
    canvas.drawCircle(
      Offset(p.right + 22, p.center.dy),
      15,
      Paint()..color = Colors.black,
    );
  }

  void _chart(Canvas canvas, Size s, double a) {
    final Path p = Path();
    for (int i = 0; i <= 10; i++) {
      final double x = s.width * 0.45 + i * (s.width * 0.5 / 10);
      final double y = s.height * 0.45 - 26 * math.sin(i * 0.7) - i * 2.5;
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = hue.withValues(alpha: a),
    );
  }

  void _access(Canvas canvas, Size s, double a) {
    double x = s.width - 16;
    for (final double size in <double>[54, 34, 20]) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: 'Aa',
          style: LumenType.display(
            size,
            weight: 700,
            color: hue.withValues(alpha: a * (size / 54)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      x -= tp.width;
      tp.paint(canvas, Offset(x, 28 + 54 - size));
      x -= 4;
      tp.dispose();
    }
  }

  void _glyph(Canvas canvas, Size s, IconData icon) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 58,
          color: hue,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(s.width - tp.width - 14, 14));
    tp.dispose();
  }

  void _basic(Canvas canvas, Size s, int k) {
    final Paint fill = Paint()..color = hue;
    final Paint soft = Paint()..color = colors.ink.withValues(alpha: 0.14);
    final double r = s.width - 18;
    RRect bar(double right, double top, double w, double h) =>
        RRect.fromRectAndRadius(
          Rect.fromLTWH(right - w, top, w, h),
          Radius.circular(h / 2),
        );
    switch (k) {
      case 0: // type: lines of decreasing size
        canvas.drawRRect(bar(r, 20, 74, 14), fill);
        canvas.drawRRect(bar(r, 42, 56, 8), soft);
        canvas.drawRRect(bar(r, 56, 74, 5), soft);
        canvas.drawRRect(bar(r, 66, 62, 5), soft);
      case 1: // space: blocks with a measured gap
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(r - 70, 20, 30, 30),
            const Radius.circular(8),
          ),
          soft,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(r - 30, 20, 30, 30),
            const Radius.circular(8),
          ),
          soft,
        );
        canvas.drawRect(Rect.fromLTWH(r - 40, 30, 10, 10), fill);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(r - 70, 60, 70, 14),
            const Radius.circular(6),
          ),
          soft,
        );
        canvas.drawRect(Rect.fromLTWH(r - 40, 50, 10, 10), fill);
      case 2: // contrast: half and half
        final Offset c = Offset(r - 30, 46);
        canvas.drawCircle(
          c,
          28,
          Paint()..color = colors.ink.withValues(alpha: 0.2),
        );
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: 28),
          -math.pi / 2,
          math.pi,
          true,
          fill,
        );
      case 3: // states: three dots, one active
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(r - 62 + i * 28, 40),
            i == 1 ? 12 : 9,
            i == 1 ? fill : soft,
          );
        }
      case 4: // forms: field with a tick
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(r - 84, 24, 84, 32),
            const Radius.circular(10),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = hue,
        );
        canvas.drawRRect(bar(r - 30, 37, 44, 6), soft);
        canvas.drawCircle(Offset(r - 14, 40), 6, fill);
      case 5: // sheets: a sheet rising from the bottom
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(r - 64, 16, 64, 64),
            const Radius.circular(12),
          ),
          soft,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(r - 64, 46, 64, 34),
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
          fill,
        );
        canvas.drawRRect(
          bar(r - 22, 51, 20, 3),
          Paint()..color = colors.surface,
        );
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
