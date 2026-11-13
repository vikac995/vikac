import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/panel.dart';
import '../../widgets/room_header.dart';

const List<(String, String, String, Color, IconData)> _cards =
    <(String, String, String, Color, IconData)>[
      (
        'Kcal left',
        '1,370',
        '1030 of 2400 eaten',
        Color(0xFFB8532F),
        Icons.local_fire_department_rounded,
      ),
      (
        'Weight',
        '81.8 kg',
        'Down 0.3 this week',
        Color(0xFF3B57B5),
        Icons.monitor_weight_outlined,
      ),
      (
        'Steps',
        '8,214',
        '82 % of today',
        Color(0xFF1F7F78),
        Icons.directions_walk_rounded,
      ),
      (
        'Sleep',
        '7 h 24',
        'Bed at 23:10',
        Color(0xFF6B45B0),
        Icons.bedtime_rounded,
      ),
    ];

/// Room 56. A stack of widgets: several widgets share one place on the
/// screen. Swipe up or down on it to turn to the next; the edges of the
/// others show underneath so you know there is more.
class StackRoom extends StatefulWidget {
  const StackRoom({super.key});

  @override
  State<StackRoom> createState() => _StackRoomState();
}

class _StackRoomState extends State<StackRoom>
    with SingleTickerProviderStateMixin {
  static const double _h = 170;
  late final SpringValue _at = SpringValue(this, spring: Motions.expressive);
  bool _smart = true;

  @override
  void dispose() {
    _at.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final int n = _cards.length;
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 56,
          title: 'Widget stack',
          hint: 'Pattern: several widgets in one place. Swipe up or down on the stack. The dots say how many there are and which one you are on.',
        ),
        const SizedBox(height: 44),
        GestureDetector(
          onVerticalDragUpdate: (DragUpdateDetails d) =>
              _at.jumpTo((_at.value - d.delta.dy / _h).clamp(-0.2, n - 0.8)),
          onVerticalDragEnd: (DragEndDetails d) {
            final double v = -(d.primaryVelocity ?? 0) / _h;
            _at.animateTo(
              (_at.value + v * 0.15).round().clamp(0, n - 1).toDouble(),
              velocity: v,
            );
            Haptics.tick();
          },
          child: SizedBox(
            height: _h + 22,
            child: ListenableBuilder(
              listenable: _at,
              builder: (BuildContext context, Widget? _) {
                final double p = _at.value;
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    // Furthest first, so the current one is drawn on top.
                    for (final int i
                        in (<int>[for (int i = 0; i < n; i++) i]..sort(
                          (int a, int b) =>
                              (b - p).abs().compareTo((a - p).abs()),
                        )))
                      Builder(
                        builder: (BuildContext context) {
                          final double d = i - p; // 0 is in front; positive is underneath, negative has gone up
                          final double under = d.clamp(0.0, 3.0),
                              gone = (-d).clamp(0.0, 1.0);
                          return Positioned(
                            left: 14 * under.clamp(0.0, 2.0),
                            right: 34 + 14 * under.clamp(0.0, 2.0),
                            top: 11 * under.clamp(0.0, 2.0) - gone * (_h + 30),
                            height: _h,
                            child: Opacity(
                              opacity:
                                  ((1 - gone) *
                                          (1 - (under - 1.6).clamp(0.0, 1.0)))
                                      .clamp(0.0, 1.0),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: ShapeDecoration(
                                  color: Color.lerp(
                                    _cards[i].$4,
                                    Colors.black,
                                    0.28 * under.clamp(0.0, 2.0),
                                  ),
                                  shape: RoundedSuperellipseBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                    ),
                                  ),
                                  shadows: const <BoxShadow>[
                                    BoxShadow(
                                      color: Color(0x44000000),
                                      blurRadius: 16,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Opacity(
                                  opacity: (1 - under * 1.4).clamp(0.0, 1.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Icon(
                                            _cards[i].$5,
                                            size: 18,
                                            color: Colors.white70,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _cards[i].$1.toUpperCase(),
                                            style: LumenType.label(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(
                                        _cards[i].$2,
                                        style: LumenType.display(
                                          44,
                                          weight: 720,
                                          color: Colors.white,
                                          height: 1.05,
                                        ),
                                      ),
                                      Text(
                                        _cards[i].$3,
                                        style: LumenType.text(
                                          14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    Positioned(
                      right: 8,
                      top: 0,
                      height: _h,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          for (int i = 0; i < n; i++)
                            Container(
                              width: 7,
                              height:
                                  7 + 14 * (1 - (p - i).abs()).clamp(0.0, 1.0),
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              decoration: ShapeDecoration(
                                color: Color.lerp(
                                  c.ink.withValues(alpha: 0.2),
                                  c.ink,
                                  (1 - (p - i).abs()).clamp(0.0, 1.0),
                                ),
                                shape: const StadiumBorder(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SectionLabel(
          'Smart stack',
          detail: 'The stack can turn itself to what matters now. Try the times of day.',
        ),
        Panel(
          child: Column(
            children: <Widget>[
              SwitchLine(
                label: 'Turn by itself',
                value: _smart,
                onChanged: (bool v) => setState(() => _smart = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  for (final (String label, int to) in const <(String, int)>[
                    ('Morning', 1),
                    ('Lunch', 0),
                    ('Evening', 2),
                    ('Night', 3),
                  ])
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _smart
                            ? () {
                                _at.animateTo(to.toDouble());
                                Haptics.tick();
                              }
                            : null,
                        child: Container(
                          height: 44,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: c.ink.withValues(
                              alpha: _smart ? 0.08 : 0.03,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            label,
                            style: LumenType.text(
                              13,
                              weight: 620,
                              color: _smart ? c.ink : c.inkFaint,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
