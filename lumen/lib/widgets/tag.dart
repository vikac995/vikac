import 'package:material_ui/material_ui.dart';

import '../core/haptics.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../reference.dart';
import 'controls.dart';
import 'room_header.dart';

/// Marks a piece of an example screen. With "Show names" on, a small badge
/// with its id and name is drawn on it, so a screenshot says what it shows.
class Tag extends StatelessWidget {
  const Tag(this.id, this.name, {super.key, required this.child});
  final String id;
  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, Widget? child) {
        if (!settings.showLabels) {
          return child!;
        }
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            child!,
            Positioned(
              left: 6,
              top: -9,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: const ShapeDecoration(
                    color: Color(0xFF2E7BFF),
                    shape: StadiumBorder(),
                  ),
                  child: Text(
                    '$id  $name',
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}

/// The bar at the top of a full example screen: back, the screen's id, and
/// the switch for names.
class ScreenBar extends StatelessWidget {
  const ScreenBar({super.key, required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final Ref? r = refs[number];
    return Row(
      children: <Widget>[
        RoundButton(
          icon: Icons.arrow_back_rounded,
          semanticLabel: 'Back',
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 10),
        if (r != null)
          Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
            decoration: ShapeDecoration(
              color: c.surface,
              shape: StadiumBorder(side: BorderSide(color: c.hairline)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  r.title,
                  style: LumenType.text(
                    12.5,
                    weight: 650,
                    color: c.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: 6),
                RefChip(number: number),
              ],
            ),
          ),
        const Spacer(),
        ListenableBuilder(
          listenable: settings,
          builder: (BuildContext context, Widget? _) => Semantics(
            button: true,
            toggled: settings.showLabels,
            label: 'Show names',
            child: GestureDetector(
              onTap: () {
                settings.showLabels = !settings.showLabels;
                Haptics.tick();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: ShapeDecoration(
                  color: settings.showLabels
                      ? const Color(0xFF2E7BFF)
                      : c.surface,
                  shape: CircleBorder(side: BorderSide(color: c.hairline)),
                ),
                child: Icon(
                  Icons.sell_outlined,
                  size: 20,
                  color: settings.showLabels ? Colors.white : c.ink,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
