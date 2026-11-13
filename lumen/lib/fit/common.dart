import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../widgets/pressable.dart';

/// The heading at the top of each of Prism's pages, with room for one glass button.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.kicker, this.icon, this.onIcon});
  final String title;
  final String? kicker;
  final IconData? icon;
  final VoidCallback? onIcon;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (kicker != null)
                Text(
                  kicker!.toUpperCase(),
                  style: LumenType.label(color: c.inkMuted),
                ),
              Text(
                title,
                style: LumenType.display(
                  40,
                  weight: 720,
                  color: c.ink,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        if (icon != null) GlassDot(icon: icon!, onTap: onIcon),
      ],
    );
  }
}

/// A round button: the small control at the top of a page.
class GlassDot extends StatelessWidget {
  const GlassDot({super.key, required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Pressable(
      onTap: onTap,
      child: SizedBox.square(
        dimension: 50,
        // Solid. As glass it scrolled with the page, so its backdrop changed every frame; Home was the slowest screen for it.
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: c.surfaceHigh,
            shape: CircleBorder(side: BorderSide(color: c.hairline)),
          ),
          child: Icon(icon, size: 22, color: c.ink),
        ),
      ),
    );
  }
}

/// Prism's own colours. The accent is amber, between orange and yellow: warm, and its own.
/// (Lumen's coral was close to another product's colour.) Text on the accent is near-black,
/// because white on amber is hard to read.
const LumenColors prismNight = LumenColors(
  dark: true,
  bg: Color(0xFF08090C),
  surface: Color(0xFF13151B),
  surfaceHigh: Color(0xFF1C1F27),
  ink: Color(0xFFF5F1E8),
  inkMuted: Color(0xFFABADB6),
  inkFaint: Color(0xFF6A6D78),
  accent: Color(0xFFFFAE1A),
  onAccent: Color(0xFF1D1300),
  hairline: Color(0x1AFFFFFF),
  glassTint: Color(0xFF0E1015),
  glassInk: Color(0xFFFFFFFF),
  shadow: Color(0x66000000),
);
const LumenColors prismDay = LumenColors(
  dark: false,
  bg: Color(0xFFFFF7EA),
  surface: Color(0xFFFFFDF8),
  surfaceHigh: Color(0xFFFFFFFF),
  ink: Color(0xFF17150F),
  inkMuted: Color(0xFF5E5A50),
  inkFaint: Color(0xFF9E998C),
  accent: Color(0xFFF59300),
  onAccent: Color(0xFF1D1300),
  hairline: Color(0x14000000),
  glassTint: Color(0xFFFFFAF0),
  glassInk: Color(0xFF17150F),
  shadow: Color(0x2E2A1A0A),
);

/// The surface content sits on. Readable first, but no longer a closed lid: about a fifth of
/// what is behind comes through, so the glowing shapes of the background tint each card.
ShapeDecoration card(LumenColors c, {double radius = 28, Color? tint}) =>
    ShapeDecoration(
      color:
          tint ?? (c.dark ? const Color(0xC9131519) : const Color(0xD9FFFDF8)),
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: c.hairline),
      ),
    );
