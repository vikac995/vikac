import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';
import '../../widgets/spring_box.dart';

class _Tile {
  _Tile(this.id, this.title, this.value, this.color, this.w, this.h);
  final int id;
  final String title, value;
  final Color color;
  int w, h; // in grid cells: 2 or 4 wide, 1 or 2 tall
}

const List<(String, String, Color)> _kinds = <(String, String, Color)>[
  ('Steps', '8,214', Color(0xFF4E6CC4)),
  ('Sleep', '7.4 h', Color(0xFF2F978F)),
  ('Water', '1.6 l', Color(0xFF3B9BFF)),
  ('Protein', '104 g', Color(0xFFD0892D)),
  ('Streak', '12 days', Color(0xFFE5484D)),
];

/// Room 33. Widgets on a home grid: long-press one to edit, drag its corner
/// to resize it in whole cells, remove it, add another. Everything else
/// moves out of the way on springs.
class WidgetsRoom extends StatefulWidget {
  const WidgetsRoom({super.key});

  @override
  State<WidgetsRoom> createState() => _WidgetsRoomState();
}

class _WidgetsRoomState extends State<WidgetsRoom>
    with SingleTickerProviderStateMixin {
  static const double _gap = 12, _rowH = 84;
  final List<_Tile> _tiles = <_Tile>[
    _Tile(1, 'Kcal left', '862', const Color(0xFFD16944), 4, 2),
    _Tile(2, 'Weight', '81.8 kg', const Color(0xFF865AC9), 2, 2),
    _Tile(3, 'Steps', '8,214', const Color(0xFF4E6CC4), 2, 1),
    _Tile(4, 'Sleep', '7.4 h', const Color(0xFF2F978F), 2, 1),
  ];
  int _next = 10;
  int? _editing;
  Offset _drag = Offset.zero;
  int _w0 = 2, _h0 = 1;
  bool _picker = false;
  late final SpringValue _edit = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );

  @override
  void dispose() {
    _edit.dispose();
    super.dispose();
  }

  /// Packs tiles left to right, top to bottom, on a four-column grid.
  Map<int, Rect> _layout(double width) {
    final double cell = (width - _gap * 3) / 4;
    final List<List<bool>> used = <List<bool>>[];
    bool free(int x, int y, int w, int h) {
      for (int yy = y; yy < y + h; yy++) {
        while (used.length <= yy) {
          used.add(List<bool>.filled(4, false));
        }
        for (int xx = x; xx < x + w; xx++) {
          if (xx > 3 || used[yy][xx]) {
            return false;
          }
        }
      }
      return true;
    }

    final Map<int, Rect> out = <int, Rect>{};
    for (final _Tile t in _tiles) {
      bool placed = false;
      for (int y = 0; !placed; y++) {
        for (int x = 0; x <= 4 - t.w && !placed; x++) {
          if (free(x, y, t.w, t.h)) {
            for (int yy = y; yy < y + t.h; yy++) {
              for (int xx = x; xx < x + t.w; xx++) {
                used[yy][xx] = true;
              }
            }
            out[t.id] = Rect.fromLTWH(
              x * (cell + _gap),
              y * (_rowH + _gap),
              t.w * cell + (t.w - 1) * _gap,
              t.h * _rowH + (t.h - 1) * _gap,
            );
            placed = true;
          }
        }
      }
    }
    return out;
  }

  void _setEditing(int? id) {
    setState(() {
      _editing = id;
      _picker = false;
    });
    _edit.animateTo(id == null ? 0 : 1);
    if (id != null) {
      Haptics.thud();
    }
  }

  void _resize(_Tile t, Offset delta, double cell) {
    _drag += delta;
    // Whole cells only: the size snaps as the finger crosses half a cell.
    final int w = ((_w0 * cell + _drag.dx) / cell).round() >= 3 ? 4 : 2;
    final int h = ((_h0 * _rowH + _drag.dy) / _rowH).round() >= 2 ? 2 : 1;
    if (w != t.w || h != t.h) {
      setState(() {
        t.w = w;
        t.h = h;
      });
      Haptics.tick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _editing == null ? null : () => _setEditing(null),
        child: ListView(
          physics: _editing == null
              ? const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                )
              : const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 32),
          children: <Widget>[
            const RoomHeader(
              number: 33,
              title: 'Widgets',
              hint:
                  'Pattern: a home made of widgets. Long-press one to edit it. Drag the round handle to resize it in whole '
                  'cells; tap the minus to remove it. Tap empty space to finish.',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                final Map<int, Rect> rects = _layout(box.maxWidth);
                final double cell = (box.maxWidth - _gap * 3) / 4;
                final double height = rects.values.fold<double>(
                  0,
                  (double m, Rect r) => r.bottom > m ? r.bottom : m,
                );
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  height: height + 8,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      for (final _Tile t in _tiles)
                        SpringPositioned(
                          key: ValueKey<int>(t.id),
                          left: rects[t.id]!.left,
                          top: rects[t.id]!.top,
                          width: rects[t.id]!.width,
                          height: rects[t.id]!.height,
                          child: _tileView(c, t, cell),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Pressable(
              onTap: () => setState(() => _picker = !_picker),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: c.accent.withValues(alpha: 0.16),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      _picker ? Icons.close_rounded : Icons.add_rounded,
                      color: c.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _picker ? 'Close' : 'Add a widget',
                      style: LumenType.text(
                        15.5,
                        weight: 650,
                        color: c.accent,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_picker
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          for (final (String title, String value, Color col)
                              in _kinds)
                            Pressable(
                              onTap: () {
                                setState(() {
                                  _tiles.add(
                                    _Tile(_next++, title, value, col, 2, 1),
                                  );
                                  _picker = false;
                                });
                                Haptics.settle();
                              },
                              scale: 0.94,
                              child: Container(
                                width: 104,
                                height: 64,
                                padding: const EdgeInsets.all(10),
                                decoration: ShapeDecoration(
                                  color: col,
                                  shape: RoundedSuperellipseBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      title,
                                      style: LumenType.text(
                                        12,
                                        weight: 600,
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      value,
                                      style: LumenType.text(
                                        15.5,
                                        weight: 700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tileView(LumenColors c, _Tile t, double cell) {
    final bool editing = _editing == t.id;
    return ListenableBuilder(
      listenable: _edit,
      builder: (BuildContext context, Widget? _) {
        final double e = editing ? _edit.value : 0;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                onLongPress: () => _setEditing(t.id),
                onTap: _editing != null
                    ? () => _setEditing(null)
                    : Haptics.tick,
                child: Transform.scale(
                  scale: 1 + 0.03 * e,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.all(14),
                    decoration: ShapeDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Color.lerp(t.color, Colors.white, 0.08)!,
                          t.color,
                        ],
                      ),
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(26),
                        side: BorderSide(
                          color: Colors.white.withValues(
                            alpha: 0.14 + 0.6 * e.clamp(0.0, 1.0),
                          ),
                          width: 1 + e.clamp(0.0, 1.0),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          t.title,
                          maxLines: 1,
                          style: LumenType.text(
                            13,
                            weight: 600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        Text(
                          t.value,
                          maxLines: 1,
                          style: LumenType.display(
                            t.h == 2 ? 34 : 24,
                            weight: 700,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (e > 0.02) ...<Widget>[
              Positioned(
                left: -10,
                top: -10,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _tiles.remove(t));
                    _setEditing(null);
                    Haptics.settle();
                  },
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Transform.scale(
                        scale: e,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const ShapeDecoration(
                            color: Colors.white,
                            shape: CircleBorder(),
                            shadows: <BoxShadow>[
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.remove_rounded,
                            size: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -14,
                bottom: -14,
                child: GestureDetector(
                  onPanStart: (_) {
                    _drag = Offset.zero;
                    _w0 = t.w;
                    _h0 = t.h;
                  },
                  onPanUpdate: (DragUpdateDetails d) =>
                      _resize(t, d.delta, cell + _gap),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Center(
                      child: Transform.scale(
                        scale: e,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: ShapeDecoration(
                            color: c.accent,
                            shape: CircleBorder(
                              side: BorderSide(color: c.bg, width: 3),
                            ),
                          ),
                          child: Icon(
                            Icons.open_in_full_rounded,
                            size: 14,
                            color: c.onAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
