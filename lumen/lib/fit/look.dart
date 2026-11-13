import 'dart:io';

import 'package:flutter/widgets.dart';

import '../core/theme.dart';

/// Prism's look, generated from two choices: a colour and a kind of background.
///
/// Nothing here is a ready-made theme. The person picks only the hue. How
/// vivid and how bright each colour is, whether text on the accent is dark
/// or light, the near-black the pages sit on and the colours the background
/// shades through are all worked out by fixed rules, so every choice comes
/// out with the same contrast and balance. It is worked out once when the
/// choice changes; after that it is plain colours and one saved picture.
class Look extends ChangeNotifier {
  Look._();
  static final Look instance = Look._();

  /// Hues offered, in degrees round the colour wheel.
  static const List<double> hues = <double>[
    38,
    20,
    2,
    332,
    276,
    222,
    192,
    152,
    96,
  ];

  /// 0 flow: glowing orbs. 1 pattern: rings and dots. 2 both.
  static const List<String> vibes = <String>['Flow', 'Pattern', 'Both'];

  double _hue = 38;
  int _vibe = 0;

  /// Goes up each time the look changes, so the background picture knows to redraw itself once.
  int version = 0;
  double get hue => _hue;
  int get vibe => _vibe;
  late LumenColors night = _colours(true), day = _colours(false);

  File get _file {
    // Kept with the app's own files where there are any; they survive a cache clear-out.
    final Directory files = Directory(
      '${Directory.systemTemp.parent.path}/files',
    );
    return File(
      '${files.existsSync() ? files.path : Directory.systemTemp.path}/prism_look_v1',
    );
  }

  void load() {
    try {
      final List<String> saved = _file.readAsStringSync().split(' ');
      _hue = double.parse(saved[0]);
      _vibe = int.parse(saved[1]).clamp(0, vibes.length - 1);
      _remake();
    } catch (_) {
      // Nothing chosen yet: amber and flow.
    }
  }

  void choose({double? hue, int? vibe}) {
    _hue = hue ?? _hue;
    _vibe = vibe ?? _vibe;
    _remake();
    notifyListeners();
    try {
      _file.writeAsStringSync('$_hue $_vibe');
    } catch (_) {
      // Not saved: it is simply asked for again next time.
    }
  }

  void _remake() {
    night = _colours(true);
    day = _colours(false);
    version++;
  }

  static Color _hsl(double h, double s, double l) =>
      HSLColor.fromAHSL(1, (h % 360 + 360) % 360, s, l).toColor();

  /// A colour of this hue at a wanted brightness as the eye sees it. Yellow is bright and blue is
  /// dark at the same nominal lightness; this evens them out, so every hue's accent carries the same weight.
  static Color _atBrightness(double h, double s, double want) {
    double lo = 0.2, hi = 0.85;
    for (int i = 0; i < 16; i++) {
      final double mid = (lo + hi) / 2;
      if (_hsl(h, s, mid).computeLuminance() < want) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return _hsl(h, s, (lo + hi) / 2);
  }

  /// The accent a hue would give, for showing the choices.
  static Color accentFor(double h, bool dark) {
    // How bright a hue is by nature: yellow and green are bright, blue and red are not. Forcing
    // them all to one brightness turned blue and red into pastels. Each is taken near its own
    // natural brightness, kept between a floor (so it shows on black) and a ceiling.
    final double natural = _hsl(h, 1, 0.5).computeLuminance();
    final double want = (natural * 1.05).clamp(0.24, 0.52);
    return _atBrightness(h, 0.95, dark ? want : want * 0.74);
  }

  LumenColors _colours(bool dark) {
    final Color accent = accentFor(_hue, dark);
    // Dark text on a bright accent, light text on a deep one.
    final Color onAccent = accent.computeLuminance() > 0.30
        ? _hsl(_hue, 0.7, 0.06)
        : const Color(0xFFFFFFFF);
    return dark
        ? LumenColors(
            dark: true,
            // Not pure black: a breath of the chosen colour, so the whole app leans the same way.
            bg: _hsl(_hue, 0.16, 0.04),
            surface: _hsl(_hue, 0.14, 0.09),
            surfaceHigh: _hsl(_hue, 0.13, 0.135),
            ink: const Color(0xFFF5F1E8),
            inkMuted: const Color(0xFFABADB6),
            inkFaint: const Color(0xFF6A6D78),
            accent: accent,
            onAccent: onAccent,
            hairline: const Color(0x1AFFFFFF),
            glassTint: _hsl(_hue, 0.16, 0.07),
            glassInk: const Color(0xFFFFFFFF),
            shadow: const Color(0x66000000),
          )
        : LumenColors(
            dark: false,
            bg: _hsl(_hue, 0.7, 0.965),
            surface: _hsl(_hue, 0.6, 0.99),
            surfaceHigh: const Color(0xFFFFFFFF),
            ink: const Color(0xFF17150F),
            inkMuted: const Color(0xFF5E5A50),
            inkFaint: const Color(0xFF9E998C),
            accent: accent,
            onAccent: onAccent,
            hairline: const Color(0x14000000),
            glassTint: _hsl(_hue, 0.6, 0.98),
            glassInk: const Color(0xFF17150F),
            shadow: const Color(0x2E2A1A0A),
          );
  }

  /// What the background shades through: a deeper neighbour, the colour itself, a lighter neighbour.
  /// Amber gives deep orange to yellow; blue gives indigo to sky. Always the two hues either side.
  Color get deep => _hsl(_hue - 16, 0.95, 0.40);
  Color get mid => _hsl(_hue, 0.98, 0.50);
  Color get light => _hsl(_hue + 18, 0.98, 0.66);
}
