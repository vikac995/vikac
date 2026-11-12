import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import 'controls.dart';

/// Back button, room number and title. Sits below the frame-rate readout.
class RoomHeader extends StatelessWidget {
  const RoomHeader({
    super.key,
    required this.number,
    required this.title,
    this.hint,
    this.tag,
  });
  final int number;

  /// Replaces "ROOM 0n" when set.
  final String? tag;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            RoundButton(
              icon: Icons.arrow_back_rounded,
              semanticLabel: 'Back',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tag ?? 'ROOM ${number.toString().padLeft(2, '0')}',
                    style: LumenType.label(color: c.accent),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: LumenType.display(30, weight: 720, color: c.ink),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 2),
            child: Text(
              hint!,
              style: LumenType.text(14, color: c.inkMuted, height: 1.4),
            ),
          ),
      ],
    );
  }
}
