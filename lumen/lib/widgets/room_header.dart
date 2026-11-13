import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../core/haptics.dart';
import '../reference.dart';
import 'controls.dart';

import 'package:flutter/services.dart';

import 'dart:async';

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
                  Row(
                    children: <Widget>[
                      Text(
                        tag ?? 'ROOM ${number.toString().padLeft(2, '0')}',
                        style: LumenType.label(color: c.accent),
                      ),
                      const SizedBox(width: 8),
                      RefChip(number: number),
                    ],
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

/// The example's id. Tap it to copy a line you can paste to another chat.
class RefChip extends StatefulWidget {
  const RefChip({super.key, required this.number});
  final int number;

  @override
  State<RefChip> createState() => _RefChipState();
}

class _RefChipState extends State<RefChip> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Ref? r = refs[widget.number];
    if (r == null) {
      return const SizedBox.shrink();
    }
    final LumenColors c = LumenColors.of(context);
    return Semantics(
      button: true,
      label: 'Copy reference ${r.id}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Clipboard.setData(ClipboardData(text: r.text));
          Haptics.tick();
          setState(() => _copied = true);
          _timer?.cancel();
          _timer = Timer(
            const Duration(milliseconds: 1500),
            () => setState(() => _copied = false),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: ShapeDecoration(
            color: _copied ? c.accent : c.ink.withValues(alpha: 0.08),
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _copied ? 'Copied' : r.id,
                style: LumenType.text(
                  11,
                  weight: 700,
                  color: _copied ? c.onAccent : c.inkMuted,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _copied ? Icons.check_rounded : Icons.content_copy_rounded,
                size: 11,
                color: _copied ? c.onAccent : c.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
