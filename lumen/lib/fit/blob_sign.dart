import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

// The looks the Blob's sign can have, chosen in the Blob panel.
//
// TO REMOVE A LOOK: delete its line in [BlobSign.looks] and its one function below, and the
// same two things in android/.../BlobLooks.kt. Nothing else knows the looks by name: a phone
// that had the removed one chosen falls back to Window (see [BlobSign.first]); remove Window last.
//
// TO ADD ONE: write the function here and in BlobLooks.kt from the same numbers, and add the
// line in both lists.
//
// Every function draws with the middle of the glass at (0, 0), in a circle of radius [r]
// (already clipped to it), for blobs of these colours, pointing along [a] (radians).

typedef _Paint = void Function(Canvas c, double r, List<Color> cs, double a);

class BlobLook {
  const BlobLook(
    this.id,
    this.name,
    this._draw, {
    this.spectrum = false,
    this.triangle = false,
    this.turns = false,
  });

  /// What is saved and what Android is told. Never shown.
  final String id;
  final String name;
  final _Paint _draw;

  /// The colours are put in rainbow order first, so that they read as light.
  final bool spectrum;

  /// Its outline is the large triangle: it can reshape into the cog (see [BlobSign.paintCog]).
  final bool triangle;

  /// On Prism's button it turns to say what is open: a sixth of a turn with the blobs out,
  /// half a turn with the app list up. The others stay pointing up, and give a bouncy shot.
  final bool turns;
}

abstract final class BlobSign {
  static const List<BlobLook> looks = <BlobLook>[
    BlobLook('pearls', 'Pearls', _pearls),
    // (Petals no longer turns, from build 184: only Window does.)
    BlobLook('petals', 'Petals', _petals),
    BlobLook('lotus', 'Lotus', _lotus),
    BlobLook('beam', 'Beam', _beam, spectrum: true),
    BlobLook('halo', 'Halo', _halo, spectrum: true),
    BlobLook(
      'window',
      'Window',
      _window,
      spectrum: true,
      triangle: true,
      turns: true,
    ),
  ];

  /// The blob's own dark ground when the look is not vivid, under the magnifying glass.
  static const Color ground = Color(0xE6121519);

  /// A triangle's tip would sit on the very edge of its glass, as an inscribed triangle's does;
  /// it is drawn lifted away from its tip, so that it sits in the middle to the eye, and a
  /// little larger. [k] is how much (1 the triangle, 0 the cog it becomes).
  static void _settleTriangle(Canvas c, double r, double angle, double k) {
    // Centred by where its corners are on the screen, whichever way it points: its middle
    // as the eye sees it, most of the way from its own centre to the middle of its outline.
    // (It was moved along the way it pointed, which is not the way it looks: turned 60°
    // it looks just as it does turned 180°, and was pushed up and to the side.)
    final Offset lift = triangleNudge(r, angle) * k;
    c
      ..translate(lift.dx, lift.dy)
      ..scale(1 + 0.06 * k);
  }

  /// How far a triangle look is moved from the middle, for it to look centred: the same on
  /// Android (BlobLooks.kt).
  static Offset triangleNudge(double r, double angle) {
    final double s = r * 0.94;
    final List<Offset> p = <Offset>[
      -Offset(math.cos(angle), math.sin(angle)) * s,
      Offset(math.cos(angle + math.pi / 3), math.sin(angle + math.pi / 3)) * s,
      Offset(math.cos(angle - math.pi / 3), math.sin(angle - math.pi / 3)) * s,
    ];
    double lx = p[0].dx, hx = lx, ly = p[0].dy, hy = ly;
    for (final Offset q in p) {
      lx = math.min(lx, q.dx);
      hx = math.max(hx, q.dx);
      ly = math.min(ly, q.dy);
      hy = math.max(hy, q.dy);
    }
    return -Offset((lx + hx) / 2, (ly + hy) / 2) * 1.06 * 0.75;
  }

  /// Where a phone starts, with nothing chosen yet: the glass and the coloured triangle are the
  /// heart of Prism. (An id no longer known falls back to it too.)
  static const String first = 'window';

