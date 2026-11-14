import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import 'controls.dart';

/// A surface card.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: color ?? c.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: c.hairline),
        ),
      ),
      child: child,
    );
  }
}

/// Small uppercase heading above a block.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.detail});
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(text.toUpperCase(), style: LumenType.label(color: c.inkFaint)),
          if (detail != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(detail!, style: LumenType.text(14, color: c.inkMuted)),
          ],
        ],
      ),
    );
  }
}

/// A labelled switch row.
class SwitchLine extends StatelessWidget {
  const SwitchLine({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: LumenType.text(15, weight: 560, color: c.ink),
            ),
          ),
          LumenSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// The standard scrolling body of a room.
class RoomScaffold extends StatelessWidget {
  const RoomScaffold({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 32),
        children: children,
      ),
    );
  }
}

/// How every bottom panel comes and goes: it slides up from the bottom edge
/// by its own height, the same quick move as the quick-action sheets
/// (Weigh-in and the others). Only the panel moves; nothing behind it is redrawn.
class PanelRise extends StatelessWidget {
  const PanelRise({super.key, required this.child});
  final Widget child;

  static final Animatable<Offset> _path = Tween<Offset>(
    begin: const Offset(0, 1.1),
    end: Offset.zero,
  );

  @override
  Widget build(BuildContext context) {
    final Animation<double> a =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: _path.animate(
          CurvedAnimation(
            parent: a,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// The timing every bottom panel uses, with [PanelRise].
const Duration panelTime = Duration(milliseconds: 260);

/// No fade on the panel itself: it slides, and only the shade behind it fades.
Widget panelNoFade(
  BuildContext context,
  Animation<double> a,
  Animation<double> b,
  Widget child,
) => child;
