import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';

/// Room 18. Two touch patterns everyone expects: rows you can swipe away
/// (with a way back), and a bottom sheet that rests at set heights.
class SheetsRoom extends StatefulWidget {
  const SheetsRoom({super.key});

  @override
  State<SheetsRoom> createState() => _SheetsRoomState();
}

class _SheetsRoomState extends State<SheetsRoom> with TickerProviderStateMixin {
  static const List<(String, String)> _all = <(String, String)>[
    ('Harbour café', 'Open until 18:00'),
    ('Tidal flats', 'Low tide at 14:20'),
    ('Print studio', 'Closed today'),
    ('Old lighthouse', '2.1 km away'),
    ('Sunday market', 'Opens 08:00'),
  ];
  final List<int> _items = <int>[0, 1, 2, 3, 4];
  int? _removed;
  int _removedAt = 0;
  Timer? _undoTimer;
  late final SpringValue _toast = SpringValue(this, spring: Motions.expressive);

  // Sheet: height above the bottom, on a spring.
  late final SpringValue _sheet = SpringValue(
    this,
    value: 96,
    spring: Motions.expressive,
    settleDistance: 1,
    settleVelocity: 30,
  );
  List<double> _detents = <double>[96, 340, 620];
  int _detent = 0;

  @override
  void dispose() {
    _undoTimer?.cancel();
    _toast.dispose();
    _sheet.dispose();
    super.dispose();
  }

  void _remove(int id) {
    setState(() {
      _removedAt = _items.indexOf(id);
      _items.remove(id);
      _removed = id;
    });
    Haptics.settle();
    _toast.animateTo(1);
    _undoTimer?.cancel();
    _undoTimer = Timer(
      const Duration(seconds: 4),
      () => _toast.animateTo(0, spring: Motions.spatial),
    );
  }

  void _undo() {
    final int? id = _removed;
    if (id == null) {
      return;
    }
    setState(() {
      _items.insert(math.min(_removedAt, _items.length), id);
      _removed = null;
    });
    _undoTimer?.cancel();
    _toast.animateTo(0, spring: Motions.spatial);
  }

  void _dragSheet(double dy) {
    double h = _sheet.value - dy;
    // Past the last stop the sheet resists.
    final double top = _detents.last, bottom = _detents.first;
    if (h > top) {
      h = _sheet.value - dy * 0.3;
    } else if (h < bottom) {
      h = _sheet.value - dy * 0.3;
    }
    _sheet.jumpTo(h);
  }

  void _releaseSheet(double velocityY) {
    // Where would the throw carry it? Rest at the nearest stop to that.
    final double projected = _sheet.value - velocityY * 0.18;
    int best = 0;
    for (int i = 1; i < _detents.length; i++) {
      if ((_detents[i] - projected).abs() <
          (_detents[best] - projected).abs()) {
        best = i;
      }
    }
    _goTo(best, velocity: -velocityY);
  }