  static BlobLook of(String id) => looks.firstWhere(
    (BlobLook l) => l.id == id,
    orElse: () => looks.firstWhere((BlobLook l) => l.id == first),
  );

  /// The colours as the look draws them: five at most, and in rainbow order where it asks.
  /// [vivid]: a look of light takes the light's own six colours at full strength; a look of
  /// the blobs keeps the blobs' colours, at full strength.
  static List<Color> _ordered(BlobLook look, List<Color> colours, bool vivid) {
    final List<Color> cs = colours.length > 5 ? colours.sublist(0, 5) : colours;
    if (vivid) {
      if (look.spectrum) {
        return _vividColours;
      }
      return <Color>[
        for (final Color c in cs)
          HSVColor.fromColor(c)
              .withSaturation(math.max(HSVColor.fromColor(c).saturation, 0.85))
              .withValue(math.max(HSVColor.fromColor(c).value, 0.95))
              .toColor(),
      ];
    }
    if (!look.spectrum) {
      return cs;
    }
    // From red round to violet. (The 20 keeps the reds that sit just under 360 with the rest.)
    double hue(Color c) => (HSVColor.fromColor(c).hue + 20) % 360;
    return <Color>[...cs]..sort((Color x, Color y) => hue(x).compareTo(hue(y)));
  }

  /// The cog the sign becomes while the blobs are being changed, in the sign's own colours.
  /// [t] is how far it has become the cog (0 not at all, 1 the cog). A look whose outline is
  /// the triangle reshapes into it, corner by corner; any other look draws in, and the cog
  /// grows out of its middle. [angle] is where the sign points, [spin] how far the cog has
  /// turned.
  static void paintCog(
    Canvas canvas,
    Size size,
    String id,
    List<Color> colours, {
    required double radius,
    required double t,
    double angle = -math.pi / 2,
    double spin = 0,
    bool vivid = false,
  }) {
    if (colours.isEmpty || t <= 0.001) {
      return;
    }
    final BlobLook look = of(id);
    final List<Color> cs = _ordered(look, colours, vivid);
    final double e = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
    final double r = radius, side = r * 0.94, apex = angle + math.pi;
    const int steps = 120;
    const double third = 2 * math.pi / 3;
    final Path shape = Path();
    for (int i = 0; i < steps; i++) {
      final double th = i / steps * 2 * math.pi;
      // The cog: eight teeth with sloped sides.
      final double tooth = math.cos(8 * (th - spin));
      final double k = ((tooth + 0.3) / 0.6).clamp(0.0, 1.0);
      final double cog = r * (0.47 + 0.17 * k * k * (3 - 2 * k));
      // What it comes from: the triangle's own outline at this angle, or nothing.
      double from = 0;
      if (look.triangle) {
        final double d = ((th - apex) % third + third) % third;
        from = side * 0.5 / math.cos(d - third / 2);
      }
      final double at = from + (cog - from) * e;
      final Offset p = Offset(math.cos(th), math.sin(th)) * at;
      if (i == 0) {
        shape.moveTo(p.dx, p.dy);
      } else {
        shape.lineTo(p.dx, p.dy);
      }
    }
    shape.close();
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..clipPath(
        Path()..addOval(
          Rect.fromCircle(
            center: Offset.zero,
            radius: look.triangle ? r * 1.25 : r,
          ),
        ),
      );
    if (look.triangle) {
      // Lifted and larger as the triangle is, letting that go as it becomes the cog.
      _settleTriangle(canvas, r, angle, 1 - e);
    }
    // Inside the cog, the look itself, as it is drawn everywhere: the cog is a window cut in
    // the shape of a cog onto the same picture, on the same ground (black when vivid).
    canvas
      ..save()
      ..clipPath(shape)
      ..drawCircle(
        Offset.zero,
        r,
        Paint()
          ..color = (vivid ? const Color(0xF2000000) : ground).withValues(
            alpha: look.triangle ? 1 : e,
          ),
      );
    if (!look.triangle) {
      // (The others fade in as the sign they come from draws away.)
      canvas.saveLayer(
        Rect.fromCircle(center: Offset.zero, radius: r),
        Paint()..color = Colors.white.withValues(alpha: e),
      );
    }
    if (look.id == 'window') {
      _windowField(canvas, r, cs);
    } else {
      look._draw(canvas, r, cs, angle);
    }
    if (!look.triangle) {
      canvas.restore();
    }
    canvas.restore();
    canvas
      // A little light on it from above, as on the glass.
      ..drawPath(
        shape,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, -r * 0.7),
            Offset(0, r * 0.7),
            <Color>[
              Colors.white.withValues(alpha: 0.28 * e),
              Colors.white.withValues(alpha: 0),
            ],
          ),
      )
      ..drawPath(
        shape,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = math.max(1, r * 0.035),
      )
      // The hole in its middle opens as it becomes the cog.
      ..drawCircle(
        Offset.zero,
        r * 0.19 * e,
        Paint()..color = const Color(0xFF14181C),
      )
      ..drawCircle(
        Offset.zero,
        r * 0.19 * e,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.75 * e)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, r * 0.03),
      )
      ..restore();
  }

  /// Draws look [id] in the middle of [size], in glass of radius [radius], for blobs of these
  /// [colours], pointing along [angle] (straight up by default). [fold] is how far it has
  /// folded away: 0 there, 1 gone. It shrinks as it folds, unless [shrink] is off, and then it
  /// only fades.
  static void paint(
    Canvas canvas,
    Size size,
    String id,
    List<Color> colours, {
    required double radius,
    double angle = -math.pi / 2,
    double fold = 0,
    bool shrink = true,
    bool vivid = false,
    Color? ground,
    bool ownGround = true,
  }) {
    if (colours.isEmpty || fold >= 0.999) {
      return;
    }
    final BlobLook look = of(id);
    final List<Color> cs = _ordered(look, colours, vivid);
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(shrink ? 1 - 0.7 * fold : 1);
    if (fold > 0) {
      canvas.saveLayer(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        Paint()
          ..color = Colors.white.withValues(
            alpha: (1 - fold * fold).clamp(0.0, 1.0),
          ),
      );
    }
    canvas.clipPath(
      Path()..addOval(
        Rect.fromCircle(
          center: Offset.zero,
          // (A triangle, a little larger and lifted, may reach past the circle: it is its own edge.)
          radius: look.triangle ? radius * 1.25 : radius,
        ),
      ),
    );
    if (look.triangle) {
      _settleTriangle(canvas, radius, angle, 1);
    }
    // Its own ground: black when vivid; otherwise the colour asked for, if any. Not under a
    // triangle: the triangle is the blob, and a disc behind it would be a second shape.
    if (look.triangle || !ownGround) {
      // (Nothing.)
    } else if (vivid) {
      _black(canvas, radius);
    } else if (ground != null) {
      canvas.drawCircle(Offset.zero, radius, Paint()..color = ground);
    }
    look._draw(canvas, radius, cs, angle);
    if (fold > 0) {
      canvas.restore();
    }
    canvas.restore();
  }
}

