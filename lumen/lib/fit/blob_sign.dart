import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

// The looks the Blob's sign can have, chosen in the Blob panel.
//
// TO REMOVE A LOOK: delete its line in [BlobSign.looks] and its one function below, and the
// same two things in android/.../BlobLooks.kt. Nothing else knows the looks by name: a phone
// that had the removed one chosen falls back to the first in the list.
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
    BlobLook('petals', 'Petals', _petals, turns: true),
    BlobLook('lotus', 'Lotus', _lotus),
    BlobLook('beam', 'Beam', _beam, spectrum: true),
    BlobLook('bands', 'Bands', _bands, spectrum: true),
    BlobLook('bandsclear', 'Clear', _bandsClear, spectrum: true),
    BlobLook('bandswhite', 'Lined', _bandsWhite, spectrum: true),
    BlobLook('halo', 'Halo', _halo, spectrum: true),
    BlobLook(
      'triangle',
      'Triangle',
      _triangle,
      spectrum: true,
      triangle: true,
      turns: true,
    ),
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

  static BlobLook of(String id) =>
      looks.firstWhere((BlobLook l) => l.id == id, orElse: () => looks.first);

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
        Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)),
      );
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
    _vividNow = vivid;
    if (look.id == 'window') {
      _windowField(canvas, r, cs);
    } else if (look.id == 'triangle') {
      _triangleField(canvas, r, cs, angle, e);
    } else {
      look._draw(canvas, r, cs, angle);
    }
    _vividNow = false;
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
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    // Its own ground: black when vivid; otherwise the colour asked for, if any. Not under a
    // triangle: the triangle is the blob, and a disc behind it would be a second shape.
    if (look.triangle) {
      // (Nothing.)
    } else if (vivid) {
      _black(canvas, radius);
    } else if (ground != null) {
      canvas.drawCircle(Offset.zero, radius, Paint()..color = ground);
    }
    _vividNow = vivid;
    look._draw(canvas, radius, cs, angle);
    _vividNow = false;
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
  void paint(Canvas canvas, Size size) => BlobSign.paint(
    canvas,
    size,
    id,
    colours,
    radius: size.width / 2 - 1,
    vivid: vivid,
    ground: BlobSign.ground,
  );

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

/// Pearls: a white point, Prism, and the blobs around it as small lit pearls on the side they
/// come out from. Each throws a little of its colour into the glass.
void _pearls(Canvas c, double r, List<Color> cs, double a) {
  final int n = cs.length;
  final double u = r / 29;
  final double back = (n == 1 ? 6.0 : 10.0) * u,
      reach = (n == 1 ? 14.0 : 21.0) * u,
      pr = const <double>[6.0, 5.4, 4.8, 4.3, 3.9][n - 1] * u,
      step = const <double>[0, 52, 40, 31, 26][n - 1] * math.pi / 180;
  final Offset core = -_dir(a) * back;
  final List<Offset> at = <Offset>[
    for (int k = 0; k < n; k++)
      core + _dir(a + (k - (n - 1) / 2) * step) * reach,
  ];
  for (int k = 0; k < n; k++) {
    c.drawCircle(
      at[k],
      pr * 2.3,
      Paint()
        ..shader = ui.Gradient.radial(at[k], pr * 2.3, <Color>[
          cs[k].withValues(alpha: 0.5),
          cs[k].withValues(alpha: 0),
        ]),
    );
  }
  c
    ..drawCircle(
      core,
      10 * u,
      Paint()
        ..shader = ui.Gradient.radial(core, 10 * u, <Color>[
          Colors.white.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0),
        ]),
    )
    ..drawCircle(core, (n == 1 ? 3.4 : 3.0) * u, Paint()..color = Colors.white);
  for (int k = 0; k < n; k++) {
    c.drawCircle(
      at[k],
      pr,
      Paint()
        ..shader = ui.Gradient.radial(
          at[k] - Offset(pr * 0.3, pr * 0.4),
          pr * 1.5,
          <Color>[Color.lerp(cs[k], Colors.white, 0.55)!, cs[k], cs[k]],
          const <double>[0, 0.6, 1],
        ),
    );
  }
}

