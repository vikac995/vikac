import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

import 'dart:typed_data';

import '../core/haptics.dart';
import '../core/shapes.dart';
import '../core/springs.dart';
import '../core/theme.dart';
import 'apps.dart';
import 'diag.dart';
import 'robot.dart';
import '../widgets/controls.dart';
import '../widgets/panel.dart';

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
    required this.tone,
    required this.onClose,
    this.pick,
    this.pickTitle,
    this.choices = const <(String, String, IconData, Color)>[],
    this.onPick,
  });
  final bool open;
  final Offset origin;
  final double button;

  /// The colour of the button the drawer grows out of.
  final Color tone;
  final VoidCallback onClose;

  /// When the drawer is up to choose what takes a blob's place: that blob's name. The drawer
  /// then says so, offers Prism's own [choices] above the apps (its actions and its pages:
  /// what each is kept as, its name, its mark and its colour), and a tap on anything calls
  /// [onPick] with 'action:2', 'screen:1' or 'app:com.whatsapp' and opens nothing.
  final String? pick;

  /// The two parts of the title while choosing, when it is not a blob being replaced.
  final (String, String)? pickTitle;
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

  // ---- The app list as one list that scrolls.
  final ScrollController _list = ScrollController();
  late final SpringValue _bounce = SpringValue(
    this,
    value: 1,
    spring: Motions.expressiveFast,
  );
  int _bounceAt = -1;
  String _letter = '';

  /// The letters the apps begin with, in order, and the first app for each.
  List<(String, int)> _letters() {
    final List<(String, int)> out = <(String, int)>[];
    final List<AppTile> all = Apps.instance.all;
    for (int i = 0; i < all.length; i++) {
      final String l = all[i].label.isEmpty
          ? '#'
          : all[i].label.substring(0, 1).toUpperCase();
      if (out.isEmpty || out.last.$1 != l) {
        out.add((l, i));
      }
    }
    return out;
  }

  /// A finger on the letters at [y] of [height]: the list goes to that letter's first app,
  /// and that app jumps.
  // While a finger is on the letters: where it is on them, and the letter under it.
  final ValueNotifier<double?> _railY = ValueNotifier<double?>(null);
  String _railLetter = '';
  double _rowH = 100;

  /// The letter at the top of the list as it scrolls, for the heading.
  String _topLetter = '';

  void _listMoved() {
    if (!_list.hasClients || _rowH <= 0) {
      return;
    }
    // The ring follows the finger exactly: no spring to lag behind it.
    final double? share = _listShare();
    if (share != null) {
      _ring.jumpTo(share);
    }
    final List<AppTile> all = Apps.instance.all;
    final int i =
        ((_list.offset / _rowH + 0.7).floor().clamp(0, 1 << 20) * _cols).clamp(
          0,
          math.max(0, all.length - 1),
        );
    final String l = all.isEmpty || all[i].label.isEmpty
        ? ''
        : all[i].label.substring(0, 1).toUpperCase();
    if (l != _topLetter) {
      setState(() => _topLetter = l);
    }
  }

  void _letGoLetters() {
    _letter = '';
    _railLetter = '';
    _railY.value = null;
  }

  void _toLetter(double y, double height, double rowH) {
    final List<(String, int)> ls = _letters();
    if (ls.isEmpty || !_list.hasClients) {
      return;
    }
    final (String l, int i) =
        ls[(y / height * ls.length).floor().clamp(0, ls.length - 1)];
    _railLetter = l;
    _railY.value = y;
    if (l == _letter) {
      return;
    }
    _letter = l;
    Haptics.tick();
    // Exactly on its row: a part of a row at the top showed names with no icons above them.
    _list.jumpTo(
      ((i ~/ _cols) * rowH).clamp(0.0, _list.position.maxScrollExtent),
    );
    setState(() => _bounceAt = i);
    _bounce
      ..jumpTo(1.22)
      ..animateTo(1);
  }

  void _unpress() {
    if (_pressed != -1 && mounted) {
      setState(() => _pressed = -1);
    }
  }

  final int _dir = 1;
  double _pull = 0;

  /// How many apps across, from the density chosen in the app list's settings.
  int get _cols => Apps.instance.cols;

  /// How large a tile is against the usual (4 across), and how tall a row is.
  double get _k => const <double>[1.12, 1, 0.86, 0.74][Apps.instance.density];
  double get _pitch => const <double>[132, 114, 99, 87][Apps.instance.density];

  @override
  void initState() {
    super.initState();
    Apps.instance.addListener(_changed);
    Notes.instance.counts.addListener(_countsChanged);
    _list.addListener(_listMoved);
  }

  void _changed() {
    if (mounted) {
      setState(() {});
      _aim();
    }
  }

  /// A notification came or went. The numbers are on the tiles, which are only there while the
  /// drawer is open: closed, there is nothing to draw again, and nothing is.
  void _countsChanged() {
    if (mounted && widget.open) {
      setState(() {});
    }
  }

  /// Where the ring should be: the share of pages reached, plus a lean while the finger pulls.
  /// In the scrolling list: the share of the list seen so far, the same idea as pages reached.
  void _aim({double lean = 0}) {
    if (Apps.instance.scrolling) {
      final double? s = _listShare();
      if (s != null) {
        _ring.animateTo(s);
      } else {
        // The list is not laid out yet: aim once it is.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final double? s = mounted ? _listShare() : null;
          if (s != null) {
            _ring.animateTo(s);
          }
        });
      }
      return;
    }
    _ring.animateTo(((_page + 1 + lean) / _pages).clamp(0.0, 1.0));
  }

  /// How far the cog in the ring has turned: one tooth (an eighth of a turn) for each row
  /// scrolled past, or for each page, part pages included while a finger pulls.
  double _cogAngle() {
    const double tooth = math.pi / 4;
    if (Apps.instance.scrolling) {
      return _list.hasClients && _rowH > 0 ? _list.offset / _rowH * tooth : 0;
    }
    return (_page + (_toward - _page) * _turn.value) * tooth;
  }

  /// How much of the scrolling list has been seen: the bottom of the screen against its whole length.
  double? _listShare() {
    if (!_list.hasClients) {
      return null;
    }
    final ScrollPosition p = _list.position;
    if (!p.hasContentDimensions || !p.hasViewportDimension) {
      return null;
    }
    final double v = p.viewportDimension;
    return ((p.pixels + v) / (p.maxScrollExtent + v)).clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(AppDrawer old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open && !widget.open) {
      // The app list closing takes its settings panel with it.
      final ModalRoute<Object?>? panel = _choice;
      _choice = null;
      if (panel != null && panel.isActive) {
        Navigator.of(context).removeRoute(panel);
      }
    }
    if (widget.open != old.open) {
      _rise.animateTo(
        widget.open ? 1 : 0,
        spring: widget.open ? Motions.snappy : Motions.spatialFast,
      );
      if (widget.open) {
        Apps.instance.refresh();
        _ring.jumpTo(0);
        _aim();
      }
    }
  }

  /// Opens app [i], or picks it for a blob.
  void _open(int i, Rect tile) {
    final List<AppTile> all = Apps.instance.all;
    if (i >= all.length) {
      return;
    }
    if (widget.onPick != null && widget.pick != null) {
      widget.onPick!('app:${all[i].package}');
      return;
    }
    Diag.instance.event('drawer open app');
    Apps.instance.launch(all[i], from: tile);
  }

  /// The app list as one list that scrolls, row by row, with the letters at the side. Rows are
  /// made only as they come into view, and each is drawn as one picture, as the pages are.
  Widget _scrolled(BuildContext context, BoxConstraints box, LumenColors c) {
    final List<AppTile> all = Apps.instance.all;
    final int rowsAll = (all.length / _cols).ceil();
    final double rowH = box.maxHeight / _rows;
    // The letters take a narrow strip at the side; a finger is taken a little wider than it.
    const double rail = 24, reach = 40;
    final double w = box.maxWidth - rail;
    _rowH = rowH;
    final List<(String, int)> ls = _letters();
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: w,
          // (No scrollbar: it ran down over the letters, and the letters are the scrollbar.)
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(scrollbars: false),
            child: ListView.builder(
              controller: _list,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemExtent: rowH,
              itemCount: rowsAll,
              itemBuilder: (BuildContext context, int r) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (TapUpDetails d) {
                  final int col = (d.localPosition.dx / (w / _cols))
                      .floor()
                      .clamp(0, _cols - 1);
                  final double dpr = MediaQuery.devicePixelRatioOf(context);
                  final Offset centre =
                      d.globalPosition -
                      d.localPosition +
                      Offset(
                        w / _cols * (col + 0.5),
                        (8 + _GridPainter._tile / 2) * _k,
                      );
                  _open(
                    r * _cols + col,
                    Rect.fromCenter(
                      center: centre * dpr,
                      width: _GridPainter._tile * _k * dpr,
                      height: _GridPainter._tile * _k * dpr,
                    ),
                  );
                },
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(w, rowH),
                    painter: _GridPainter(
                      apps: all,
                      from: r,
                      to: r,
                      dir: 0,
                      rows: 1,
                      cols: _cols,
                      k: _k,
                      turn: kAlwaysDismissedAnimation,
                      ink: c.ink.withValues(alpha: 0.84),
                      accent: c.accent,
                      surface: c.surface,
                      counts: Notes.instance.counts.value,
                      pressed: -1,
                      bounceAt: _bounceAt ~/ _cols == r ? _bounceAt : -1,
                      bounce: _bounceAt ~/ _cols == r ? _bounce : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Soft edges: rows fade in at the top and out at the bottom instead of being cut.
        // (Plain shades of the panel's own colour: nothing is blurred.)
        Positioned(
          left: 0,
          top: 0,
          width: w,
          height: 34,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[c.surface, c.surface.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          bottom: 0,
          width: w,
          height: 34,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[c.surface.withValues(alpha: 0), c.surface],
                ),
              ),
            ),
          ),
        ),
        // The letters, the wave and the bubble. Only this part is redrawn while a finger is
        // on the letters; the list is moved, not rebuilt.
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: reach,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints r) => Listener(
              key: Robot.key('letters'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (PointerDownEvent d) =>
                  _toLetter(d.localPosition.dy, r.maxHeight, rowH),
              onPointerMove: (PointerMoveEvent d) =>
                  _toLetter(d.localPosition.dy, r.maxHeight, rowH),
              onPointerUp: (_) => _letGoLetters(),
              onPointerCancel: (_) => _letGoLetters(),
              child: ValueListenableBuilder<double?>(
                valueListenable: _railY,
                builder: (BuildContext context, double? y, Widget? _) {
                  final double h = r.maxHeight;
                  final double step = h / math.max(1, ls.length);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      for (final (int k, (String l, int _)) in ls.indexed)
                        () {
                          // Near the finger the letters swell and lean out, so a thumb can
                          // find one: a wave that follows the finger.
                          final double mid = step * (k + 0.5);
                          final double d = y == null ? 99 : (mid - y) / step;
                          final double near = math.exp(-d * d / 3.2);
                          final bool on = l == _railLetter;
                          return Positioned(
                            right: (rail - 14) / 2 + 22 * near,
                            top: mid - 8,
                            width: 14,
                            height: 16,
                            child: Transform.scale(
                              scale: 1 + 0.75 * near,
                              child: Text(
                                l,
                                textAlign: TextAlign.center,
                                textScaler: TextScaler.noScaling,
                                style: LumenType.text(
                                  11,
                                  weight: on ? 800 : 650,
                                  color: on
                                      ? c.accent
                                      : Color.lerp(c.inkMuted, c.ink, near),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          );
                        }(),
                      // The letter, large, beside the finger: the thumb covers the letters, not this.
                      if (y != null && _railLetter.isNotEmpty)
                        Positioned(
                          right: reach + 26,
                          top: (y - 30).clamp(-20.0, h - 40),
                          width: 60,
                          height: 60,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: c.surfaceHigh,
                              shape: CircleBorder(
                                side: BorderSide(
                                  color: c.accent.withValues(alpha: 0.7),
                                  width: 1.5,
                                ),
                              ),
                              shadows: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x55000000),
                                  blurRadius: 14,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _railLetter,
                                textScaler: TextScaler.noScaling,
                                style: LumenType.display(
                                  30,
                                  weight: 700,
                                  color: c.accent,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // The app list's settings panel while it is open.
  ModalRoute<Object?>? _choice;

  /// The app list's own settings, behind the cog on its first page.
  void _showIconChoice() {
    Haptics.tick();
    // While the density is being dragged, the panel and its shade step aside so the list can be seen.
    final ValueNotifier<bool> clear = ValueNotifier<bool>(false);
    _choice = null;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      // The shade is drawn here, below, so that it can clear with the panel.
      barrierColor: const Color(0x00000000),
      transitionDuration: panelTime,
      transitionBuilder: panelNoFade,
      pageBuilder: (BuildContext context, Animation<double> a, _) {
        final LumenColors c = LumenColors.of(context);
        // (Kept, so that the panel can be closed when the app list is.)
        _choice = ModalRoute.of(context);
        return ValueListenableBuilder<bool>(
          valueListenable: clear,
          builder: (BuildContext context, bool see, Widget? panel) => Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: FadeTransition(
                    opacity: a,
                    child: AnimatedOpacity(
                      opacity: see ? 0 : 1,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      child: const ColoredBox(color: Color(0x66000000)),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                // (The panel clears from the inside: all of it but the slider, which stays as it is.)
                child: panel!,
              ),
            ],
          ),
          child: PanelRise(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                10,
                0,
                10,
                MediaQuery.paddingOf(context).bottom + 10,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: ListenableBuilder(
                  listenable: Listenable.merge(<Listenable>[
                    Apps.instance,
                    clear,
                  ]),
                  builder: (BuildContext context, Widget? _) =>
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.all(20),
                        decoration: ShapeDecoration(
                          // While the density is dragged the panel itself goes clear, and only the slider is left.
                          color: c.surface.withValues(
                            alpha: clear.value ? 0 : c.surface.a,
                          ),
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(36),
                            side: BorderSide(
                              color: c.hairline.withValues(
                                alpha: clear.value ? 0 : c.hairline.a,
                              ),
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            AnimatedOpacity(
                              opacity: clear.value ? 0 : 1,
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOutCubic,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          'Apps',
                                          style: LumenType.display(
                                            22,
                                            weight: 700,
                                            color: c.ink,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          Haptics.tick();
                                          Navigator.of(context).pop();
                                        },
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: ShapeDecoration(
                                            color: c.ink.withValues(alpha: 0.1),
                                            shape: const CircleBorder(),
                                          ),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 24,
                                            color: c.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  // Two choices of two each: the glass segmented picker, as everywhere.
                                  Text(
                                    'Icons',
                                    style: LumenType.text(
                                      15,
                                      weight: 560,
                                      color: c.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Segmented<bool>(
                                    key: Robot.key('prismIcons'),
                                    values: const <bool>[true, false],
                                    labels: const <String>['Prism', 'Regular'],
                                    value: Apps.instance.prismIcons,
                                    onChanged: (bool v) =>
                                        Apps.instance.setPrismIcons(v),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Layout',
                                    style: LumenType.text(
                                      15,
                                      weight: 560,
                                      color: c.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Segmented<bool>(
                                    key: Robot.key('appsScrolling'),
                                    values: const <bool>[false, true],
                                    labels: const <String>['Pages', 'List'],
                                    value: Apps.instance.scrolling,
                                    onChanged: (bool v) {
                                      Apps.instance.setScrolling(v);
                                      // The ring now measures the other way of moving through the list.
                                      _aim();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                // The slider's own ground, there only while the panel is clear.
                                Positioned(
                                  left: -12,
                                  right: -12,
                                  top: -8,
                                  bottom: -2,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    curve: Curves.easeOutCubic,
                                    decoration: ShapeDecoration(
                                      color: c.surface.withValues(
                                        alpha: clear.value ? c.surface.a : 0,
                                      ),
                                      shape: RoundedSuperellipseBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        side: BorderSide(
                                          color: c.hairline.withValues(
                                            alpha: clear.value
                                                ? c.hairline.a
                                                : 0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    Text(
                                      'Density',
                                      style: LumenType.text(
                                        15,
                                        weight: 560,
                                        color: c.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _DensitySlider(
                                      key: Robot.key('appsDensity'),
                                      value: Apps.instance.density,
                                      stops: Apps.columns.length,
                                      onHold: (bool held) => clear.value = held,
                                      onChanged: (int v) {
                                        Apps.instance.setDensity(v);
                                        _aim();
                                      },
                                      onDone: (int v) => Apps.instance
                                          .setDensity(v, save: true),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) => clear.dispose());
  }

  @override
  void dispose() {
    Apps.instance.removeListener(_changed);
    Notes.instance.counts.removeListener(_countsChanged);
    _rise.dispose();
    _ring.dispose();
    _list
      ..removeListener(_listMoved)
      ..dispose();
    _railY.dispose();
    _bounce.dispose();
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
      ((panel.height - 92 - (widget.pick == null ? 0 : 80)) / _pitch).floor(),
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
              // Near the button the whole panel, icons and all, dissolves into it. (Before, the
              // icons were dropped part way and a bare slab went on shrinking: that read as a stutter.)
              // Above that it is fully there and this costs nothing.
              child: Opacity(
                opacity: ((g - 0.05) / 0.25).clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    // The button's colour drains away as it becomes the panel.
                    color: Color.lerp(
                      widget.tone,
                      c.surface,
                      // It stays the panel's colour until it is nearly the button again.
                      ((g - 0.08) / 0.2).clamp(0.0, 1.0),
                    ),
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(
                        ui.lerpDouble(
                          widget.button / 2,
                          38,
                          g.clamp(0.0, 1.0),
                        )!,
                      ),
                      side: BorderSide(
                        color: c.hairline.withValues(
                          alpha: c.hairline.a * show,
                        ),
                      ),
                    ),
                  ),
                  // The contents grow and shrink with the panel, as one piece: the whole grid comes out
                  // of the button and goes back into it. (Before, the grid stayed full size and was cut
                  // off by the panel's edge, which looked broken half-way.) Stretching a finished picture
                  // is nearly free; it is not drawn again.
                  child: g < 0.05
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
                      widget.pick == null
                          ? 'Apps'
                          : (widget.pickTitle?.$1 ??
                                (widget.pick!.isEmpty ? 'Add' : 'Replace')),
                      style: LumenType.display(26, color: c.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.pick == null
                            ? (Apps.instance.scrolling ? _topLetter : _range)
                            : (widget.pickTitle?.$2 ??
                                  (widget.pick!.isEmpty
                                      ? 'a blob'
                                      : widget.pick!)),
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
                    GestureDetector(
                      key: Robot.key('drawerCog'),
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.pick == null ? _showIconChoice : null,
                      child: ListenableBuilder(
                        // The cog turns with the pages and with the list, so those are listened to as well.
                        listenable: Listenable.merge(<Listenable>[
                          _ring,
                          _turn,
                          _list,
                        ]),
                        builder: (BuildContext context, Widget? _) =>
                            CustomPaint(
                              size: const Size(38, 38),
                              painter: _RingPainter(
                                _ring.value,
                                c.accent,
                                c.ink.withValues(alpha: 0.1),
                              ),
                              child: SizedBox(
                                width: 38,
                                height: 38,
                                // A cog, always: the app list's own settings. It turns like a gear rolling
                                // along the list, one tooth for each page or row, exactly as far as the
                                // finger has gone, and stands still when the list does. (While an app is
                                // being chosen for a blob there are no settings: which page this is.)
                                child: Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    transitionBuilder:
                                        (Widget w, Animation<double> a) =>
                                            FadeTransition(
                                              opacity: a,
                                              child: ScaleTransition(
                                                scale: Tween<double>(
                                                  begin: 0.6,
                                                  end: 1,
                                                ).animate(a),
                                                child: w,
                                              ),
                                            ),
                                    child: widget.pick == null
                                        ? Transform.rotate(
                                            key: const ValueKey<String>('cog'),
                                            angle: _cogAngle(),
                                            child: Icon(
                                              Icons.settings_rounded,
                                              size: 18,
                                              color: c.ink,
                                            ),
                                          )
                                        : Text(
                                            '${_page + 1}',
                                            key: ValueKey<int>(_page),
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
                            // (The test's robot finds the first of them by this.)
                            key: key == widget.choices.first.$1
                                ? Robot.key('choice0')
                                : null,
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
                      Apps.instance.scrolling
                      ? _scrolled(context, box, c)
                      // The tile answers the instant a finger lands, before anyone can tell whether it
                      // is a tap or a drag. Waiting to be sure costs a tenth of a second of nothing.
                      : Listener(
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
                            if (_page * _perPage + i <
                                Apps.instance.all.length) {
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
                              final int i =
                                  _page * _perPage + row * _cols + col;
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
                                final double dpr =
                                    MediaQuery.devicePixelRatioOf(context);
                                final Offset origin =
                                    d.globalPosition - d.localPosition;
                                final Offset centre =
                                    origin +
                                    Offset(
                                      box.maxWidth / _cols * (col + 0.5),
                                      box.maxHeight / _rows * row +
                                          (8 + _GridPainter._tile / 2) * _k,
                                    );
                                final Rect tile = Rect.fromCenter(
                                  center: centre * dpr,
                                  width: _GridPainter._tile * _k * dpr,
                                  height: _GridPainter._tile * _k * dpr,
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
                                  k: _k,
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
    this.k = 1,
    required this.turn,
    required this.ink,
    required this.accent,
    required this.surface,
    required this.counts,
    required this.pressed,
    this.bounceAt = -1,
    this.bounce,
  }) : super(
         repaint: bounce == null
             ? turn
             : Listenable.merge(<Listenable>[turn, bounce]),
       );

  /// The app (by its place in [apps]) that bounces, and how far through its bounce it is.
  final int bounceAt;
  final ValueListenable<double>? bounce;

  /// The panel's own colour, and how many notifications each app has.
  final Color surface;
  final Map<String, int> counts;
  final List<AppTile> apps;
  final int from, to, dir, rows, cols;

  /// The tiles' size against the usual one: smaller when more fit across.
  final double k;
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

  TextPainter _label(int i, double width, double k) {
    // Names shrink less than the tiles do, so they stay readable when the list is dense.
    final double f = 0.5 + 0.5 * k;
    final AppTile t = apps[i];
    final bool lead = t.label.isNotEmpty && _starts(i);
    final TextStyle style = LumenType.text(
      14.2 * f,
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
      '${t.label}|${width.round()}|${f.toStringAsFixed(2)}|${ink.toARGB32()}|${lead ? initial.toARGB32() : 0}',
      () => TextPainter(
        text: lead
            ? TextSpan(
                style: style,
                children: <InlineSpan>[
                  TextSpan(
                    text: t.label.substring(0, 1),
                    // Lighter than before but larger than the letters after it: it stands out by size and colour, not by heaviness.
                    style: LumenType.text(
                      16 * f,
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

  /// The app's own icon, when the app list is set to show the apps' own.
  static ui.Image? _own(AppTile? t) => Apps.instance.prismIcons ? null : t?.own;

  void _mark(Canvas canvas, AppTile t, Rect box, double alpha, double scale) {
    if (alpha <= 0) {
      return;
    }
    final Paint p = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..filterQuality = FilterQuality.medium;
    if (_own(t) != null) {
      // The app's own icon, in the tile's shape.
      final ui.Image im = _own(t)!;
      canvas.drawImageRect(
        im,
        Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
        box.inflate(box.width * 0.04),
        p,
      );
    } else if (t.picture != null) {
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
          ..translate(cw * (col + 0.5), ch * row + (8 + _tile / 2) * k)
          ..scale(k);
        if (ia == bounceAt && bounce != null) {
          // Found from the letters at the side: it jumps, once.
          canvas.scale(bounce!.value);
        }
        if (i == pressed && e <= 0) {
          // Pressed: it gives a little and lightens, at once.
          canvas.scale(0.9);
          fill.color = Color.lerp(fill.color, Colors.white, 0.14)!;
        }
        // (An app's own icon is its own colour: the tile under it is not drawn.)
        if (_own(a) == null && _own(b) == null) {
          canvas.drawPath(outline, fill);
        }
        // Only a picture can reach the edge of its tile, so only a picture needs trimming to it.
        if (a?.picture != null ||
            b?.picture != null ||
            _own(a) != null ||
            _own(b) != null) {
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
          ..translate(cw * (col + 0.5), ch * row + (8 + _tile / 2) * k)
          ..scale(k);
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
      final double top = ch * row + (8 + _tile + 5) * k;
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
          final TextPainter tp = _label(i, cw, k);
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
    // The colour deepens as the end comes near: a little darker and well toward its deeper
    // neighbour, so each page is a visible step and the last pages feel like arriving.
    final HSLColor h = HSLColor.fromColor(this.color);
    final Color color = h
        .withLightness((h.lightness * (1 - 0.20 * f)).clamp(0.0, 1.0))
        .withHue((h.hue - 22 * f + 360) % 360)
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

/// The app list's density: a track with a stop for each choice, and a thumb that goes from stop to
/// stop with the finger, with a tick at each. While it is held, [onHold] says so.
class _DensitySlider extends StatefulWidget {
  const _DensitySlider({
    super.key,
    required this.value,
    required this.stops,
    required this.onChanged,
    required this.onHold,
    required this.onDone,
  });
  final int value, stops;
  final ValueChanged<int> onChanged, onDone;
  final ValueChanged<bool> onHold;

  @override
  State<_DensitySlider> createState() => _DensitySliderState();
}

class _DensitySliderState extends State<_DensitySlider>
    with TickerProviderStateMixin {
  late final SpringValue _pos = SpringValue(
    this,
    value: widget.value.toDouble(),
    spring: Motions.spatialFast,
  );
  late final SpringValue _grab = SpringValue(this, spring: Motions.spatialFast);
  late int _at = widget.value;
  double _width = 1;
  static const double _thumb = 26;

  int _stopAt(double dx) =>
      ((dx - _thumb / 2) / (_width - _thumb) * (widget.stops - 1))
          .round()
          .clamp(0, widget.stops - 1);

  void _to(double dx) {
    final int v = _stopAt(dx);
    if (v != _at) {
      _at = v;
      Haptics.tick();
      widget.onChanged(v);
    }
    _pos.animateTo(v.toDouble());
  }

  void _hold(bool on) {
    _grab.animateTo(on ? 1 : 0);
    widget.onHold(on);
    if (!on) {
      widget.onDone(_at);
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    _grab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        _width = box.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // A tap goes to the stop under it, and nothing clears: only a drag is a wish to watch the list.
          onTapUp: (TapUpDetails d) {
            _to(d.localPosition.dx);
            widget.onDone(_at);
          },
          onHorizontalDragStart: (DragStartDetails d) {
            _hold(true);
            _to(d.localPosition.dx);
          },
          onHorizontalDragUpdate: (DragUpdateDetails d) =>
              _to(d.localPosition.dx),
          onHorizontalDragEnd: (_) => _hold(false),
          onHorizontalDragCancel: () => _hold(false),
          child: SizedBox(
            height: 48,
            child: ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[_pos, _grab]),
              builder: (BuildContext context, Widget? _) {
                final double span = _width - _thumb;
                final double x =
                    _thumb / 2 + span * _pos.value / (widget.stops - 1);
                final double size = _thumb + 6 * _grab.value;
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: <Widget>[
                    Positioned(
                      left: _thumb / 2,
                      right: _thumb / 2,
                      child: Container(
                        height: 6,
                        decoration: ShapeDecoration(
                          color: c.ink.withValues(alpha: 0.18),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    // A small dot at each stop, so it is clear there are only a few.
                    for (int i = 0; i < widget.stops; i++)
                      Positioned(
                        left: _thumb / 2 + span * i / (widget.stops - 1) - 3,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: ShapeDecoration(
                            color: c.ink.withValues(alpha: 0.4),
                            shape: const CircleBorder(),
                          ),
                        ),
                      ),
                    Positioned(
                      left: x - size / 2,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: const ShapeDecoration(
                          color: Colors.white,
                          shape: CircleBorder(),
                          shadows: <BoxShadow>[
                            BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
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
