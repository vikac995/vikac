import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'dart:typed_data';

import '../core/haptics.dart';
import '../core/shapes.dart';
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
    duration: const Duration(milliseconds: 260),
    value: 0,
  );
  late final SpringValue _ring = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  int _page = 0, _rows = 5;
  final int _dir = 1;
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
      _aim();
    }
  }

  /// Where the ring should be: the share of pages reached, plus a lean while the finger pulls.
  void _aim({double lean = 0}) =>
      _ring.animateTo(((_page + 1 + lean) / _pages).clamp(0.0, 1.0));

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
        _ring.jumpTo(0);
        _aim();
      }
    }
  }

  @override
  void dispose() {
    Apps.instance.removeListener(_changed);
    _rise.dispose();
    _ring.dispose();
    _turn.dispose();
    super.dispose();
  }

  int get _perPage => _rows * _cols;
  int get _pages => math.max(1, (Apps.instance.all.length / _perPage).ceil());

  // How far the finger must travel to change one page completely.
  static const double _travel = 120;

  /// The page being morphed toward while a finger is down or the change is finishing. Equal to [_page] at rest.
  int _toward = 0;

  /// The finger moved. The morph follows it exactly: further is more, back is less,
  /// and past the full distance the page is taken and the next one begins.
  void _drag(double by) {
    _turn.stop();
    _pull += by;
    int dir = _pull < 0 ? 1 : -1;
    while (_pull.abs() >= _travel &&
        (_page + dir).clamp(0, _pages - 1) != _page) {
      // A whole page has gone by under the finger.
      _page += dir;
      _pull -= _travel * (_pull < 0 ? -1 : 1);
      Haptics.tick();
      Diag.instance.event('drawer page');
      dir = _pull < 0 ? 1 : -1;
    }
    final int next = (_page + dir).clamp(0, _pages - 1);
    setState(() => _toward = next);
    // At the first or last page there is nothing to morph to: the finger meets no response.
    _turn.value = next == _page ? 0 : (_pull.abs() / _travel).clamp(0.0, 1.0);
    _aim(lean: (next - _page) * _turn.value);
  }

  /// The finger left. Past a third of the way (or with a flick) the change completes; otherwise it goes back.
  void _release(double speed) {
    _pull = 0;
    if (_toward == _page) {
      _turn.value = 0;
      _aim();
      return;
    }
    final bool forward = _toward > _page;
    final bool flick = forward ? speed < -350 : speed > 350;
    if (_turn.value > 0.33 || flick) {
      final int to = _toward;
      _aim(lean: (to - _page).toDouble());
      _turn
          .animateTo(
            1,
            duration: Duration(
              milliseconds: (220 * (1 - _turn.value)).round() + 40,
            ),
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            if (!mounted || _toward != to) {
              return;
            }
            setState(() => _page = to);
            _turn.value = 0;
            _aim();
            Haptics.tick();
            Diag.instance.event('drawer page');
          });
    } else {
      _aim();
      _turn
          .animateTo(
            0,
            duration: Duration(milliseconds: (220 * _turn.value).round() + 40),
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            if (mounted) {
              setState(() => _toward = _page);
            }
          });
    }
  }

  /// A finger came down while a change was still finishing: settle it at once so the new drag starts clean.
  void _settle() {
    if (_turn.isAnimating) {
      _turn.stop();
      if (_turn.value > 0.5) {
        _page = _toward;
      }
    }
    _turn.value = 0;
    setState(() => _toward = _page);
    _pull = 0;
    _aim();
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
    _rows = math.max(3, ((panel.height - 92) / 114).floor());
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
                    // How far through the apps you are: the same ring the rest of Prism uses.
                    ListenableBuilder(
                      listenable: _ring,
                      builder: (BuildContext context, Widget? _) => CustomPaint(
                        size: const Size(38, 38),
                        painter: _RingPainter(
                          _ring.value,
                          c.accent,
                          c.ink.withValues(alpha: 0.1),
                        ),
                        child: SizedBox(
                          width: 38,
                          height: 38,
                          child: Center(
                            child: Text(
                              '${_page + 1}',
                              textScaler: TextScaler.noScaling,
                              style: LumenType.text(
                                13,
                                weight: 700,
                                color: c.ink,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
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
                        onPanStart: (_) => _settle(),
                        // No scrolling. Up or left is forward, down or right is back, whichever way the finger mostly goes.
                        onPanUpdate: (DragUpdateDetails d) => _drag(
                          d.delta.dy.abs() >= d.delta.dx.abs()
                              ? d.delta.dy
                              : d.delta.dx,
                        ),
                        onPanEnd: (DragEndDetails d) {
                          final Offset v = d.velocity.pixelsPerSecond;
                          _release(v.dy.abs() >= v.dx.abs() ? v.dy : v.dx);
                        },
                        onPanCancel: () => _release(0),
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
                            from: _page,
                            to: _toward,
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
  static const double _tile = 61;
  // The squircle from Prism's shape set, and the gently lobed outline it leans toward mid-change.
  // Softer than a standard squircle: fuller corners and less flat side, so a tile sits between
  // the round blobs and the rectangular cards and belongs to both.
  static final Float32List _squircle = Float32List.fromList(<double>[
    for (int i = 0; i < ShapeLib.samples; i++)
      math
          .pow(
            math.pow(math.cos(i / ShapeLib.samples * 2 * math.pi).abs(), 3.1) +
                math.pow(
                  math.sin(i / ShapeLib.samples * 2 * math.pi).abs(),
                  3.1,
                ),
            -1 / 3.1,
          )
          .toDouble(),
  ]);
  // A cookie with fewer, softer waves than the one in the Shape morph room: six shallow lobes.
  static final Float32List _ripple = Float32List.fromList(<double>[
    for (int i = 0; i < ShapeLib.samples; i++)
      0.98 * (1 + 0.052 * math.cos(6 * i / ShapeLib.samples * 2 * math.pi)),
  ]);
  static final Map<String, TextPainter> _labels = <String, TextPainter>{};
  static final Map<String, TextPainter> _letters = <String, TextPainter>{};

  TextPainter _label(AppTile t, double width) => _labels.putIfAbsent(
    '${t.label}|${width.round()}|${ink.toARGB32()}',
    () => TextPainter(
      text: TextSpan(
        text: t.label,
        style: LumenType.text(13.5, weight: 660, color: ink, height: 1.14),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: width - 6),
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
        width: box.width * 0.6 * scale,
        height: box.height * 0.6 * scale,
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
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final int i = row * cols + col;
        final int ia = from * per + i, ib = to * per + i;
        final AppTile? a = ia < apps.length ? apps[ia] : null,
            b = ib < apps.length ? apps[ib] : null;
        if (a == null && b == null) {
          continue;
        }
        // Every tile changes together, exactly as far as the finger has gone.
        final double e = v;
        final Offset centre = Offset(
          cw * (col + 0.5),
          ch * row + 8 + _tile / 2,
        );
        // The colour goes straight from one to the other. No change in brightness, nothing else.
        final Color colour = Color.lerp(
          a?.color ?? b!.color.withValues(alpha: 0),
          b?.color ?? a!.color.withValues(alpha: 0),
          e,
        )!;
        // Nothing disappears. The squircle's outline ripples a little while its colour slides
        // across (the same shape morph as elsewhere in Prism), and settles back to a squircle.
        final Rect box = Rect.fromCenter(
          center: centre,
          width: _tile,
          height: _tile,
        );
        final Path shape = ShapeLib.lerpPath(
          _squircle,
          _ripple,
          math.sin(math.pi * e),
          centre,
          _tile / 2 / _squircle[0],
          0,
        );
        canvas
          ..drawPath(shape, Paint()..color = colour)
          ..save()
          ..clipPath(shape);
        // The marks dissolve one into the other in place, at full size.
        if (a != null) {
          _mark(canvas, a, box, 1 - e, 1);
        }
        if (b != null) {
          _mark(canvas, b, box, e, 1);
        }
        canvas.restore();
        // So do the names.
        void name(AppTile? t, double alpha) {
          if (t == null || alpha <= 0.02) {
            return;
          }
          final TextPainter tp = _label(t, cw);
          final Offset at = Offset(
            centre.dx - tp.width / 2,
            centre.dy + _tile / 2 + 8,
          );
          if (alpha >= 0.999) {
            tp.paint(canvas, at);
          } else {
            canvas.saveLayer(
              Rect.fromLTWH(
                centre.dx - cw / 2,
                centre.dy + _tile / 2 + 5,
                cw,
                38,
              ),
              Paint()..color = Colors.white.withValues(alpha: alpha),
            );
            tp.paint(canvas, at);
            canvas.restore();
          }
        }

        if (a?.label == b?.label) {
          name(b, 1);
        } else {
          // Each name is mostly gone before the other is mostly there, so two names are never both readable.
          name(a, 1 - Curves.easeInOut.transform((e / 0.62).clamp(0.0, 1.0)));
          name(
            b,
            Curves.easeInOut.transform(((e - 0.38) / 0.62).clamp(0.0, 1.0)),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => true;
}

/// Prism's ring: a track and a round-ended arc from the top, which fades out as it empties.
class _RingPainter extends CustomPainter {
  const _RingPainter(this.v, this.color, this.track);
  final double v;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = (Offset.zero & size).deflate(3);
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    final double f = v.clamp(0.0, 1.0);
    if (f > 0.0005) {
      canvas.drawArc(
        r,
        -math.pi / 2,
        math.pi * 2 * f,
        false,
        p
          ..color = color.withValues(
            alpha: color.a * (f / 0.03).clamp(0.0, 1.0),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.color != color;
}
