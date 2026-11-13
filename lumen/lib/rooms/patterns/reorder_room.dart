import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';
import '../../widgets/panel.dart';
import '../../widgets/spring_box.dart';

/// Room 41. Editing a list by hand: drag a row by its handle to move it,
/// swipe it left to remove it, and take the removal back.
class ReorderRoom extends StatefulWidget {
  const ReorderRoom({super.key});

  @override
  State<ReorderRoom> createState() => _ReorderRoomState();
}

class _ReorderRoomState extends State<ReorderRoom> {
  static const double _rowH = 72;
  static const List<(String, String)> _all = <(String, String)>[
    ('Bench press', '4 sets'),
    ('Incline press', '3 sets'),
    ('Cable fly', '3 sets'),
    ('Lateral raise', '4 sets'),
    ('Triceps pushdown', '3 sets'),
  ];
  List<int> _order = <int>[0, 1, 2, 3, 4];
  int? _dragging; // item id
  double _dragTop = 0;
  int? _swiping;
  double _swipe = 0;
  (int id, int index)? _removed;
  Timer? _undoTimer;

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  void _dragUpdate(double dy) {
    final int id = _dragging!;
    setState(
      () => _dragTop = (_dragTop + dy).clamp(
        -10.0,
        (_order.length - 1) * _rowH + 10,
      ),
    );
    final int to = ((_dragTop + _rowH / 2) / _rowH).floor().clamp(
      0,
      _order.length - 1,
    );
    final int from = _order.indexOf(id);
    if (to != from) {
      setState(() {
        _order.removeAt(from);
        _order.insert(to, id);
      });
      Haptics.tick();
    }
  }

  void _remove(int id) {
    final int index = _order.indexOf(id);
    setState(() {
      _order.remove(id);
      _removed = (id, index);
      _swiping = null;
      _swipe = 0;
    });
    Haptics.thud();
    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _removed = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    const Color danger = Color(0xFFE5484D);
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 41,
          title: 'Reorder',
          hint: 'Pattern: edit a list with your hands. Drag the handle on the right to move a row. Swipe a row left to remove it.',
        ),
        const SizedBox(height: 16),
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: _order.length * _rowH,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // The dragged row is listed last so it draws on top.
              for (final int id in <int>[
                ..._order.where((int i) => i != _dragging),
                ?_dragging,
              ])
                Builder(
                  key: ValueKey<int>(id),
                  builder: (BuildContext context) {
                    final bool drag = id == _dragging;
                    final double sw = id == _swiping ? _swipe : 0;
                    return SpringPositioned(
                      left: 0,
                      top: drag ? _dragTop : _order.indexOf(id) * _rowH,
                      width: MediaQuery.sizeOf(context).width - 32,
                      height: _rowH - 8,
                      // The row under the finger follows it closely; the others make way.
                      spring: drag ? Motions.effectsFast : Motions.expressive,
                      child: Stack(
                        children: <Widget>[
                          // What a left swipe uncovers.
                          Positioned.fill(
                            child: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 22),
                              decoration: ShapeDecoration(
                                color: danger.withValues(alpha: sw < 0 ? 1 : 0),
                                shape: RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child: Transform.scale(
                                scale: sw < -96 ? 1.25 : 1,
                                child: Icon(
                                  Icons.delete_rounded,
                                  color: Colors.white.withValues(
                                    alpha: sw < 0 ? 1 : 0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: Duration(
                              milliseconds: id == _swiping ? 0 : 220,
                            ),
                            curve: Curves.easeOutCubic,
                            transform: Matrix4.translationValues(sw, 0, 0),
                            child: GestureDetector(
                              onHorizontalDragStart: (_) => setState(() {
                                _swiping = id;
                                _swipe = 0;
                              }),
                              onHorizontalDragUpdate: (DragUpdateDetails d) {
                                final double before = _swipe;
                                setState(
                                  () => _swipe = (_swipe + d.delta.dx).clamp(
                                    -220.0,
                                    0.0,
                                  ),
                                );
                                // One tick as it crosses the point of no return.
                                if ((before < -96) != (_swipe < -96)) {
                                  Haptics.tick();
                                }
                              },
                              onHorizontalDragEnd: (_) {
                                if (_swipe < -96) {
                                  _remove(id);
                                } else {
                                  setState(() => _swiping = null);
                                }
                              },
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 140),
                                scale: drag ? 1.03 : 1,
                                child: Container(
                                  padding: const EdgeInsets.only(left: 16),
                                  decoration: ShapeDecoration(
                                    color: c.surfaceHigh,
                                    shape: RoundedSuperellipseBorder(
                                      borderRadius: BorderRadius.circular(22),
                                      side: BorderSide(
                                        color: drag
                                            ? c.accent.withValues(alpha: 0.7)
                                            : c.hairline,
                                      ),
                                    ),
                                    shadows: drag
                                        ? <BoxShadow>[
                                            BoxShadow(
                                              color: c.shadow,
                                              blurRadius: 22,
                                              offset: const Offset(0, 10),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: <Widget>[
                                            Text(
                                              _all[id].$1,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: LumenType.text(
                                                16,
                                                weight: 620,
                                                color: c.ink,
                                              ),
                                            ),
                                            Text(
                                              _all[id].$2,
                                              style: LumenType.text(
                                                13,
                                                color: c.inkMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onVerticalDragStart: (_) {
                                          setState(() {
                                            _dragging = id;
                                            _dragTop =
                                                _order.indexOf(id) * _rowH;
                                          });
                                          Haptics.settle();
                                        },
                                        onVerticalDragUpdate: (
                                          DragUpdateDetails d,
                                        ) => _dragUpdate(d.delta.dy),
                                        onVerticalDragEnd: (_) {
                                          setState(() => _dragging = null);
                                          Haptics.settle();
                                        },
                                        onVerticalDragCancel: () =>
                                            setState(() => _dragging = null),
                                        child: Semantics(
                                          label: 'Drag to reorder',
                                          child: SizedBox(
                                            width: 56,
                                            height: _rowH - 8,
                                            child: Icon(
                                              Icons.drag_handle_rounded,
                                              color: drag
                                                  ? c.accent
                                                  : c.inkFaint,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _removed != null
              ? Pressable(
                  key: const ValueKey<int>(1),
                  onTap: () {
                    final (int id, int index) = _removed!;
                    _undoTimer?.cancel();
                    setState(() {
                      _order.insert(index.clamp(0, _order.length), id);
                      _removed = null;
                    });
                    Haptics.settle();
                  },
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: ShapeDecoration(
                      color: c.ink.withValues(alpha: 0.08),
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${_all[_removed!.$1].$1} removed',
                            style: LumenType.text(
                              15,
                              weight: 600,
                              color: c.ink,
                            ),
                          ),
                        ),
                        Text(
                          'Undo',
                          style: LumenType.text(
                            15,
                            weight: 720,
                            color: c.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : (_order.length < _all.length
                    ? Pressable(
                        key: const ValueKey<int>(2),
                        onTap: () =>
                            setState(() => _order = <int>[0, 1, 2, 3, 4]),
                        child: SizedBox(
                          height: 52,
                          child: Center(
                            child: Text(
                              'Restore the list',
                              style: LumenType.text(
                                15,
                                weight: 650,
                                color: c.accent,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(key: ValueKey<int>(3), height: 52)),
        ),
        const SectionLabel(
          'Why this way',
          detail: 'A visible handle means dragging never fights scrolling. The delete colour appears under the row, and Undo replaces an "Are you sure?" question.',
        ),
      ],
    );
  }
}