/// One of the looks, drawn small, for choosing among them.
class BlobSignPreview extends CustomPainter {
  const BlobSignPreview(this.id, this.colours, {this.vivid = false});
  final String id;
  final List<Color> colours;
  final bool vivid;

  @override
  void paint(Canvas canvas, Size size) {
    // On black, as every look is under the button's glass.
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 - 1,
      Paint()..color = const Color(0xEB000000),
    );
    BlobSign.paint(
      canvas,
      size,
      id,
      colours,
      radius: size.width / 2 - 1,
      vivid: vivid,
      ownGround: false,
    );
  }

  @override
  bool shouldRepaint(BlobSignPreview old) =>
      old.id != id ||
      old.vivid != vivid ||
      old.colours.length != colours.length;
}

// ---- Shared by the looks made of light.

Offset _dir(double a) => Offset(math.cos(a), math.sin(a));

Path _upright(Offset at, double size) => Path()
  ..moveTo(at.dx, at.dy - size)
  ..lineTo(at.dx + size * 0.866, at.dy + size * 0.5)
  ..lineTo(at.dx - size * 0.866, at.dy + size * 0.5)
  ..close();

/// A fan of the colours from [from], [half] to each side of [a], each colour holding in the
/// middle of its share and melting into the next. Drawn in one go.
void _fan(
  Canvas c,
  Offset from,
  double reach,
  List<Color> cs,
  double a,
  double half,
) {
  final int n = cs.length;
  final Paint fill = Paint()..color = cs.first;
  if (n > 1) {
    fill.shader = ui.Gradient.sweep(
      Offset.zero,
      <Color>[
        for (final Color k in cs) ...<Color>[k, k],
      ],
      <double>[
        for (int k = 0; k < n; k++) ...<double>[(k + 0.3) / n, (k + 0.7) / n],
      ],
      TileMode.clamp,
      0,
      2 * half,
    );
  }
  c
    ..save()
    ..translate(from.dx, from.dy)
    ..rotate(a - half)
    ..drawPath(
      Path()
        ..moveTo(0, 0)
        ..arcTo(
          Rect.fromCircle(center: Offset.zero, radius: reach),
          0,
          2 * half,
          false,
        )
        ..close(),
      fill,
    )
    ..restore();
}

