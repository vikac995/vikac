import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/panel.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';
import '../patterns/inputs_room.dart' show NumberStepper;
import '../shapes/shape_loader.dart';

/// Room 25. Every control in one place, each with its id and name printed
/// under it, so a screenshot of any piece identifies itself.
class ComponentsRoom extends StatefulWidget {
  const ComponentsRoom({super.key});

  @override
  State<ComponentsRoom> createState() => _ComponentsRoomState();
}

class _ComponentsRoomState extends State<ComponentsRoom> {
  final Set<String> _filters = <String>{'Strength'};
  bool _switch = true, _check = true;
  int _radio = 0, _seg = 1, _step = 8, _tab = 0;
  double _slider = 0.6;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    Widget spec(String id, String name, Widget child, {double? width}) =>
        SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              child,
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: '$id  ',
                      style: LumenType.text(11, weight: 700, color: c.accent),
                    ),
                    TextSpan(
                      text: name,
                      style: LumenType.text(11, weight: 560, color: c.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    Widget group(String title, List<Widget> kids) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel(title),
        Panel(
          child: Wrap(
            spacing: 14,
            runSpacing: 18,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: kids,
          ),
        ),
      ],
    );
    Widget btn(
      String label, {
      Color? fill,
      Color? ink,
      BorderSide? side,
      IconData? icon,
    }) => Pressable(
      onTap: Haptics.tick,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: ShapeDecoration(
          color: fill,
          shape: StadiumBorder(side: side ?? BorderSide.none),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 18, color: ink),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: LumenType.text(15, weight: 640, color: ink, height: 1),
            ),
          ],
        ),
      ),
    );

    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 25,
          title: 'Components',
          hint:
              'A catalogue. Every piece has an id and a name under it: screenshot one and the picture says what it is. '
              'Everything here works; press things.',
        ),
        group('Buttons', <Widget>[
          spec(
            'C01',
            'Primary button',
            btn('Save', fill: c.accent, ink: c.onAccent),
          ),
          spec(
            'C02',
            'Tonal button',
            btn('Later', fill: c.accent.withValues(alpha: 0.16), ink: c.accent),
          ),
          spec(
            'C03',
            'Outline button',
            btn(
              'Share',
              ink: c.ink,
              side: BorderSide(color: c.inkFaint),
            ),
          ),
          spec('C04', 'Text button', btn('Skip', ink: c.accent)),
          spec(
            'C05',
            'Destructive',
            btn(
              'Delete',
              fill: const Color(0xFFE5484D),
              ink: Colors.white,
              icon: Icons.delete_outline_rounded,
            ),
          ),
          spec(
            'C06',
            'Icon button',
            Pressable(
              onTap: Haptics.tick,
              scale: 0.9,
              child: Container(
                width: 48,
                height: 48,
                decoration: ShapeDecoration(
                  color: c.ink.withValues(alpha: 0.08),
                  shape: const CircleBorder(),
                ),
                child: Icon(
                  Icons.favorite_border_rounded,
                  color: c.ink,
                  size: 22,
                ),
              ),
            ),
          ),
        ]),
        group('Newer button patterns', <Widget>[
          spec(
            'C07',
            'Button group: neighbours give way',
            const _ButtonGroup(),
            width: 300,
          ),
          spec(
            'C08',
            'Split button: action plus menu',
            const _SplitButton(),
            width: 220,
          ),
          spec('C09', 'FAB menu', const _FabMenu(), width: 300),
          spec('C10', 'Floating toolbar', const _Toolbar(), width: 300),
        ]),
        group('Choosing', <Widget>[
          spec(
            'C11',
            'Filter chips',
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final String f in <String>[
                  'Strength',
                  'Cardio',
                  'Mobility',
                ])
                  Pressable(
                    onTap: () => setState(() {
                      _filters.contains(f)
                          ? _filters.remove(f)
                          : _filters.add(f);
                      Haptics.tick();
                    }),
                    scale: 0.94,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: ShapeDecoration(
                        color: _filters.contains(f)
                            ? c.accent.withValues(alpha: 0.18)
                            : Colors.transparent,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: _filters.contains(f) ? c.accent : c.inkFaint,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (_filters.contains(f)) ...<Widget>[
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: c.accent,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            f,
                            style: LumenType.text(
                              13.5,
                              weight: 600,
                              color: _filters.contains(f) ? c.accent : c.ink,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            width: 300,
          ),
          spec(
            'C12',
            'Switch',
            LumenSwitch(
              value: _switch,
              onChanged: (bool v) => setState(() => _switch = v),
            ),
          ),
          spec(
            'C13',
            'Checkbox',
            _Check(
              value: _check,
              round: false,
              onTap: () => setState(() => _check = !_check),
            ),
          ),
          spec(
            'C14',
            'Radio',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < 3; i++)
                  _Check(
                    value: _radio == i,
                    round: true,
                    onTap: () => setState(() => _radio = i),
                  ),
              ],
            ),
          ),
          spec(
            'C15',
            'Segmented picker',
            Segmented<int>(
              values: const <int>[0, 1, 2],
              labels: const <String>['Day', 'Week', 'Month'],
              value: _seg,
              onChanged: (int v) => setState(() => _seg = v),
            ),
            width: 300,
          ),
        ]),
        group('Entering', <Widget>[
          spec(
            'C16',
            'Slider',
            LumenSlider(
              value: _slider,
              onChanged: (double v) => setState(() => _slider = v),
            ),
            width: 300,
          ),
          spec(
            'C17',
            'Stepper',
            NumberStepper(
              value: _step,
              step: 1,
              min: 0,
              max: 99,
              onChanged: (int v) => setState(() => _step = v),
            ),
            width: 150,
          ),
          spec(
            'C18',
            'Search field',
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: ShapeDecoration(
                color: c.ink.withValues(alpha: 0.07),
                shape: const StadiumBorder(),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.search_rounded, size: 20, color: c.inkMuted),
                  const SizedBox(width: 10),
                  Text(
                    'Search exercises',
                    style: LumenType.text(15.5, color: c.inkFaint),
                  ),
                ],
              ),
            ),
            width: 300,
          ),
        ]),
        group('Showing', <Widget>[
          spec(
            'C19',
            'List row',
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: ShapeDecoration(
                    color: c.accent.withValues(alpha: 0.18),
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 20,
                    color: c.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Pull day',
                        style: LumenType.text(15.5, weight: 620, color: c.ink),
                      ),
                      Text(
                        '5 exercises · 62 min',
                        style: LumenType.text(13, color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.inkFaint),
              ],
            ),
            width: 300,
          ),
          spec(
            'C20',
            'Badges and avatar',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF8E7CFF),
                      child: Text(
                        'M',
                        style: LumenType.display(
                          18,
                          weight: 700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2FA84F),
                          shape: BoxShape.circle,
                          border: Border.all(color: c.surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: const ShapeDecoration(
                    color: Color(0xFFE5484D),
                    shape: StadiumBorder(),
                  ),
                  child: Text(
                    '3',
                    style: LumenType.text(
                      12,
                      weight: 700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: ShapeDecoration(
                    color: c.accent.withValues(alpha: 0.18),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'NEW',
                    style: LumenType.text(
                      10.5,
                      weight: 700,
                      color: c.accent,
                      height: 1.2,
                      spacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          spec(
            'C21',
            'Progress: bar, ring, loader',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 110,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.64,
                      minHeight: 8,
                      color: c.accent,
                      backgroundColor: c.accent.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    value: 0.72,
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    color: c.accent,
                    backgroundColor: c.accent.withValues(alpha: 0.18),
                  ),
                ),
                const SizedBox(width: 16),
                ShapeLoader(size: 34, color: c.accent),
              ],
            ),
          ),
          spec(
            'C22',
            'Tabs',
            _Tabs(index: _tab, onChanged: (int i) => setState(() => _tab = i)),
            width: 300,
          ),
          spec(
            'C23',
            'Toast with action',
            Container(
              height: 48,
              padding: const EdgeInsets.only(left: 16, right: 6),
              decoration: const ShapeDecoration(
                color: Color(0xF21A1C22),
                shape: StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Workout saved',
                    style: LumenType.text(14, weight: 560, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: const ShapeDecoration(
                      color: Color(0x33FFFFFF),
                      shape: StadiumBorder(),
                    ),
                    child: Text(
                      'Undo',
                      style: LumenType.text(
                        14,
                        weight: 660,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          spec(
            'C24',
            'Inline banner',
            Container(
              padding: const EdgeInsets.all(12),
              decoration: ShapeDecoration(
                color: const Color(0xFFF5A524).withValues(alpha: 0.14),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: const Color(0xFFF5A524).withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 20,
                    color: Color(0xFFF5A524),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Offline. Changes are saved on this phone.',
                      style: LumenType.text(13.5, weight: 560, color: c.ink),
                    ),
                  ),
                ],
              ),
            ),
            width: 300,
          ),
        ]),
      ],
    );
  }
}

