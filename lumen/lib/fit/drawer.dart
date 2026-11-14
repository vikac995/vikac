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
    this.pick,
    this.choices = const <(String, String, IconData, Color)>[],
    this.onPick,
  });
  final bool open;
  final Offset origin;
  final double button;
  final VoidCallback onClose;

  /// When the drawer is up to choose what takes a blob's place: that blob's name. The drawer
  /// then says so, offers Prism's own [choices] above the apps (its actions and its pages:
  /// what each is kept as, its name, its mark and its colour), and a tap on anything calls
  /// [onPick] with 'action:2', 'screen:1' or 'app:com.whatsapp' and opens nothing.
  final String? pick;
  final List<(String, String, IconData, Color)> choices;
  final void Function(String key)? onPick;

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
  int _page = 0, _rows = 5, _pressed = -1;

  void _unpress() {
    if (_pressed != -1 && mounted) {
      setState(() => _pressed = -1);
    }
  }

  final int _dir = 1;
  double _pull = 0;
  static const int _cols = 4;

  @override
  void initState() {
    super.initState();
    Apps.instance.addListener(_changed);
    Notes.instance.counts.addListener(_changed);
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
    Notes.instance.counts.removeListener(_changed);
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
    _rows = math.max(
      3,
      ((panel.height - 92 - (widget.pick == null ? 0 : 80)) / 114).floor(),
    );
    // Fewer rows fit while Prism's own actions are offered above the apps.
    _page = _page.clamp(0, _pages - 1);
    _toward = _toward.clamp(0, _pages - 1);
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
                // The dim behind it is the shell's, the same one the blobs have.
                child: const SizedBox.expand(),
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
                    // It stays the panel's colour until it is nearly the button again.
                    ((g - 0.08) / 0.2).clamp(0.0, 1.0),
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
                // The contents grow and shrink with the panel, as one piece: the whole grid comes out
                // of the button and goes back into it. (Before, the grid stayed full size and was cut
                // off by the panel's edge, which looked broken half-way.) Stretching a finished picture
                // is nearly free; it is not drawn again.
                child: g < 0.22
                    ? null
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(
                          ui.lerpDouble(
                            widget.button / 2,
                            38,
                            g.clamp(0.0, 1.0),
                          )!,
                        ),
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: SizedBox(
                            width: panel.width,
                            height: panel.height,
                            child: child,
                          ),
                        ),
                      ),
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
                    Text(
                      widget.pick == null ? 'Apps' : 'Replace',
                      style: LumenType.display(26, color: c.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.pick ?? _range,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
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
              if (widget.pick != null)
                // Prism's own actions and pages, offered as round blobs above the apps. There
                // are more than fit, so the row slides sideways; the last one showing is cut
                // short, which says so.
                SizedBox(
                  height: 78,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                    children: <Widget>[
                      for (final (
                            String key,
                            String name,
                            IconData icon,
                            Color color,
                          )
                          in widget.choices)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Haptics.tick();
                            widget.onPick?.call(key);
                          },
                          child: SizedBox(
                            width: 70,
                            child: Column(
                              children: <Widget>[
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: ShapeDecoration(
                                    color: color,
                                    shape: const CircleBorder(),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: color.computeLuminance() > 0.45
                                        ? const Color(0xFF15171C)
                                        : Colors.white,
                                    size: 21,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  name,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.fade,
                                  textScaler: TextScaler.noScaling,
                                  style: LumenType.text(
                                    11.5,
                                    weight: 600,
                                    color: c.ink.withValues(alpha: 0.84),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) =>
                      // The tile answers the instant a finger lands, before anyone can tell whether it
                      // is a tap or a drag. Waiting to be sure costs a tenth of a second of nothing.
                      Listener(
                        onPointerDown: (PointerDownEvent d) {
                          final int col =
                              (d.localPosition.dx / (box.maxWidth / _cols))
                                  .floor()
                                  .clamp(0, _cols - 1);
                          final int row =
                              (d.localPosition.dy / (box.maxHeight / _rows))
                                  .floor()
                                  .clamp(0, _rows - 1);
                          final int i = row * _cols + col;
                          if (_page * _perPage + i < Apps.instance.all.length) {
                            setState(() => _pressed = i);
                            Haptics.tick();
                          }
                        },
                        onPointerUp: (_) => _unpress(),
                        onPointerCancel: (_) => _unpress(),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (_) {
                            _unpress();
                            _settle();
                          },
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
                            if (i < Apps.instance.all.length &&
                                widget.onPick != null &&
                                widget.pick != null) {
                              // Up to choose a blob's replacement: this one is it.
                              widget.onPick!(
                                'app:${Apps.instance.all[i].package}',
                              );
                            } else if (i < Apps.instance.all.length) {
                              Diag.instance.event('drawer open app');
                              // Where the tile is on the glass, in real pixels: the app opens out of it.
                              final double dpr = MediaQuery.devicePixelRatioOf(
                                context,
                              );
                              final Offset origin =
                                  d.globalPosition - d.localPosition;
                              final Offset centre =
                                  origin +
                                  Offset(
                                    box.maxWidth / _cols * (col + 0.5),
                                    box.maxHeight / _rows * row +
                                        8 +
                                        _GridPainter._tile / 2,
                                  );
                              final Rect tile = Rect.fromCenter(
                                center: centre * dpr,
                                width: _GridPainter._tile * dpr,
                                height: _GridPainter._tile * dpr,
                              );
                              Apps.instance.launch(
                                Apps.instance.all[i],
                                from: tile,
                              );
                            }
                          },
                          // Its own layer: opening, closing and the ring never make the grid redraw.
                          child: RepaintBoundary(
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
                                ink: c.ink.withValues(alpha: 0.84),
                                accent: c.accent,
                                surface: c.surface,
                                counts: Notes.instance.counts.value,
                                pressed: _pressed,
                              ),
                            ),
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
    required this.accent,
    required this.surface,
    required this.counts,
    required this.pressed,
  }) : super(repaint: turn);

  /// The panel's own colour, and how many notifications each app has.
  final Color surface;
  final Map<String, int> counts;
  final List<AppTile> apps;
  final int from, to, dir, rows, cols;
  final Animation<double> turn;
  final Color ink, accent;

  /// The tile under a finger that has just landed, or -1.
  final int pressed;
  static const double _tile = 61;
  static final Path _rest = ShapeLib.lerpPath(
    _squircle,
    _squircle,
    0,
    Offset.zero,
    _tile / 2 / _squircle[0],
    0,
  );
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
  // What the squircle leans toward mid-change: a circle of about the same area. Leaning toward
  // a circle only softens the corners, which is the mildest change of shape there is.
  static final Float32List _ripple = Float32List.fromList(
    List<double>.filled(
      ShapeLib.samples,
      _squircle.reduce((double a, double b) => a + b) / _squircle.length,
    ),
  );
  static final Map<String, TextPainter> _labels = <String, TextPainter>{};
  static final Map<String, TextPainter> _letters = <String, TextPainter>{};

  /// The first app of each letter carries its initial in the accent colour, so the
  /// coloured initials down a page read as an index of where each letter starts.
  bool _starts(int i) {
    String first(int k) => apps[k].label.isEmpty
        ? ''
        : apps[k].label.substring(0, 1).toUpperCase();
    return i == 0 || first(i) != first(i - 1);
  }

  TextPainter _label(int i, double width) {
    final AppTile t = apps[i];
    final bool lead = t.label.isNotEmpty && _starts(i);
    final TextStyle style = LumenType.text(
      14.2,
      weight: 570,
      color: ink,
      height: 1.13,
    );
    // The initial takes the app's own tile colour, nudged a little toward the text colour so it
    // stays readable: tile colours are chosen to sit behind white marks, not to be read as text.
    // Same hue as the tile, but brought up to a brightness and strength that reads as text and
    // stands out from the plain names beside it.
    final HSLColor own = HSLColor.fromColor(t.color);
    final bool onDark = ink.computeLuminance() > 0.5;
    final Color initial = own
        .withSaturation((own.saturation * 1.45 + 0.12).clamp(0.0, 1.0))
        .withLightness(onDark ? 0.69 : 0.4)
        .toColor();
    return _labels.putIfAbsent(
      '${t.label}|${width.round()}|${ink.toARGB32()}|${lead ? initial.toARGB32() : 0}',
      () => TextPainter(
        text: lead
            ? TextSpan(
                style: style,
                children: <InlineSpan>[
                  TextSpan(
                    text: t.label.substring(0, 1),
                    // Lighter than before but larger than the letters after it: it stands out by size and colour, not by heaviness.
                    style: LumenType.text(
                      16,
                      weight: 720,
                      color: initial,
                      height: 1.0,
                    ),
                  ),
                  TextSpan(text: t.label.substring(1)),
                ],
              )
            : TextSpan(text: t.label, style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: width - 6),
    );
  }

  static final Map<String, TextPainter> _figures = <String, TextPainter>{};

  /// The small number on an app: how many notifications it has, on the colour opposite the
  /// app's own, with an edge of the panel's colour that cuts it clear of the tile.
  void _badge(Canvas canvas, AppTile t, double alpha) {
    final int n = counts[t.package] ?? 0;
    if (n <= 0 || alpha <= 0.01) {
      return;
    }
    final String text = n > 99 ? '99+' : '$n';
    final TextPainter tp = _figures.putIfAbsent(
      text,
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: LumenType.text(
            11.5,
            weight: 720,
            color: Colors.white,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    const double r = 10.5;
    final double half = math.max(r, tp.width / 2 + 5);
    // Its middle sits on the tile's top right corner, a little way in.
    const Offset at = Offset(_tile / 2 - 5, -_tile / 2 + 5);
    final RRect pill = RRect.fromRectAndRadius(
      Rect.fromLTRB(at.dx - half, at.dy - r, at.dx + half, at.dy + r),
      const Radius.circular(r),
    );
    final bool dim = alpha < 0.999;
    if (dim) {
      canvas.saveLayer(
        pill.outerRect.inflate(4),
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
    canvas
      ..drawRRect(pill.inflate(2.2), Paint()..color = surface)
      ..drawRRect(pill, Paint()..color = Notes.colourFor(t.color, accent));
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    if (dim) {
      canvas.restore();
    }
  }

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
    // Every tile changes together, exactly as far as the finger has gone.
    final double e = turn.value;
    // So one outline serves all of them: worked out once per frame, then moved into place.
    final Path outline = e <= 0
        ? _rest
        : ShapeLib.lerpPath(
            _squircle,
            _ripple,
            // Barely there: the corners soften by about a third and the shape leans a few degrees,
            // then both come back. With twenty tiles doing it together, less is calmer.
            0.3744 * math.sin(math.pi * e),
            Offset.zero,
            _tile / 2 / _squircle[0],
            0.208 * math.sin(math.pi * e),
          );
    double ease(double x) => Curves.easeInOut.transform(x.clamp(0.0, 1.0));
    // The centre never holds two things. The old mark draws in and is gone, the tile is plain
    // colour while its shape changes, and the new mark grows in at the end.
    final double leave = ease(e / 0.4), arrive = ease((e - 0.6) / 0.4);
    const Rect box = Rect.fromLTRB(
      -_tile / 2,
      -_tile / 2,
      _tile / 2,
      _tile / 2,
    );
    final Paint fill = Paint();
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final int i = row * cols + col;
        final int ia = from * per + i, ib = to * per + i;
        final AppTile? a = ia < apps.length ? apps[ia] : null,
            b = ib < apps.length ? apps[ib] : null;
        if (a == null && b == null) {
          continue;
        }
        // The colour goes straight from one to the other. No change in brightness, nothing else.
        fill.color = e <= 0
            ? (a?.color ?? const Color(0x00000000))
            : Color.lerp(
                a?.color ?? b!.color.withValues(alpha: 0),
                b?.color ?? a!.color.withValues(alpha: 0),
                e,
              )!;
        canvas
          ..save()
          ..translate(cw * (col + 0.5), ch * row + 8 + _tile / 2);
        if (i == pressed && e <= 0) {
          // Pressed: it gives a little and lightens, at once.
          canvas.scale(0.9);
          fill.color = Color.lerp(fill.color, Colors.white, 0.14)!;
        }
        canvas.drawPath(outline, fill);
        // Only a picture can reach the edge of its tile, so only a picture needs trimming to it.
        if (a?.picture != null || b?.picture != null) {
          canvas.clipPath(outline);
        }
        if (a != null) {
          _mark(canvas, a, box, 1 - leave, 1 - 0.6 * leave);
        }
        if (b != null && e > 0) {
          _mark(canvas, b, box, arrive, 0.4 + 0.6 * arrive);
        }
        canvas.restore();
        // The numbers go with the marks: the old one out with the old mark, the new one in with the new.
        canvas
          ..save()
          ..translate(cw * (col + 0.5), ch * row + 8 + _tile / 2);
        if (a != null) {
          _badge(canvas, a, 1 - leave);
        }
        if (b != null && e > 0) {
          _badge(canvas, b, arrive);
        }
        canvas.restore();
      }
    }
    // The names. As mild as it can be: a name never vanishes. It dims, changes to the new
    // name at its dimmest, and comes back up. A row of names dims as one, not name by name.
    final double strength = 1 - 0.8 * math.sin(math.pi * e);
    for (int row = 0; row < rows; row++) {
      final double top = ch * row + 8 + _tile + 5;
      final bool dim = strength < 0.999;
      if (dim) {
        canvas.saveLayer(
          Rect.fromLTWH(0, top, size.width, 38),
          Paint()..color = Colors.white.withValues(alpha: strength),
        );
      }
      for (int col = 0; col < cols; col++) {
        final int i = (e < 0.5 ? from : to) * per + row * cols + col;
        if (i < apps.length) {
          final TextPainter tp = _label(i, cw);
          tp.paint(canvas, Offset(cw * (col + 0.5) - tp.width / 2, top + 3));
        }
      }
      if (dim) {
        canvas.restore();
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
    // The colour deepens ever so slightly as the end comes near: a little darker and a touch
    // toward its deeper neighbour, so the last pages feel like arriving.
    final HSLColor h = HSLColor.fromColor(this.color);
    final Color color = h
        .withLightness((h.lightness * (1 - 0.20 * f)).clamp(0.0, 1.0))
        .withHue((h.hue - 9 * f + 360) % 360)
        .toColor();
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