// ---- The looks.

/// Pearls: a white point, Prism, and the blobs as lit pearls in an arc above it, the way they
/// come out of the button. Large enough to fill the glass, and balanced in it; each pearl
/// throws a little of its colour into the glass round it.
void _pearls(Canvas c, double r, List<Color> cs, double a) {
  final int n = cs.length;
  final double u = r / 29;
  final double back = (n == 1 ? 7.0 : 8.0) * u,
      reach = (n == 1 ? 15.0 : 19.0) * u,
      pr = const <double>[9.0, 8.4, 7.6, 6.9, 6.2][n - 1] * u,
      step = const <double>[0, 62, 50, 41, 34][n - 1] * math.pi / 180;
  final Offset core = -_dir(a) * back;
  final List<Offset> at = <Offset>[
    for (int k = 0; k < n; k++)
      core + _dir(a + (k - (n - 1) / 2) * step) * reach,
  ];
  for (int k = 0; k < n; k++) {
    c.drawCircle(
      at[k],
      pr * 2.1,
      Paint()
        ..shader = ui.Gradient.radial(at[k], pr * 2.1, <Color>[
          cs[k].withValues(alpha: 0.42),
          cs[k].withValues(alpha: 0),
        ]),
    );
  }
  c
    ..drawCircle(
      core,
      11 * u,
      Paint()
        ..shader = ui.Gradient.radial(core, 11 * u, <Color>[
          Colors.white.withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0),
        ]),
    )
    ..drawCircle(core, (n == 1 ? 4.0 : 3.6) * u, Paint()..color = Colors.white);
  for (int k = 0; k < n; k++) {
    // Lit from above: a bright cap, the colour, and a little shade under it.
    c.drawCircle(
      at[k],
      pr,
      Paint()
        ..shader = ui.Gradient.radial(
          at[k] - Offset(pr * 0.32, pr * 0.42),
          pr * 1.6,
          <Color>[
            Color.lerp(cs[k], Colors.white, 0.6)!,
            cs[k],
            Color.lerp(cs[k], Colors.black, 0.28)!,
          ],
          const <double>[0, 0.55, 1],
        ),
    );
    c.drawCircle(
      at[k] - Offset(pr * 0.34, pr * 0.4),
      pr * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }
}

/// Petals: the blobs' colours as petals round a quiet white point in the very middle of the
/// glass, nearly filling it.
void _petals(Canvas c, double r, List<Color> cs, double a) {
  // As Window does: each petal is a window onto the same upright bands, which stand still while
  // the petals turn. Where two lie over each other the colour is deeper, which draws them.
  final int n = cs.length;
  final double u = r / 29, step = n == 1 ? 0 : 2 * math.pi / n;
  final Rect field = Rect.fromCircle(center: Offset.zero, radius: r);
  for (int k = 0; k < n; k++) {
    final double turn = a + (k - (n - 1) / 2) * step;
    final Path petal = Path()
      ..addOval(Rect.fromLTRB(1 * u, -9.5 * u, 25 * u, 9.5 * u));
    final Path there = petal.transform(Matrix4.rotationZ(turn).storage);
    c
      ..save()
      ..clipPath(there)
      ..saveLayer(field, Paint()..color = Colors.white.withValues(alpha: 0.76));
    _windowField(c, r, cs);
    c
      ..drawRect(field, Paint()..color = Colors.white.withValues(alpha: 0.14))
      ..restore()
      ..restore();
  }
  c
    ..drawCircle(
      Offset.zero,
      6.5 * u,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, 6.5 * u, <Color>[
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0),
        ]),
    )
    ..drawCircle(
      Offset.zero,
      2.4 * u,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
}