  void _goTo(int i, {double velocity = 0}) {
    final bool changed = i != _detent;
    setState(() => _detent = i);
    _sheet.onSettle = changed ? Haptics.tick : null;
    _sheet.animateTo(_detents[i], velocity: velocity);
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Size screen = MediaQuery.sizeOf(context);
    _detents = <double>[
      96 + safe.bottom,
      screen.height * 0.42,
      screen.height - safe.top - 110,
    ];
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              safe.top + 44,
              16,
              _detents.first + 90,
            ),
            children: <Widget>[
              const RoomHeader(
                number: 18,
                title: 'Sheets',
                hint:
                    'Basics: touch patterns. Swipe a row left to remove it, and note the Undo: '
                    'forgiving beats asking "are you sure?". Then drag the sheet below by its handle, or flick it.',
              ),
              const SizedBox(height: 18),
              for (final int id in _items)
                _SwipeRow(
                  key: ValueKey<int>(id),
                  title: _all[id].$1,
                  detail: _all[id].$2,
                  onRemove: () => _remove(id),
                ),
            ],
          ),
          // Dim the page as the sheet rises over it.
          ListenableBuilder(
            listenable: _sheet,
            builder: (BuildContext context, Widget? _) {
              final double t =
                  ((_sheet.value - _detents[0]) / (_detents[2] - _detents[0]))
                      .clamp(0.0, 1.0);
              return IgnorePointer(
                ignoring: t < 0.05,
                child: GestureDetector(
                  onTap: () => _goTo(0),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.5 * t),
                    child: const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
          // Undo toast.
          ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[_toast, _sheet]),
            builder: (BuildContext context, Widget? child) {
              final double v = _toast.value;
              if (v < 0.01) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: 16,
                right: 16,
                bottom: math.max(0, _sheet.value) + 12,
                child: Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - v)),
                    child: child,
                  ),
                ),
              );
            },
            child: Container(
              height: 52,
              padding: const EdgeInsets.only(left: 18, right: 6),
              decoration: const ShapeDecoration(
                color: Color(0xF21A1C22),
                shape: StadiumBorder(),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Removed',
                      style: LumenType.text(
                        14.5,
                        weight: 560,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Pressable(
                    onTap: _undo,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: const ShapeDecoration(
                        color: Color(0x33FFFFFF),
                        shape: StadiumBorder(),
                      ),
                      child: Text(
                        'Undo',
                        style: LumenType.text(
                          14.5,
                          weight: 660,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // The sheet.
          ListenableBuilder(
            listenable: _sheet,
            builder: (BuildContext context, Widget? child) => Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: math.max(60, _sheet.value) + 40,
              child: Transform.translate(
                offset: const Offset(0, 40),
                child: child,
              ),
            ),
            child: Container(
              decoration: ShapeDecoration(
                color: c.surfaceHigh,
                shape: RoundedSuperellipseBorder(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(34),
                  ),
                  side: BorderSide(color: c.hairline),
                ),
                shadows: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 30,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (DragUpdateDetails d) =>
                        _dragSheet(d.delta.dy),
                    onVerticalDragEnd: (DragEndDetails d) =>
                        _releaseSheet(d.velocity.pixelsPerSecond.dy),
                    onTap: () => _goTo((_detent + 1) % 3),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: ShapeDecoration(
                                color: c.ink.withValues(alpha: 0.25),
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Nearby',
                            style: LumenType.display(
                              24,
                              weight: 700,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            'Three resting heights: peek, half, full',
                            style: LumenType.text(13.5, color: c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        maxHeight: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              for (final (String t, String s) in _all)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 9,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: ShapeDecoration(
                                          color: c.accent.withValues(
                                            alpha: 0.16,
                                          ),
                                          shape: const CircleBorder(),
                                        ),
                                        child: Icon(
                                          Icons.place_rounded,
                                          color: c.accent,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              t,
                                              style: LumenType.text(
                                                15.5,
                                                weight: 620,
                                                color: c.ink,
                                              ),
                                            ),
                                            Text(
                                              s,
                                              style: LumenType.text(
                                                13,
                                                color: c.inkMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeRow extends StatefulWidget {
  const _SwipeRow({
    super.key,
    required this.title,
    required this.detail,
    required this.onRemove,
  });
  final String title;
  final String detail;
  final VoidCallback onRemove;

  @override
  State<_SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<_SwipeRow> with TickerProviderStateMixin {
  late final SpringValue _dx = SpringValue(
    this,
    spring: Motions.expressiveFast,
    settleDistance: 1,
    settleVelocity: 30,
  );
  late final SpringValue _height = SpringValue(
    this,
    value: 1,
    spring: Motions.spatial,
  );
  bool _armed = false;
  double _width = 300;

  @override
  void dispose() {
    _dx.dispose();
    _height.dispose();
    super.dispose();
  }

  void _update(double delta) {
    final double next = math.min(0, _dx.value + delta);
    _dx.jumpTo(next);
    final bool armed = next < -_width * 0.4;
    if (armed != _armed) {
      _armed = armed;
      Haptics.tick();
      setState(() {});
    }
  }

  void _end(double velocity) {
    if (_armed || velocity < -900) {
      // Fly off, then close the gap.
      _dx.onSettle = () {
        _height.onSettle = widget.onRemove;
        _height.animateTo(0);
      };
      _dx.animateTo(-_width - 40, velocity: velocity, spring: Motions.spatial);
    } else {
      _dx.animateTo(0, velocity: velocity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        _width = box.maxWidth;
        return ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[_dx, _height]),
          builder: (BuildContext context, Widget? row) {
            final double reveal = (-_dx.value / (_width * 0.4)).clamp(0.0, 1.0);
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _height.value.clamp(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          decoration: ShapeDecoration(
                            color: Color.lerp(
                              c.ink.withValues(alpha: 0.08),
                              const Color(0xFFE5484D),
                              _armed ? 1 : reveal * 0.5,
                            ),
                            shape: RoundedSuperellipseBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: Transform.scale(
                            scale: 0.7 + 0.3 * reveal + (_armed ? 0.15 : 0),
                            child: const Icon(
                              Icons.delete_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(_dx.value, 0),
                        child: row,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _dx.jumpTo(_dx.value),
            onHorizontalDragUpdate: (DragUpdateDetails d) =>
                _update(d.delta.dx),
            onHorizontalDragEnd: (DragEndDetails d) =>
                _end(d.velocity.pixelsPerSecond.dx),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: ShapeDecoration(
                color: c.surface,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(color: c.hairline),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.title,
                          style: LumenType.text(16, weight: 620, color: c.ink),
                        ),
                        Text(
                          widget.detail,
                          style: LumenType.text(13.5, color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.drag_indicator_rounded,
                    color: c.inkFaint,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
