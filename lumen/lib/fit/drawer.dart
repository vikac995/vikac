import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../core/haptics.dart';
import '../core/springs.dart';
import '../core/theme.dart';
import 'apps.dart';
import 'diag.dart';

/// The app drawer. It grows out of the centre button: the round button
/// widens and rises into a panel. Inside, the grid never scrolls. A swipe
/// turns the page in place: every tile keeps its squircle, and its colour
/// and mark melt into the next app's, row after row.
class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    required this.open,
    required this.origin,
    required this.button,
    required this.onClose,
  });
  final bool open;
  final Offset origin;
  final double button;
  final VoidCallback onClose;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> with TickerProviderStateMixin {
  late final SpringValue _rise = SpringValue(this, spring: Motions.expressive);
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );
  int _from = 0, _page = 0, _dir = 1, _rows = 5;
  double _pull = 0;
  static const int _cols = 4;

  @override
  void initState() {
    super.initState();
    Apps.instance.addListener(_changed);
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(AppDrawer old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open) {
      _rise.animateTo(
        widget.open ? 1 : 0,
        spring: widget.open ? Motions.expressive : Motions.spatialFast,
      );
      if (widget.open) {
        Apps.instance.refresh();
      }
    }
  }

  @override
  void dispose() {
    Apps.instance.removeListener(_changed);
    _rise.dispose();
    _turn.dispose();
    super.dispose();
  }

  int get _perPage => _rows * _cols;
  int get _pages => math.max(1, (Apps.instance.all.length / _perPage).ceil());

  void _go(int by) {
    final int to = (_page + by).clamp(0, _pages - 1);
    if (to == _page) {
      Haptics.thud();
      return;
    }
    setState(() {
      _from = _page;
      _page = to;
      _dir = by;
    });
    _turn.forward(from: 0);
    Haptics.tick();
    Diag.instance.event('drawer page');
  }

  String get _range {
    final List<AppTile> all = Apps.instance.all;
    if (all.isEmpty) {
      return 'Looking for your apps';
    }
    final int a = _page * _perPage, b = math.min(a + _perPage, all.length) - 1;
    String first(AppTile t) =>
        t.label.isEmpty ? '?' : t.label.substring(0, 1).toUpperCase();
    return '${first(all[a])} to ${first(all[b])}';
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Rect start = Rect.fromCircle(
      center: widget.origin,
      radius: widget.button / 2,
    );
    final Rect panel = Rect.fromLTRB(
      10,
      safe.top + 58,
      screen.width - 10,
      widget.origin.dy - widget.button / 2 - 16,
    );
    // As many rows as fit, so tiles are always the same generous size.
    _rows = math.max(3, ((panel.height - 74) / 104).floor());
    return ListenableBuilder(
      listenable: _rise,
      builder: (BuildContext context, Widget? child) {
        final double g = _rise.value;
        if (g < 0.004) {
          return const SizedBox.shrink();
        }
        final Rect r = Rect.lerp(start, panel, g)!;
        final double show = ((g - 0.6) / 0.4).clamp(0.0, 1.0);
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: ColoredBox(
                  color: Colors.black.withValues(
                    alpha: 0.5 * g.clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: r,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  // The button's colour drains away as it becomes the panel.
                  color: Color.lerp(
                    c.accent,
                    c.surface,
                    (g * 2.2).clamp(0.0, 1.0),
                  ),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(
                      ui.lerpDouble(widget.button / 2, 38, g.clamp(0.0, 1.0))!,
                    ),
                    side: BorderSide(
                      color: c.hairline.withValues(alpha: c.hairline.a * show),
                    ),
                  ),
                ),
                child: show <= 0 ? null : Opacity(opacity: show, child: child),
              ),
            ),
          ],
        );
      },
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: panel.width,
          maxWidth: panel.width,
          minHeight: panel.height,
          maxHeight: panel.height,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 6),
                child: Row(
                  children: <Widget>[
                    Text('Apps', style: LumenType.display(26, color: c.ink)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _range,
                        style: LumenType.text(
                          14,
                          weight: 560,
                          color: c.inkMuted,
                        ),
                      ),
                    ),
                    for (int i = 0; i < _pages; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(left: 5),
                        width: i == _page ? 16 : 6,
                        height: 6,
                        decoration: ShapeDecoration(
                          color: i == _page
                              ? c.accent
                              : c.ink.withValues(alpha: 0.22),
                          shape: const StadiumBorder(),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) =>
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragStart: (_) => _pull = 0,
                        onVerticalDragUpdate: (DragUpdateDetails d) {
                          // No scrolling: every 56 of travel turns one page, so a long swipe turns several.
                          _pull += d.delta.dy;
                          if (_pull.abs() > 56) {
                            _go(_pull < 0 ? 1 : -1);
                            _pull = 0;
                          }
                        },
                        onTapUp: (TapUpDetails d) {
                          final int col =
                              (d.localPosition.dx / (box.maxWidth / _cols))
                                  .floor()
                                  .clamp(0, _cols - 1);
                          final int row =
                              (d.localPosition.dy / (box.maxHeight / _rows))
                                  .floor()
                                  .clamp(0, _rows - 1);
                          final int i = _page * _perPage + row * _cols + col;
                          if (i < Apps.instance.all.length) {
                            Haptics.settle();
                            Diag.instance.event('drawer open app');
                            Apps.instance.launch(Apps.instance.all[i]);
                          }
                        },
                        child: CustomPaint(
                          size: Size(box.maxWidth, box.maxHeight),
                          painter: _GridPainter(
                            apps: Apps.instance.all,
                            from: _from,
                            to: _page,
                            dir: _dir,
                            rows: _rows,
                            cols: _cols,
                            turn: _turn,
                            ink: c.ink,
                          ),
                        ),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The whole grid in one painting pass. Tiles do not move. During a page
/// turn each tile blends from the old app to the new one: the colour slides
/// across, the old mark shrinks away and the new one grows in, and the tile
/// dips slightly as it changes. Rows go one after another in the direction
/// of the swipe.
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.apps,
    required this.from,
    required this.to,
    required this.dir,
    required this.rows,
    required this.cols,
    required this.turn,
    required this.ink,
  }) : super(repaint: turn);
  final List<AppTile> apps;
  final int from, to, dir, rows, cols;
  final Animation<double> turn;
  final Color ink;
  static const double _tile = 68;
  static final Map<String, TextPainter> _labels = <String, TextPainter>{};
  static final Map<String, TextPainter> _letters = <String, TextPainter>{};

  TextPainter _label(AppTile t, double width) => _labels.putIfAbsent(
    '${t.label}|${width.round()}|${ink.toARGB32()}',
    () => TextPainter(
      text: TextSpan(
        text: t.label,
        style: LumenType.text(12.5, weight: 540, color: ink, height: 1.15),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: width - 8),
  );

  void _mark(Canvas canvas, AppTile t, Rect box, double alpha, double scale) {
    if (alpha <= 0) {
      return;
    }
    final Paint p = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..filterQuality = FilterQuality.medium;
    if (t.picture != null) {
      // A picture fills its squircle.
      final ui.Image im = t.picture!;
      canvas.drawImageRect(
        im,
        Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
        box,
        p,
      );
    } else if (t.glyph != null) {
      final ui.Image im = t.glyph!;
      final Rect at = Rect.fromCenter(
        center: box.center,
        width: box.width * 0.62 * scale,
        height: box.height * 0.62 * scale,
      );
      canvas.drawImageRect(
        im,
        Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
        at,
        p,
      );
    } else if (t.label.isNotEmpty) {
      // Not worked out yet, or nothing to show: its first letter.
      final TextPainter tp = _letters.putIfAbsent(
        t.label.substring(0, 1).toUpperCase(),
        () => TextPainter(
          text: TextSpan(
            text: t.label.substring(0, 1).toUpperCase(),
            style: LumenType.display(30, color: Colors.white),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
      canvas
        ..saveLayer(box, Paint()..color = Colors.white.withValues(alpha: alpha))
        ..translate(box.center.dx, box.center.dy)
        ..scale(scale);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double cw = size.width / cols, ch = size.height / rows;
    final int per = rows * cols;
    final double v = turn.value;
    const double rowGap = 0.11, colGap = 0.035, span = 0.46;
    final double last = (rows - 1) * rowGap + (cols - 1) * colGap;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final int i = row * cols + col;
        final int ia = from * per + i, ib = to * per + i;
        final AppTile? a = ia < apps.length ? apps[ia] : null,
            b = ib < apps.length ? apps[ib] : null;
        if (a == null && b == null) {
          continue;
        }
        final double wait =
            (dir > 0 ? row : rows - 1 - row) * rowGap + col * colGap;
        final double t = v >= 1
            ? 1
            : ((v * (last + span) - wait) / span).clamp(0.0, 1.0);
        final double e = Curves.easeInOut.transform(t);
        final Offset centre = Offset(
          cw * (col + 0.5),
          ch * row + 8 + _tile / 2,
        );
        // The tile dips a little while it is between two apps.
        final double dip = 1 - 0.1 * math.sin(math.pi * e);
        final Rect box = Rect.fromCenter(
          center: centre,
          width: _tile * dip,
          height: _tile * dip,
        );
        final Color colour = Color.lerp(
          a?.color ?? b!.color.withValues(alpha: 0),
          b?.color ?? a!.color.withValues(alpha: 0),
          e,
        )!;
        final Path shape = RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(_tile * 0.31),
        ).getOuterPath(box);
        canvas
          ..drawPath(shape, Paint()..color = colour)
          ..save()
          ..clipPath(shape);
        if (a != null) {
          _mark(canvas, a, box, (1 - e * 2).clamp(0.0, 1.0), 1 - 0.3 * e);
        }
        if (b != null) {
          _mark(canvas, b, box, (e * 2 - 1).clamp(0.0, 1.0), 0.7 + 0.3 * e);
        }
        canvas.restore();
        // The names swap at the halfway point.
        final AppTile? named = e < 0.5 ? a : b;
        if (named != null) {
          final TextPainter tp = _label(named, cw);
          final double fade = (e < 0.5 ? 1 - e * 2 : e * 2 - 1).clamp(0.0, 1.0);
          if (fade >= 0.999) {
            tp.paint(
              canvas,
              Offset(centre.dx - tp.width / 2, centre.dy + _tile / 2 + 8),
            );
          } else if (fade > 0.02) {
            final Rect lr = Rect.fromLTWH(
              centre.dx - cw / 2,
              centre.dy + _tile / 2 + 6,
              cw,
              20,
            );
            canvas.saveLayer(
              lr,
              Paint()..color = Colors.white.withValues(alpha: fade),
            );
            tp.paint(
              canvas,
              Offset(centre.dx - tp.width / 2, centre.dy + _tile / 2 + 8),
            );
            canvas.restore();
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => true;
}
