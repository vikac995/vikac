import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/panel.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';
import '../../widgets/spring_box.dart';

const List<(String, String, String, Color, IconData)> _all =
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
      (
        'Water',
        '0.75 l',
        '3 of 8 glasses',
        Color(0xFF2B7FC4),
        Icons.water_drop_rounded,
      ),
      (
        'Next workout',
        'Push day',
        'About 52 min',
        Color(0xFF865AC9),
        Icons.fitness_center_rounded,
      ),
      ('Streak', '4 days', 'Best is 11', Color(0xFFB07A1E), Icons.bolt_rounded),
    ];

/// Room 56. Stacks of widgets: several widgets share one place. One stack
/// turns up and down, the other left and right. Hold a stack to edit it:
/// it unfolds into a list you can reorder, add to and remove from.
class StackRoom extends StatefulWidget {
  const StackRoom({super.key});

  @override
  State<StackRoom> createState() => _StackRoomState();
}

class _StackRoomState extends State<StackRoom> {
  final List<List<int>> _ids = <List<int>>[
    <int>[0, 1, 2, 3],
    <int>[5, 4, 6],
  ];
  final List<bool> _smart = <bool>[true, false];
  int? _editing;

  void _edit(int? i) {
    setState(() => _editing = i);
    i == null ? Haptics.settle() : Haptics.thud();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    Widget slot(int i, Axis axis, String label) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel(label),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _editing == i
              ? _Editor(
                  ids: _ids[i],
                  smart: _smart[i],
                  onChanged: () => setState(() {}),
                  onSmart: (bool v) => setState(() => _smart[i] = v),
                  onDone: () => _edit(null),
                )
              : _Stack(
                  key: ValueKey<int>(i),
                  ids: _ids[i],
                  axis: axis,
                  onEdit: () => _edit(i),
                ),
        ),
      ],
    );
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 56,
          title: 'Widget stacks',
          hint: 'Pattern: several widgets in one place. Swipe the first stack up or down and the second sideways. Hold either one to edit it.',
        ),
        slot(0, Axis.vertical, 'Turns up and down'),
        slot(1, Axis.horizontal, 'Turns sideways'),
        const SizedBox(height: 18),
        Text(
          _editing == null
              ? 'Hold a stack to unfold it.'
              : 'Drag a handle to reorder. The first widget is the one on top.',
          textAlign: TextAlign.center,
          style: LumenType.text(13.5, color: c.inkMuted),
        ),
      ],
    );
  }
}

Widget _face((String, String, String, Color, IconData) w, {double fade = 1}) =>
    Opacity(
      opacity: fade.clamp(0.0, 1.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(w.$5, size: 18, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                w.$1.toUpperCase(),
                style: LumenType.label(color: Colors.white70),
              ),
            ],
          ),
          const Spacer(),
          Text(
            w.$2,
            style: LumenType.display(
              40,
              weight: 720,
              color: Colors.white,
              height: 1.05,
            ),
          ),
          Text(w.$3, style: LumenType.text(14, color: Colors.white70)),
        ],
      ),
    );

/// One stack. The front widget follows the finger along [axis]; the next
/// ones peek out from under it on the far side.
class _Stack extends StatefulWidget {
  const _Stack({
    super.key,
    required this.ids,
    required this.axis,
    required this.onEdit,
  });
  final List<int> ids;
  final Axis axis;
  final VoidCallback onEdit;

  @override
  State<_Stack> createState() => _StackState();
}

class _StackState extends State<_Stack> with SingleTickerProviderStateMixin {
  static const double _h = 158;
  late final SpringValue _at = SpringValue(this, spring: Motions.expressive);
  double _span = 300;

  @override
  void dispose() {
    _at.dispose();
    super.dispose();
  }

  void _drag(double delta) => _at.jumpTo(
    (_at.value - delta / _span).clamp(-0.2, widget.ids.length - 0.8),
  );

