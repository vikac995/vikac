import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/panel.dart';
import '../../widgets/room_header.dart';

/// Room 36. One small screen, restyled live. The point: a look is a handful
/// of numbers (colour, corner, spacing, light or dark), and the line under
/// the preview states them so a screenshot carries the exact recipe.
class ThemeRoom extends StatefulWidget {
  const ThemeRoom({super.key});

  @override
  State<ThemeRoom> createState() => _ThemeRoomState();
}

class _ThemeRoomState extends State<ThemeRoom> {
  static const List<(String, Color)> _accents = <(String, Color)>[
    ('Ember', Color(0xFFFF6B4A)),
    ('Plum', Color(0xFF9B6BFF)),
    ('Sky', Color(0xFF3FA9F5)),
    ('Mint', Color(0xFF22C7A0)),
    ('Gold', Color(0xFFF5B301)),
    ('Rose', Color(0xFFF0508C)),
  ];
  int _accent = 0;
  double _corner = 0.6; // 0..1 → 4..36
  String _density = 'Regular';
  bool _dark = true;
  bool _tinted = true;

  double get _radius => 4 + _corner * 32;
  double get _gap => switch (_density) {
    'Compact' => 8,
    'Roomy' => 18,
    _ => 12,
  };
  String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final Color a = _accents[_accent].$2;
    // Tinted neutrals: the background borrows a little of the accent.
    final Color baseBg = _dark
        ? const Color(0xFF0E0F13)
        : const Color(0xFFF5F3EF);
    final Color bg = _tinted
        ? Color.lerp(baseBg, a, _dark ? 0.07 : 0.06)!
        : baseBg;
    final Color card = Color.lerp(
      bg,
      _dark ? Colors.white : Colors.white,
      _dark ? 0.07 : 0.75,
    )!;
    final Color ink = _dark ? const Color(0xFFF4F1EC) : const Color(0xFF17181C);
    final Color muted = ink.withValues(alpha: 0.62);
    final Color onA = a.computeLuminance() > 0.45
        ? const Color(0xFF16110A)
        : Colors.white;
    const Duration d = Duration(milliseconds: 260);
    final BorderRadius r = BorderRadius.circular(_radius);

    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 36,
          title: 'Theme lab',
          hint: 'Pattern: change four numbers and the same screen becomes a different product. The line under the preview is the recipe; screenshot it.',
        ),
        const SizedBox(height: 16),
        AnimatedContainer(
          duration: d,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(_gap + 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_radius + 8),
            border: Border.all(color: ink.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Thursday',
                          style: LumenType.text(13, color: muted),
                        ),
                        Text(
                          'Push day',
                          style: LumenType.display(28, weight: 700, color: ink),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: d,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: a.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(_radius.clamp(4, 22)),
                    ),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      color: a,
                      size: 22,
                    ),
                  ),
                ],
              ),
              AnimatedContainer(duration: d, height: _gap + 4),
              AnimatedContainer(
                duration: d,
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.all(_gap + 4),
                decoration: BoxDecoration(color: card, borderRadius: r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'This week',
                      style: LumenType.text(13, weight: 600, color: muted),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '3',
                          style: LumenType.display(
                            40,
                            weight: 720,
                            color: ink,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5, left: 6),
                          child: Text(
                            'of 4 sessions',
                            style: LumenType.text(14, color: muted),
                          ),
                        ),
                      ],
                    ),
                    AnimatedContainer(duration: d, height: _gap),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(_radius.clamp(0, 5)),
                      child: SizedBox(
                        height: 10,
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: ColoredBox(
                                color: ink.withValues(alpha: 0.1),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: 0.75,
                              heightFactor: 1,
                              child: AnimatedContainer(duration: d, color: a),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(duration: d, height: _gap),
              Row(
                children: <Widget>[
                  for (final (int i, String t) in <String>[
                    'Bench',
                    'Dips',
                    'Fly',
                  ].indexed) ...<Widget>[
                    if (i > 0)
                      AnimatedContainer(duration: d, width: _gap * 0.7),
                    AnimatedContainer(
                      duration: d,
                      padding: EdgeInsets.symmetric(
                        horizontal: _gap + 2,
                        vertical: _gap * 0.6 + 2,
                      ),
                      decoration: BoxDecoration(
                        color: i == 0
                            ? a.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          _radius.clamp(4, 20),
                        ),
                        border: Border.all(
                          color: i == 0
                              ? Colors.transparent
                              : ink.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        t,
                        style: LumenType.text(
                          13.5,
                          weight: 620,
                          color: i == 0 ? a : ink,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              AnimatedContainer(duration: d, height: _gap + 4),
              AnimatedContainer(
                duration: d,
                curve: Curves.easeOutCubic,
                height: 40 + _gap,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: a,
                  borderRadius: BorderRadius.circular(_radius.clamp(4, 28)),
                ),
                child: Text(
                  'Start workout',
                  style: LumenType.text(
                    15.5,
                    weight: 680,
                    color: onA,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'accent ${_hex(a)}  ·  corner ${_radius.round()}  ·  gap ${_gap.round()}  ·  ${_dark ? 'dark' : 'light'}${_tinted ? ', tinted' : ''}',
          textAlign: TextAlign.center,
          style: LumenType.text(12.5, weight: 600, color: c.inkMuted),
        ),
        const SectionLabel('Accent'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            for (int i = 0; i < _accents.length; i++)
              GestureDetector(
                onTap: () {
                  setState(() => _accent = i);
                  Haptics.tick();
                },
                child: Semantics(
                  label: _accents[i].$1,
                  selected: i == _accent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 48,
                    height: 48,
                    padding: EdgeInsets.all(i == _accent ? 4 : 8),
                    decoration: ShapeDecoration(
                      shape: CircleBorder(
                        side: BorderSide(
                          color: i == _accent
                              ? _accents[i].$2
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: _accents[i].$2,
                        shape: const CircleBorder(),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SectionLabel(
          'Corners',
          detail:
              '${_radius.round()} px. Sharp reads technical, round reads friendly.',
        ),
        LumenSlider(
          value: _corner,
          onChanged: (double v) => setState(() => _corner = v),
        ),
        const SectionLabel('Spacing'),
        Segmented<String>(
          values: const <String>['Compact', 'Regular', 'Roomy'],
          labels: const <String>['Compact', 'Regular', 'Roomy'],
          value: _density,
          onChanged: (String v) => setState(() => _density = v),
        ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            children: <Widget>[
              SwitchLine(
                label: 'Dark',
                value: _dark,
                onChanged: (bool v) => setState(() => _dark = v),
              ),
              const SizedBox(height: 12),
              SwitchLine(
                label: 'Tint the background with the accent',
                value: _tinted,
                onChanged: (bool v) => setState(() => _tinted = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
