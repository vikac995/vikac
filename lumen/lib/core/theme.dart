import 'package:material_ui/material_ui.dart';

/// Colour roles. Light and dark are designed separately, not derived.
@immutable
class LumenColors extends ThemeExtension<LumenColors> {
  const LumenColors({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.accent,
    required this.onAccent,
    required this.hairline,
    required this.glassTint,
    required this.glassInk,
    required this.shadow,
  });

  final bool dark;
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color accent;
  final Color onAccent;
  final Color hairline;

  /// Colour mixed into glass, and the colour of text and icons on it.
  final Color glassTint;
  final Color glassInk;
  final Color shadow;

  static const LumenColors night = LumenColors(
    dark: true,
    bg: Color(0xFF0B0D12),
    surface: Color(0xFF14171F),
    surfaceHigh: Color(0xFF1D212B),
    ink: Color(0xFFF3F0EA),
    inkMuted: Color(0xFFA6AAB6),
    inkFaint: Color(0xFF666B78),
    accent: Color(0xFFFF6B4A),
    onAccent: Color(0xFF200C06),
    hairline: Color(0x14FFFFFF),
    glassTint: Color(0xFF10131A),
    glassInk: Color(0xFFFFFFFF),
    shadow: Color(0x66000000),
  );

  static const LumenColors day = LumenColors(
    dark: false,
    bg: Color(0xFFF4F0E8),
    surface: Color(0xFFFFFCF7),
    surfaceHigh: Color(0xFFFFFFFF),
    ink: Color(0xFF16171B),
    inkMuted: Color(0xFF5B5E68),
    inkFaint: Color(0xFF9B9DA4),
    accent: Color(0xFFD9431F),
    onAccent: Color(0xFFFFFFFF),
    hairline: Color(0x14000000),
    glassTint: Color(0xFFFBF8F2),
    glassInk: Color(0xFF16171B),
    shadow: Color(0x2E2A1A0A),
  );

  static LumenColors of(BuildContext context) =>
      Theme.of(context).extension<LumenColors>()!;

  @override
  LumenColors copyWith() => this;

  @override
  LumenColors lerp(LumenColors? other, double t) {
    if (other == null) {
      return this;
    }
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return LumenColors(
      dark: t < 0.5 ? dark : other.dark,
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surfaceHigh: c(surfaceHigh, other.surfaceHigh),
      ink: c(ink, other.ink),
      inkMuted: c(inkMuted, other.inkMuted),
      inkFaint: c(inkFaint, other.inkFaint),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      hairline: c(hairline, other.hairline),
      glassTint: c(glassTint, other.glassTint),
      glassInk: c(glassInk, other.glassInk),
      shadow: c(shadow, other.shadow),
    );
  }
}

/// Type. Bricolage Grotesque for display (weight and width are continuous
/// axes), Inter for text and controls.
abstract final class LumenType {
  static TextStyle display(
    double size, {
    double weight = 700,
    double width = 100,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Bricolage',
      fontSize: size,
      height: height ?? 1.02,
      letterSpacing: -0.02 * size,
      color: color,
      fontVariations: <FontVariation>[
        FontVariation('wght', weight),
        FontVariation('wdth', width),
        FontVariation('opsz', size.clamp(12, 96)),
      ],
    );
  }

  static TextStyle text(
    double size, {
    double weight = 450,
    Color? color,
    double? height,
    double? spacing,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      height: height ?? 1.35,
      letterSpacing: spacing ?? (size < 13 ? 0.01 * size : -0.006 * size),
      color: color,
      fontVariations: <FontVariation>[
        FontVariation('wght', weight),
        FontVariation('opsz', size.clamp(14, 32)),
      ],
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  /// Small uppercase label.
  static TextStyle label({Color? color}) =>
      text(11, weight: 600, color: color, spacing: 0.9);
}

ThemeData lumenTheme(LumenColors c) {
  final Brightness b = c.dark ? Brightness.dark : Brightness.light;
  return ThemeData(
    brightness: b,
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: b,
      surface: c.bg,
      primary: c.accent,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: const Color(0x00000000),
    fontFamily: 'Inter',
    extensions: <ThemeExtension<dynamic>>[c],
  );
}