  void _end(double velocity) {
    final double v = -velocity / _span;
    _at.animateTo(
      (_at.value + v * 0.15).round().clamp(0, widget.ids.length - 1).toDouble(),
      velocity: v,
    );
    Haptics.tick();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final bool vertical = widget.axis == Axis.vertical;
    final int n = widget.ids.length;
    if (n == 0) {
      return Pressable(
        onTap: widget.onEdit,
        child: Container(
          height: _h,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(30),
              side: BorderSide(color: c.inkFaint),
            ),
          ),
          child: Text(
            'Empty stack. Tap to add widgets.',
            style: LumenType.text(14.5, weight: 600, color: c.inkMuted),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        _span = vertical ? _h : box.maxWidth * 0.8;
        return GestureDetector(
          onLongPress: widget.onEdit,
          onVerticalDragUpdate: vertical
              ? (DragUpdateDetails d) => _drag(d.delta.dy)
              : null,
          onVerticalDragEnd: vertical
              ? (DragEndDetails d) => _end(d.primaryVelocity ?? 0)
              : null,
          onHorizontalDragUpdate: vertical
              ? null
              : (DragUpdateDetails d) => _drag(d.delta.dx),
          onHorizontalDragEnd: vertical
              ? null
              : (DragEndDetails d) => _end(d.primaryVelocity ?? 0),
          child: SizedBox(
            height: _h + (vertical ? 22 : 26),
            child: ListenableBuilder(
              listenable: _at,
              builder: (BuildContext context, Widget? _) {
                final double p = _at.value.clamp(-0.2, n - 0.8);
                final List<int> order = <int>[for (int i = 0; i < n; i++) i]
                  ..sort(
                    (int a, int b) => (b - p).abs().compareTo((a - p).abs()),
                  );
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    for (final int i in order)
                      Builder(
                        builder: (BuildContext context) {
                          final double d = i - p; // 0 in front, positive underneath, negative already turned away
                          final double under = d.clamp(0.0, 2.0),
                              gone = (-d).clamp(0.0, 1.0);
                          final (String, String, String, Color, IconData) w =
                              _all[widget.ids[i]];
                          return Positioned(
                            left: vertical
                                ? 14 * under
                                : 22 * under - gone * (box.maxWidth + 20),
                            right: vertical
                                ? 30 + 14 * under
                                : 30 - 15 * under + gone * (box.maxWidth + 20),
                            top: vertical
                                ? 11 * under - gone * (_h + 30)
                                : 9 * under,
                            height: _h - (vertical ? 0 : 18 * under),
                            child: Opacity(
                              opacity:
                                  ((1 - gone) * (1 - (d - 1.6).clamp(0.0, 1.0)))
                                      .clamp(0.0, 1.0),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: ShapeDecoration(
                                  color: Color.lerp(
                                    w.$4,
                                    Colors.black,
                                    0.28 * under,
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
                                child: _face(w, fade: 1 - under * 1.4),
                              ),
                            ),
                          );
                        },
                      ),
                    // Dots: at the side for up and down, underneath for sideways.
                    Positioned(
                      right: vertical ? 6 : 0,
                      left: vertical ? null : 0,
                      top: vertical ? 0 : null,
                      bottom: vertical ? null : 0,
                      height: vertical ? _h : 12,
                      child: Flex(
                        direction: vertical ? Axis.vertical : Axis.horizontal,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          for (int i = 0; i < n; i++)
                            Builder(
                              builder: (BuildContext context) {
                                final double on = (1 - (p - i).abs()).clamp(
                                  0.0,
                                  1.0,
                                );
                                return Container(
                                  width: vertical ? 7 : 7 + 14 * on,
                                  height: vertical ? 7 + 14 * on : 7,
                                  margin: const EdgeInsets.all(3),
                                  decoration: ShapeDecoration(
                                    color: Color.lerp(
                                      c.ink.withValues(alpha: 0.2),
                                      c.ink,
                                      on,
                                    ),
                                    shape: const StadiumBorder(),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// The stack unfolded for editing: one row per widget, in order.
class _Editor extends StatefulWidget {
  const _Editor({
    required this.ids,
    required this.smart,
    required this.onChanged,
    required this.onSmart,
    required this.onDone,
  });
  final List<int> ids;
  final bool smart;
  final VoidCallback onChanged, onDone;
  final ValueChanged<bool> onSmart;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  static const double _rowH = 64;
  int? _dragging;
  double _dragTop = 0;

  void _drag(double dy) {
    final List<int> ids = widget.ids;
    final int from = ids.indexOf(_dragging!);
    setState(
      () =>
          _dragTop = (_dragTop + dy).clamp(-8.0, (ids.length - 1) * _rowH + 8),
    );
    final int to = ((_dragTop + _rowH / 2) / _rowH).floor().clamp(
      0,
      ids.length - 1,
    );
    if (to != from) {
      ids
        ..removeAt(from)
        ..insert(to, _dragging!);
      widget.onChanged();
      Haptics.tick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final List<int> ids = widget.ids;
    final List<int> spare = <int>[
      for (int i = 0; i < _all.length; i++)
        if (!ids.contains(i)) i,
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: ShapeDecoration(
        color: c.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: c.accent.withValues(alpha: 0.6), width: 1.5),
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: ids.length * _rowH,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  for (final int id in <int>[
                    ...ids.where((int i) => i != _dragging),
                    ?_dragging,
                  ])
                    Builder(
                      key: ValueKey<int>(id),
                      builder: (BuildContext context) {
                        final bool drag = id == _dragging;
                        final (String, String, String, Color, IconData) w =
                            _all[id];
                        return SpringPositioned(
                          left: 0,
                          top: drag ? _dragTop : ids.indexOf(id) * _rowH,
                          width: box.maxWidth,
                          height: _rowH - 8,
                          spring: drag
                              ? Motions.effectsFast
                              : Motions.expressive,
                          child: Container(
                            padding: const EdgeInsets.only(left: 4),
                            decoration: ShapeDecoration(
                              color: w.$4,
                              shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: Colors.white.withValues(
                                    alpha: drag ? 0.8 : 0.14,
                                  ),
                                  width: drag ? 2 : 1,
                                ),
                              ),
                              shadows: drag
                                  ? const <BoxShadow>[
                                      BoxShadow(
                                        color: Color(0x66000000),
                                        blurRadius: 18,
                                        offset: Offset(0, 8),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: <Widget>[
                                Semantics(
                                  button: true,
                                  label: 'Remove ${w.$1}',
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      ids.remove(id);
                                      widget.onChanged();
                                      Haptics.tick();
                                    },
                                    child: const SizedBox(
                                      width: 48,
                                      height: 56,
                                      child: Icon(
                                        Icons.remove_circle_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                Icon(w.$5, color: Colors.white70, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    w.$1,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: LumenType.text(
                                      15.5,
                                      weight: 650,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Text(
                                  w.$2,
                                  style: LumenType.text(
                                    14,
                                    weight: 600,
                                    color: Colors.white70,
                                  ),
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onVerticalDragStart: (_) {
                                    setState(() {
                                      _dragging = id;
                                      _dragTop = ids.indexOf(id) * _rowH;
                                    });
                                    Haptics.settle();
                                  },
                                  onVerticalDragUpdate: (DragUpdateDetails d) =>
                                      _drag(d.delta.dy),
                                  onVerticalDragEnd: (_) =>
                                      setState(() => _dragging = null),
                                  onVerticalDragCancel: () =>
                                      setState(() => _dragging = null),
                                  child: const SizedBox(
                                    width: 52,
                                    height: 56,
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            if (spare.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text('ADD', style: LumenType.label(color: c.inkMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final int id in spare)
                    Pressable(
                      onTap: () {
                        ids.add(id);
                        widget.onChanged();
                        Haptics.settle();
                      },
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.only(left: 10, right: 14),
                        decoration: ShapeDecoration(
                          color: _all[id].$4.withValues(alpha: 0.22),
                          shape: StadiumBorder(
                            side: BorderSide(color: _all[id].$4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.add_rounded, size: 18, color: c.ink),
                            const SizedBox(width: 4),
                            Text(
                              _all[id].$1,
                              style: LumenType.text(
                                13.5,
                                weight: 620,
                                color: c.ink,
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
            const SizedBox(height: 14),
            SwitchLine(
              label: 'Turn by itself through the day',
              value: widget.smart,
              onChanged: widget.onSmart,
            ),
            const SizedBox(height: 14),
            Pressable(
              onTap: widget.onDone,
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: c.accent,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Done',
                  style: LumenType.text(
                    15.5,
                    weight: 700,
                    color: c.onAccent,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
