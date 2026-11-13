import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/room_header.dart';
import '../../widgets/panel.dart';
import '../../widgets/spring_box.dart';

const List<(String, String, Color)> _types = <(String, String, Color)>[
  ('', 'Normal set', Color(0x00000000)),
  ('W', 'Warm-up: not counted', Color(0xFFF5B301)),
  ('D', 'Drop set: less weight, no rest', Color(0xFF9B6BFF)),
  ('F', 'To failure', Color(0xFFE5484D)),
];

class _Ex {
  _Ex(this.id, this.name, this.detail);
  final int id;
  final String name, detail;
  bool skipped = false;
}

/// Room 49. Changing the plan in the middle of a workout: set types, sets
/// added and removed in place, and the queue of what comes next reordered,
/// skipped or linked into supersets.
class SessionRoom extends StatefulWidget {
  const SessionRoom({super.key});

  @override
  State<SessionRoom> createState() => _SessionRoomState();
}

class _SessionRoomState extends State<SessionRoom> {
  static const double _rowH = 68;
  // Current exercise: each set is (id, type index).
  final List<(int, int)> _sets = <(int, int)>[(0, 1), (1, 0), (2, 0)];
  int _nextSet = 3;
  String _hint = 'Tap a set number to change what kind of set it is';

  // What comes next.
  final List<_Ex> _queue = <_Ex>[
    _Ex(0, 'Incline press', '3 sets'),
    _Ex(1, 'Cable fly', '3 sets'),
    _Ex(2, 'Lateral raise', '4 sets'),
    _Ex(3, 'Triceps pushdown', '3 sets'),
  ];
  final Set<int> _linked = <int>{}; // id of the upper exercise of a linked pair
  int? _dragging;
  double _dragTop = 0;

  void _drag(double dy) {
    final int from = _queue.indexWhere((_Ex e) => e.id == _dragging);
    setState(
      () => _dragTop = (_dragTop + dy).clamp(
        -8.0,
        (_queue.length - 1) * _rowH + 8,
      ),
    );
    final int to = ((_dragTop + _rowH / 2) / _rowH).floor().clamp(
      0,
      _queue.length - 1,
    );
    if (to != from) {
      setState(() {
        final _Ex e = _queue.removeAt(from);
        _queue.insert(to, e);
        // Moving things breaks any pairing; saying nothing would be a surprise later.
        _linked.clear();
      });
      Haptics.tick();
    }
  }