/// Lotus: pointed petals in the blobs' colours, opening from one foot the way the blobs do,
/// the middle one tallest and in front, nearly filling the glass.
void _lotus(Canvas c, double r, List<Color> cs, double a) {
  final int n = cs.length;
  final double u = r / 29, step = (n <= 3 ? 38.0 : 29.0) * math.pi / 180;
  final Offset foot = -_dir(a) * 18 * u;
  // From the outside in, so the middle petal lies over its neighbours.
  final List<int> order = <int>[for (int k = 0; k < n; k++) k]
    ..sort(
      (int x, int y) =>
          (y - (n - 1) / 2).abs().compareTo((x - (n - 1) / 2).abs()),
    );
  for (final int k in order) {
    final double off = k - (n - 1) / 2;
    final double len = (39 - 4 * off.abs()) * u, w = 9.6 * u;
    c
      ..save()
      ..translate(foot.dx, foot.dy)
      ..rotate(a + off * step)
      ..drawPath(
        Path()
          ..moveTo(0, 0)
          ..cubicTo(len * 0.22, -w * 1.5, len * 0.72, -w * 1.05, len, 0)
          ..cubicTo(len * 0.72, w * 1.05, len * 0.22, w * 1.5, 0, 0)
          ..close(),
        Paint()
          ..color = Color.lerp(
            cs[k],
            Colors.white,
            0.14,
          )!.withValues(alpha: 0.8),
      )
      ..restore();
  }
  final Offset glow = foot + _dir(a) * 4 * u;
  c.drawCircle(
    glow,
    7 * u,
    Paint()
      ..shader = ui.Gradient.radial(glow, 7 * u, <Color>[
        Colors.white.withValues(alpha: 0.5),
        Colors.white.withValues(alpha: 0),
      ]),
  );
}

/// Beam: a short white beam into a prism set low in the glass, and out of it the colours,
/// melting into one another, wide across the rest of the glass to its edge.
void _beam(Canvas c, double r, List<Color> cs, double a) {
  final Offset at = -_dir(a) * r * 0.6;
  final double half = (cs.length == 1 ? 24 : 52) * math.pi / 180;
  _fan(c, at, r * 2.2, cs, a, half);
  c.drawCircle(
    at,
    r * 0.95,
    Paint()
      ..shader = ui.Gradient.radial(at, r * 0.95, <Color>[
        Colors.white.withValues(alpha: 0.6),
        Colors.white.withValues(alpha: 0),
      ]),
  );
  c
    ..drawLine(
      -_dir(a) * r * 1.1,
      at,
      Paint()
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = r * 0.2,
    )
    ..drawLine(
      -_dir(a) * r * 1.1,
      at,
      Paint()
        ..strokeCap = StrokeCap.round
        ..color = Colors.white
        ..strokeWidth = r * 0.08,
    );
  final Path prism = _upright(at, r * 0.45);
  c
    ..drawPath(
      prism,
      Paint()
        ..shader = ui.Gradient.linear(
          at - Offset(0, r * 0.45),
          at + Offset(0, r * 0.2),
          const <Color>[Color(0xFF39424C), Color(0xFF161B20)],
        ),
    )
    ..drawPath(
      prism,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = r * 0.055,
    );
}

/// The light's own colours, at full strength, for the Vivid looks.
const List<Color> _vividColours = <Color>[
  Color(0xFFF2334B),
  Color(0xFFFF7A2B),
  Color(0xFFFFD21F),
  Color(0xFF34C94A),
  Color(0xFF1F7BF2),
  Color(0xFF8A3FF0),
];