/// Buttons that share one row: the pressed one grows and its neighbours
/// give way; the chosen one turns from a soft square into a pill.
class _ButtonGroup extends StatefulWidget {
  const _ButtonGroup();

  @override
  State<_ButtonGroup> createState() => _ButtonGroupState();
}

class _ButtonGroupState extends State<_ButtonGroup>
    with TickerProviderStateMixin {
  static const List<(IconData, String)> _items = <(IconData, String)>[
    (Icons.directions_run_rounded, 'Run'),
    (Icons.directions_bike_rounded, 'Ride'),
    (Icons.pool_rounded, 'Swim'),
  ];
  int _sel = 0;
  late final List<SpringValue> _press = <SpringValue>[
    for (int i = 0; i < 3; i++)
      SpringValue(this, spring: Motions.expressiveFast),
  ];
  late final List<SpringValue> _on = <SpringValue>[
    for (int i = 0; i < 3; i++)
      SpringValue(this, value: i == 0 ? 1 : 0, spring: Motions.expressiveFast),
  ];

  @override
  void dispose() {
    for (final SpringValue s in <SpringValue>[..._press, ..._on]) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return SizedBox(
      height: 52,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) =>
            ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[..._press, ..._on]),
              builder: (BuildContext context, Widget? _) {
                const double gap = 4;
                final List<double> weight = <double>[
                  for (int i = 0; i < 3; i++) 1 + 0.28 * _press[i].value,
                ];
                final double total = weight.reduce(
                  (double a, double b) => a + b,
                );
                final double usable = box.maxWidth - gap * 2;
                return Row(
                  children: <Widget>[
                    for (int i = 0; i < 3; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: gap),
                      Listener(
                        onPointerDown: (_) =>
                            _press[i].animateTo(1, velocity: 10),
                        onPointerUp: (_) => _press[i].animateTo(0),
                        onPointerCancel: (_) => _press[i].animateTo(0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _sel = i);
                            for (int k = 0; k < 3; k++) {
                              _on[k].animateTo(k == i ? 1 : 0);
                            }
                            Haptics.tick();
                          },
                          child: Container(
                            width: usable * weight[i] / total,
                            height: 52,
                            decoration: ShapeDecoration(
                              color: Color.lerp(
                                c.ink.withValues(alpha: 0.08),
                                c.accent,
                                _on[i].value.clamp(0.0, 1.0),
                              ),
                              shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(
                                  10 + 16 * _on[i].value.clamp(0.0, 1.2),
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  _items[i].$1,
                                  size: 18,
                                  color: _sel == i ? c.onAccent : c.ink,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _items[i].$2,
                                  style: LumenType.text(
                                    14,
                                    weight: 640,
                                    color: _sel == i ? c.onAccent : c.ink,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
      ),
    );
  }
}

/// A main action with a second button that opens related choices.
class _SplitButton extends StatefulWidget {
  const _SplitButton();

  @override
  State<_SplitButton> createState() => _SplitButtonState();
}

class _SplitButtonState extends State<_SplitButton>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  String _action = 'Save';
  late final SpringValue _v = SpringValue(this, spring: Motions.expressiveFast);

  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _v.animateTo(_open ? 1 : 0);
    Haptics.tick();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return ListenableBuilder(
      listenable: _v,
      builder: (BuildContext context, Widget? _) {
        final double v = _v.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Pressable(
                  onTap: Haptics.settle,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: c.accent,
                      shape: const RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(24),
                          right: Radius.circular(6),
                        ),
                      ),
                    ),
                    child: Text(
                      _action,
                      style: LumenType.text(
                        15,
                        weight: 640,
                        color: c.onAccent,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: ShapeDecoration(
                      color: c.accent,
                      // The menu half rounds off as it opens.
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(6 + 18 * v.clamp(0.0, 1.0)),
                          right: const Radius.circular(24),
                        ),
                      ),
                    ),
                    child: Transform.rotate(
                      angle: math.pi * v,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: c.onAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ClipRect(
              child: Align(
                alignment: Alignment.topLeft,
                heightFactor: v.clamp(0.0, 1.0),
                child: Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  width: 200,
                  decoration: ShapeDecoration(
                    color: c.surfaceHigh,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: c.hairline),
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      for (final String a in <String>[
                        'Save',
                        'Save as template',
                        'Save and share',
                      ])
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(
                              () => _action = a.length > 8
                                  ? a
                                        .replaceFirst('Save ', '')
                                        .replaceFirst('as ', 'As ')
                                        .replaceFirst('and ', 'And ')
                                  : a,
                            );
                            _toggle();
                          },
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              a,
                              style: LumenType.text(
                                14.5,
                                weight: 560,
                                color: c.ink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A floating action button that opens into a short list of actions.
class _FabMenu extends StatefulWidget {
  const _FabMenu();

  @override
  State<_FabMenu> createState() => _FabMenuState();
}

class _FabMenuState extends State<_FabMenu> with TickerProviderStateMixin {
  static const List<(IconData, String)> _items = <(IconData, String)>[
    (Icons.fitness_center_rounded, 'Workout'),
    (Icons.restaurant_rounded, 'Meal'),
    (Icons.monitor_weight_outlined, 'Weight'),
  ];
  bool _open = false;
  late final List<SpringValue> _v = <SpringValue>[
    for (int i = 0; i < 4; i++)
      SpringValue(this, spring: Motions.expressiveFast),
  ];
  final List<Timer> _timers = <Timer>[];

  @override
  void dispose() {
    for (final Timer t in _timers) {
      t.cancel();
    }
    for (final SpringValue s in _v) {
      s.dispose();
    }
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _v[3].animateTo(_open ? 1 : 0);
    for (int i = 0; i < 3; i++) {
      if (_open) {
        _timers.add(
          Timer(Duration(milliseconds: 40 * i), () => _v[i].animateTo(1)),
        );
      } else {
        _v[i].animateTo(0, spring: Motions.spatialFast);
      }
    }
    Haptics.tick();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return SizedBox(
      height: 232,
      child: ListenableBuilder(
        listenable: Listenable.merge(_v),
        builder: (BuildContext context, Widget? _) => Stack(
          alignment: Alignment.bottomRight,
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              if (_v[i].value > 0.02)
                Positioned(
                  right: 0,
                  bottom: 66.0 + i * 54 * _v[i].value.clamp(0.0, 1.1),
                  child: Opacity(
                    opacity: _v[i].value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.7 + 0.3 * _v[i].value,
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _toggle,
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: ShapeDecoration(
                            color: c.accent.withValues(alpha: 0.2),
                            shape: const StadiumBorder(),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(_items[i].$1, size: 18, color: c.accent),
                              const SizedBox(width: 8),
                              Text(
                                _items[i].$2,
                                style: LumenType.text(
                                  14.5,
                                  weight: 640,
                                  color: c.accent,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            GestureDetector(
              onTap: _toggle,
              child: Container(
                width: 58,
                height: 58,
                decoration: ShapeDecoration(
                  color: c.accent,
                  // A soft square at rest, a circle when open.
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(
                      18 + 11 * _v[3].value.clamp(0.0, 1.0),
                    ),
                  ),
                ),
                child: Transform.rotate(
                  angle: _v[3].value * math.pi / 4,
                  child: Icon(Icons.add_rounded, size: 28, color: c.onAccent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    Widget ib(IconData i) => Pressable(
      onTap: Haptics.tick,
      scale: 0.88,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(i, size: 22, color: c.ink),
      ),
    );
    return Center(
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: ShapeDecoration(
          color: c.surfaceHigh,
          shape: StadiumBorder(side: BorderSide(color: c.hairline)),
          shadows: <BoxShadow>[
            BoxShadow(
              color: c.shadow,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ib(Icons.undo_rounded),
            ib(Icons.format_bold_rounded),
            Pressable(
              onTap: Haptics.settle,
              scale: 0.9,
              child: Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: ShapeDecoration(
                  color: c.accent,
                  shape: const CircleBorder(),
                ),
                child: Icon(Icons.add_rounded, color: c.onAccent),
              ),
            ),
            ib(Icons.image_outlined),
            ib(Icons.more_horiz_rounded),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatefulWidget {
  const _Check({required this.value, required this.round, required this.onTap});
  final bool value;
  final bool round;
  final VoidCallback onTap;

  @override
  State<_Check> createState() => _CheckState();
}

class _CheckState extends State<_Check> with SingleTickerProviderStateMixin {
  late final SpringValue _v = SpringValue(
    this,
    value: widget.value ? 1 : 0,
    spring: Motions.expressiveFast,
  );

  @override
  void didUpdateWidget(_Check old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _v.animateTo(widget.value ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.onTap();
        Haptics.tick();
      },
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: ListenableBuilder(
            listenable: _v,
            builder: (BuildContext context, Widget? _) {
              final double on = _v.value.clamp(0.0, 1.0);
              return Container(
                width: 26,
                height: 26,
                decoration: ShapeDecoration(
                  color: widget.round
                      ? null
                      : Color.lerp(Colors.transparent, c.accent, on),
                  shape: widget.round
                      ? CircleBorder(
                          side: BorderSide(
                            color: Color.lerp(c.inkFaint, c.accent, on)!,
                            width: 2,
                          ),
                        )
                      : RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Color.lerp(c.inkFaint, c.accent, on)!,
                            width: 2,
                          ),
                        ),
                ),
                child: Transform.scale(
                  scale: _v.value.clamp(0.0, 1.25),
                  child: widget.round
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: c.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : Icon(Icons.check_rounded, size: 18, color: c.onAccent),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatefulWidget {
  const _Tabs({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> with SingleTickerProviderStateMixin {
  late final SpringValue _p = SpringValue(
    this,
    value: widget.index.toDouble(),
    spring: Motions.expressiveFast,
  );

  @override
  void didUpdateWidget(_Tabs old) {
    super.didUpdateWidget(old);
    _p.animateTo(widget.index.toDouble());
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    const List<String> labels = <String>['Overview', 'History', 'Notes'];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double w = box.maxWidth / 3;
        return SizedBox(
          height: 48,
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(height: 1, color: c.hairline),
              ),
              ListenableBuilder(
                listenable: _p,
                builder: (BuildContext context, Widget? _) => Positioned(
                  left: w * _p.value + w * 0.25,
                  width: w * 0.5,
                  bottom: 0,
                  child: Container(
                    height: 3,
                    decoration: ShapeDecoration(
                      color: c.accent,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  for (int i = 0; i < 3; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          widget.onChanged(i);
                          Haptics.tick();
                        },
                        child: Center(
                          child: Text(
                            labels[i],
                            style: LumenType.text(
                              14.5,
                              weight: widget.index == i ? 680 : 520,
                              color: widget.index == i ? c.ink : c.inkMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