  Widget _link(LumenColors c, _Ex e) {
    final bool linked = _linked.contains(e.id);
    return Semantics(
      button: true,
      label: linked ? 'Unlink superset' : 'Link as superset',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => linked ? _linked.remove(e.id) : _linked.add(e.id));
          Haptics.settle();
        },
        child: SizedBox(
          width: 56,
          height: 36,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: linked ? 34 : 28,
              height: linked ? 34 : 28,
              decoration: ShapeDecoration(
                color: linked ? c.accent : c.bg,
                shape: CircleBorder(
                  side: BorderSide(color: linked ? c.accent : c.inkFaint),
                ),
              ),
              child: Icon(
                linked ? Icons.link_rounded : Icons.add_link_rounded,
                size: 17,
                color: linked ? c.onAccent : c.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final double width = MediaQuery.sizeOf(context).width - 32;
    int number = 0;
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 49,
          title: 'Edit mid-workout',
          hint: 'Pattern: plans change at the gym. Every change happens in place, on the thing itself, with no edit mode to enter or leave.',
        ),
        const SectionLabel('Now: bench press'),
        Panel(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 6),
          child: Column(
            children: <Widget>[
              for (final (int id, int type) in _sets)
                TweenAnimationBuilder<double>(
                  key: ValueKey<int>(id),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  builder: (BuildContext context, double t, Widget? child) =>
                      Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.9 + 0.1 * t,
                          child: child,
                        ),
                      ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: <Widget>[
                        // The badge is the control: tap to step through the set types.
                        Semantics(
                          button: true,
                          label: 'Set type: ${_types[type].$2}',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              final int i = _sets.indexWhere(
                                ((int, int) s) => s.$1 == id,
                              );
                              final int t = (type + 1) % _types.length;
                              setState(() {
                                _sets[i] = (id, t);
                                _hint = _types[t].$2;
                              });
                              Haptics.tick();
                            },
                            child: SizedBox(
                              width: 52,
                              height: 52,
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: ShapeDecoration(
                                    color: type == 0
                                        ? c.ink.withValues(alpha: 0.08)
                                        : _types[type].$3.withValues(
                                            alpha: 0.2,
                                          ),
                                    shape: RoundedSuperellipseBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: type == 0
                                            ? Colors.transparent
                                            : _types[type].$3,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    type == 0 ? '${++number}' : _types[type].$1,
                                    textScaler: TextScaler.noScaling,
                                    style: LumenType.text(
                                      15,
                                      weight: 720,
                                      color: type == 0
                                          ? c.ink
                                          : (c.dark ? _types[type].$3 : c.ink),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            type == 1
                                ? '40 kg  ×  10'
                                : (type == 2 ? '60 kg  ×  10' : '80 kg  ×  8'),
                            style: LumenType.text(
                              16,
                              weight: 620,
                              color: c.ink,
                            ),
                          ),
                        ),
                        if (_sets.length > 1)
                          Semantics(
                            button: true,
                            label: 'Remove set',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(
                                  () => _sets.removeWhere(
                                    ((int, int) s) => s.$1 == id,
                                  ),
                                );
                                Haptics.tick();
                              },
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(
                                  Icons.remove_circle_outline_rounded,
                                  size: 22,
                                  color: c.inkFaint,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  // A new set copies the last one, because that is nearly always what is wanted.
                  setState(() => _sets.add((_nextSet++, 0)));
                  Haptics.settle();
                },
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 14),
                      Icon(Icons.add_rounded, size: 20, color: c.accent),
                      const SizedBox(width: 6),
                      Text(
                        'Add a set like the last',
                        style: LumenType.text(
                          14.5,
                          weight: 650,
                          color: c.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Text(
            _hint,
            key: ValueKey<String>(_hint),
            style: LumenType.text(13.5, color: c.inkMuted),
          ),
        ),
        const SectionLabel(
          'Up next',
          detail: 'Drag a handle to reorder. The chain links two into a superset. The arrow skips one for today.',
        ),
        SizedBox(
          height: _queue.length * _rowH,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // Superset brackets, drawn behind the rows they join.
              for (int i = 0; i < _queue.length - 1; i++)
                if (_linked.contains(_queue[i].id) && _dragging == null)
                  Positioned(
                    left: 0,
                    top: i * _rowH + 4,
                    width: width,
                    height: _rowH * 2 - 8,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: c.accent.withValues(alpha: 0.1),
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(26),
                            side: BorderSide(
                              color: c.accent.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              for (final _Ex e in <_Ex>[
                ..._queue.where((_Ex e) => e.id != _dragging),
                ..._queue.where((_Ex e) => e.id == _dragging),
              ])
                Builder(
                  key: ValueKey<int>(e.id),
                  builder: (BuildContext context) {
                    final int i = _queue.indexOf(e);
                    final bool drag = e.id == _dragging;
                    return SpringPositioned(
                      left: 0,
                      top: drag ? _dragTop : i * _rowH,
                      width: width,
                      height: _rowH,
                      spring: drag ? Motions.effectsFast : Motions.expressive,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Positioned.fill(
                            bottom: 8,
                            top: 8,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: e.skipped ? 0.45 : 1,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                padding: const EdgeInsets.only(left: 14),
                                decoration: ShapeDecoration(
                                  color: c.surfaceHigh,
                                  shape: RoundedSuperellipseBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: BorderSide(
                                      color: drag ? c.accent : c.hairline,
                                    ),
                                  ),
                                  shadows: drag
                                      ? <BoxShadow>[
                                          BoxShadow(
                                            color: c.shadow,
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        e.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            LumenType.text(
                                              15.5,
                                              weight: 620,
                                              color: c.ink,
                                            ).copyWith(
                                              decoration: e.skipped
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      e.skipped ? 'skipped' : e.detail,
                                      style: LumenType.text(
                                        13,
                                        color: c.inkMuted,
                                      ),
                                    ),
                                    Semantics(
                                      button: true,
                                      label: e.skipped
                                          ? 'Bring back'
                                          : 'Skip today',
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          setState(() {
                                            e.skipped = !e.skipped;
                                            _linked.remove(e.id);
                                            if (i > 0) {
                                              _linked.remove(_queue[i - 1].id);
                                            }
                                          });
                                          Haptics.tick();
                                        },
                                        child: SizedBox(
                                          width: 44,
                                          height: 48,
                                          child: Icon(
                                            e.skipped
                                                ? Icons.undo_rounded
                                                : Icons.skip_next_rounded,
                                            size: 21,
                                            color: c.inkMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onVerticalDragStart: (_) {
                                        setState(() {
                                          _dragging = e.id;
                                          _dragTop = i * _rowH;
                                        });
                                        Haptics.settle();
                                      },
                                      onVerticalDragUpdate: (
                                        DragUpdateDetails d,
                                      ) => _drag(d.delta.dy),
                                      onVerticalDragEnd: (_) =>
                                          setState(() => _dragging = null),
                                      onVerticalDragCancel: () =>
                                          setState(() => _dragging = null),
                                      child: SizedBox(
                                        width: 46,
                                        height: 52,
                                        child: Icon(
                                          Icons.drag_handle_rounded,
                                          color: drag ? c.accent : c.inkFaint,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              // The link sits on the seam between two rows, above both.
              if (_dragging == null)
                for (int i = 0; i < _queue.length - 1; i++)
                  if (!_queue[i].skipped && !_queue[i + 1].skipped)
                    Positioned(
                      left: width / 2 - 28,
                      top: (i + 1) * _rowH - 18,
                      child: _link(c, _queue[i]),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _linked.isEmpty
              ? 'No supersets'
              : '${_linked.length} superset${_linked.length > 1 ? 's' : ''}: alternate the two exercises, rest after both.',
          style: LumenType.text(13.5, color: c.inkMuted),
        ),
      ],
    );
  }
}
