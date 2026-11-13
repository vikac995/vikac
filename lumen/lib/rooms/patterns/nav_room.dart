import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/panel.dart';
import '../../widgets/room_header.dart';
import '../../widgets/spring_box.dart';

const List<(IconData, String)> _tabs = <(IconData, String)>[
  (Icons.home_rounded, 'Home'),
  (Icons.fitness_center_rounded, 'Train'),
  (Icons.bar_chart_rounded, 'Progress'),
  (Icons.person_rounded, 'You'),
];

/// Room 40. Three bottom bars for the same four destinations, so the
/// difference can be pointed at.
class NavRoom extends StatefulWidget {
  const NavRoom({super.key});

  @override
  State<NavRoom> createState() => _NavRoomState();
}

class _NavRoomState extends State<NavRoom> with SingleTickerProviderStateMixin {
  int _a = 0, _b = 1, _c = 2;
  late final SpringValue _plus = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  bool _plusOpen = false;

  @override
  void dispose() {
    _plus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    Widget stage(Widget bar, String page) => Container(
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: c.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: c.hairline),
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 20,
            top: 18,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                page,
                key: ValueKey<String>(page),
                style: LumenType.display(26, weight: 700, color: c.ink),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 62,
            child: Column(
              children: <Widget>[
                for (final double w in <double>[1, 0.7])
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: w,
                      child: Container(
                        height: 10,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: ShapeDecoration(
                          color: c.ink.withValues(alpha: 0.08),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: bar),
        ],
      ),
    );

    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 40,
          title: 'Navigation',
          hint: 'Pattern: the same four places, three bars. Tap the tabs in each and compare how the selection moves.',
        ),
        const SectionLabel(
          'A  Labels and a travelling pill',
          detail: 'The safe default. Every place is named; one pill slides between them.',
        ),
        stage(
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              border: Border(top: BorderSide(color: c.hairline)),
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                final double w = box.maxWidth / 4;
                return Stack(
                  children: <Widget>[
                    SpringPositioned(
                      left: _a * w + (w - 60) / 2,
                      top: 9,
                      width: 60,
                      height: 30,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: c.accent.withValues(alpha: 0.2),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        for (int i = 0; i < 4; i++)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() => _a = i);
                                Haptics.tick();
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    _tabs[i].$1,
                                    size: 22,
                                    color: i == _a ? c.accent : c.inkMuted,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _tabs[i].$2,
                                    textScaler: TextScaler.noScaling,
                                    style: LumenType.text(
                                      11.5,
                                      weight: i == _a ? 700 : 560,
                                      color: i == _a ? c.ink : c.inkMuted,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          _tabs[_a].$2,
        ),
        const SectionLabel(
          'B  Floating bar with one main action',
          detail: 'For apps with one thing you do most. The bar floats; the action sits in the middle.',
        ),
        stage(
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Container(
              height: 60,
              decoration: ShapeDecoration(
                color: c.surfaceHigh,
                shape: StadiumBorder(side: BorderSide(color: c.hairline)),
                shadows: <BoxShadow>[
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < 4; i++) ...<Widget>[
                    if (i == 2)
                      GestureDetector(
                        onTap: () {
                          setState(() => _plusOpen = !_plusOpen);
                          _plus.animateTo(_plusOpen ? 1 : 0);
                          Haptics.settle();
                        },
                        child: ListenableBuilder(
                          listenable: _plus,
                          builder: (BuildContext context, Widget? child) =>
                              Transform.rotate(
                                angle: _plus.value * 0.785,
                                child: Transform.scale(
                                  scale: 1 + 0.08 * _plus.value,
                                  child: child,
                                ),
                              ),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: ShapeDecoration(
                              color: c.accent,
                              shape: const CircleBorder(),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: c.onAccent,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() => _b = i);
                          Haptics.tick();
                        },
                        child: SizedBox(
                          height: 60,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                _tabs[i].$1,
                                size: 24,
                                color: i == _b ? c.ink : c.inkFaint,
                              ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: i == _b ? 5 : 0,
                                height: 5,
                                decoration: ShapeDecoration(
                                  color: c.accent,
                                  shape: const CircleBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _plusOpen ? 'Start a workout' : _tabs[_b].$2,
        ),
        const SectionLabel(
          'C  The selected tab opens its name',
          detail: 'Compact and lively. Only the current place is named, so icons must be obvious.',
        ),
        stage(
          Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              border: Border(top: BorderSide(color: c.hairline)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (int i = 0; i < 4; i++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() => _c = i);
                      Haptics.tick();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      decoration: ShapeDecoration(
                        color: i == _c ? c.accent : Colors.transparent,
                        shape: const StadiumBorder(),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            _tabs[i].$1,
                            size: 22,
                            color: i == _c ? c.onAccent : c.inkMuted,
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            child: i == _c
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 7),
                                    child: Text(
                                      _tabs[i].$2,
                                      textScaler: TextScaler.noScaling,
                                      style: LumenType.text(
                                        13.5,
                                        weight: 680,
                                        color: c.onAccent,
                                        height: 1,
                                      ),
                                    ),
                                  )
                                : const SizedBox(height: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _tabs[_c].$2,
        ),
      ],
    );
  }
}