/// Petals: the blobs' colours as petals round a quiet white point in the very middle of the
/// glass, nearly filling it.
void _petals(Canvas c, double r, List<Color> cs, double a) {
  final int n = cs.length;
  final double u = r / 29, step = n == 1 ? 0 : 2 * math.pi / n;
  for (int k = 0; k < n; k++) {
    c
      ..save()
      ..rotate(a + (k - (n - 1) / 2) * step)
      ..drawOval(
        Rect.fromLTRB(1 * u, -9.5 * u, 25 * u, 9.5 * u),
        Paint()
          ..color = Color.lerp(
            cs[k],
            Colors.white,
            0.14,
          )!.withValues(alpha: 0.76),
      )
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

/// Bands: the same light through the same prism, but cut clean: each colour a flat band with
/// a dark line between it and the next, seen paler through the prism, which is drawn bold.
void _bands(Canvas c, double r, List<Color> cs, double a) =>
    _cutBands(c, r, cs, a, const Color(0xFF0B0E11), 0.05);

/// Clear: the bands with nothing between them, colour straight against colour.
void _bandsClear(Canvas c, double r, List<Color> cs, double a) =>
    _cutBands(c, r, cs, a, null, 0);

/// Lined: the bands with a very thin white line between them.
void _bandsWhite(Canvas c, double r, List<Color> cs, double a) =>
    _cutBands(c, r, cs, a, Colors.white, 0.018);

/// Whether the look being drawn is vivid: then nothing greys the black (see [_cutBands]).
bool _vividNow = false;

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
void _black(Canvas c, double r) =>
    c.drawCircle(Offset.zero, r, Paint()..color = const Color(0xF2000000));

/// The flat bands of the looks above. [line] is drawn between the colours, [width] of
/// the glass's radius wide; with no line there is none. (Used only by Bands, Clear, Lined and
/// Vivid: when the last of them is removed, this goes with it.)
void _cutBands(
  Canvas c,
  double r,
  List<Color> cs,
  double a,
  Color? line,
  double width, {
  double shine = 0.6,
}) {
  final int n = cs.length;
  final Offset at = -_dir(a) * r * 0.6;
  final double half = (n == 1 ? 24 : 54) * math.pi / 180, each = 2 * half / n;
  const Color dark = Color(0xFF0B0E11);
  Path band(int k, double reach) => Path()
    ..moveTo(0, 0)
    ..arcTo(
      Rect.fromCircle(center: Offset.zero, radius: reach),
      k * each,
      each,
      false,
    )
    ..close();
  c
    ..save()
    ..translate(at.dx, at.dy)
    ..rotate(a - half);
  for (int k = 0; k < n; k++) {
    c.drawPath(band(k, r * 2.2), Paint()..color = cs[k]);
  }
  if (line != null) {
    // Between the colours only: the fan's two outer edges lie against the dark glass.
    for (int k = line == dark ? 0 : 1; k <= (line == dark ? n : n - 1); k++) {
      c.drawLine(
        Offset.zero,
        _dir(k * each) * r * 2.2,
        Paint()
          ..color = line
          ..strokeWidth = math.max(1, r * width),
      );
    }
  }
  c
    ..restore()
    // The same white shine round the prism as Beam has.
    ..drawCircle(
      at,
      r * 0.95,
      Paint()
        ..shader = ui.Gradient.radial(at, r * 0.95, <Color>[
          Colors.white.withValues(alpha: _vividNow ? 0 : shine),
          Colors.white.withValues(alpha: 0),
        ]),
    )
    ..drawLine(
      -_dir(a) * r * 1.1,
      at,
      Paint()
        ..color = Colors.white
        ..strokeWidth = r * 0.13,
    );
  final Path prism = _upright(at, r * 0.45);
  // The bands again inside the prism, paler: the light seen through the glass.
  c
    ..drawPath(prism, Paint()..color = dark)
    ..save()
    ..clipPath(prism)
    ..translate(at.dx, at.dy)
    ..rotate(a - half);
  for (int k = 0; k < n; k++) {
    c.drawPath(
      band(k, r),
      Paint()..color = Color.lerp(cs[k], Colors.white, 0.45)!,
    );
  }
  c
    ..restore()
    ..drawPath(
      prism,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = r * 0.08,
    );
}

/// Halo: white light in the middle, and the rim of the glass splits it, as the edge of a lens
/// does. Each blob owns one piece of the rim. A small white prism marks the middle.
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

/// Triangle: the prism itself, as large as the glass allows, made of light: white at the
/// corner the light comes in by, the colours fanned across the far side.
void _triangle(Canvas c, double r, List<Color> cs, double a) {
  final double s = r * 0.94;
  final Offset apex = -_dir(a) * s;
  // (No coloured glow behind it: lifted from under the glass, it would show as a disc.)
  final Offset p1 = _dir(a + math.pi / 3) * s, p2 = _dir(a - math.pi / 3) * s;
  final Path shape = Path()
    ..moveTo(apex.dx, apex.dy)
    ..lineTo(p1.dx, p1.dy)
    ..lineTo(p2.dx, p2.dy)
    ..close();
  c
    ..save()
    ..clipPath(shape);
  _triangleField(c, r, cs, a, 0);
  c
    ..restore()
    ..drawPath(
      shape,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(1, r * 0.03),
    );
}

/// What Triangle is filled with: the colours fanned from the corner the light comes in by, white
/// there. [open] widens the fan, from just the triangle (0) to all round (1), for the cog.
void _triangleField(Canvas c, double r, List<Color> cs, double a, double open) {
  final double s = r * 0.94;
  final Offset apex = -_dir(a) * s;
  _fan(
    c,
    apex,
    r * 2.4,
    cs,
    a,
    math.pi / 6 + (math.pi / 2.1 - math.pi / 6) * open,
  );
  c.drawCircle(
    apex,
    s * 1.75,
    Paint()
      ..shader = ui.Gradient.radial(
        apex,
        s * 1.75,
        <Color>[
          Colors.white,
          Colors.white.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0),
        ],
        const <double>[0, 0.3, 0.62, 1],
      ),
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