/// Black glass under a Vivid look.
/// (Not flat: a touch lighter in the middle and deepest at the rim, so the glass has depth.)
void _black(Canvas c, double r) => c.drawCircle(
  Offset.zero,
  r,
  Paint()
    ..shader = ui.Gradient.radial(
      Offset(0, -r * 0.15),
      r * 1.1,
      const <Color>[Color(0xFF1A1B20), Color(0xFF0B0B0E), Color(0xFF020203)],
      const <double>[0, 0.6, 1],
    ),
);

/// Halo: a ring of the colours round a small white prism in the middle.
void _halo(Canvas c, double r, List<Color> cs, double a) {
  final int n = cs.length;
  final double each = 2 * math.pi / n, gap = n == 1 ? 0 : 0.07;
  for (int k = 0; k < n; k++) {
    final double t0 = a + math.pi / 2 + k * each;
    final Path piece = Path();
    if (n == 1) {
      piece.addOval(Rect.fromCircle(center: Offset.zero, radius: r * 1.1));
    } else {
      piece
        ..moveTo(0, 0)
        ..arcTo(
          Rect.fromCircle(center: Offset.zero, radius: r * 1.1),
          t0,
          each,
          false,
        )
        ..close();
    }
    c
      ..drawPath(
        piece,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            r,
            <Color>[
              cs[k].withValues(alpha: 0),
              cs[k].withValues(alpha: 0.45),
              cs[k].withValues(alpha: 0.85),
            ],
            const <double>[0.2, 0.62, 1],
          ),
      )
      ..drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r * 0.8),
        t0 + gap + 0.06,
        n == 1 ? 2 * math.pi : each - 2 * gap - 0.12,
        false,
        Paint()
          ..color = Color.lerp(cs[k], Colors.white, 0.25)!
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = r * 0.2,
      );
  }
  c
    ..drawCircle(
      Offset.zero,
      r * 0.62,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          r * 0.62,
          <Color>[
            Colors.white.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0.3),
            Colors.white.withValues(alpha: 0),
          ],
          const <double>[0, 0.35, 1],
        ),
    )
    ..drawPath(
      _upright(Offset(0, r * 0.03), r * 0.27),
      Paint()..color = Colors.white,
    );
}

/// What Window looks onto: upright bands of the colours, standing still, with light from above.
void _windowField(Canvas c, double r, List<Color> cs) {
  final int n = cs.length;
  final Paint field = Paint()..color = cs.first;
  if (n > 1) {
    // Each colour holds across the middle of its band and melts into the next.
    field.shader = ui.Gradient.linear(
      Offset(-r, 0),
      Offset(r, 0),
      <Color>[
        for (final Color k in cs) ...<Color>[k, k],
      ],
      <double>[
        for (int k = 0; k < n; k++) ...<double>[(k + 0.25) / n, (k + 0.75) / n],
      ],
    );
  }
  c
    ..drawRect(Rect.fromCircle(center: Offset.zero, radius: r), field)
    // Light from above, the same across the whole field: it does not turn either.
    ..drawRect(
      Rect.fromCircle(center: Offset.zero, radius: r),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -r),
          Offset(0, r),
          <Color>[
            Colors.white.withValues(alpha: 0.32),
            Colors.white.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.12),
          ],
          const <double>[0, 0.55, 1],
        ),
    );
}

/// Window: the same triangle, turning the same way, but as a window onto a field of colour of
/// its own that stands still behind it: upright bands, one for each blob, from the left of the
/// glass to the right. Whichever way the triangle points, the left of it shows the same colour,
/// and so does the right. (A field lit from one point read as turning when the triangle did:
/// what showed through each corner changed as the corners moved. Upright bands do not.)
void _window(Canvas c, double r, List<Color> cs, double a) {
  final double s = r * 0.94;
  final Offset p0 = -_dir(a) * s,
      p1 = _dir(a + math.pi / 3) * s,
      p2 = _dir(a - math.pi / 3) * s;
  final Path shape = Path()
    ..moveTo(p0.dx, p0.dy)
    ..lineTo(p1.dx, p1.dy)
    ..lineTo(p2.dx, p2.dy)
    ..close();
  c
    ..save()
    ..clipPath(shape);
  _windowField(c, r, cs);
  c
    ..restore()
    ..drawPath(
      shape,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(1, r * 0.035),
    );
}
