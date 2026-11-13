import 'package:material_ui/material_ui.dart';

import '../core/glass.dart';
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

/// A round glass button: the small floating control used at the top of pages.
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
        child: Glass(
          radius: 25,
          style: GlassStyle(
            blur: 14,
            tint: 0.34,
            refraction: 18,
            bevel: 14,
            fallbackColor: c.surfaceHigh,
          ),
          child: Icon(icon, size: 22, color: c.glassInk),
        ),
      ),
    );
  }
}

/// The surface content sits on: solid enough to read on, and never glass.
ShapeDecoration card(LumenColors c, {double radius = 28, Color? tint}) =>
    ShapeDecoration(
      color:
          tint ?? (c.dark ? const Color(0xE6151820) : const Color(0xF2FFFFFF)),
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: c.hairline),
      ),
    );
