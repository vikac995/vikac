import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../core/frame_stats.dart';
import '../../core/glass.dart';
import '../../core/haptics.dart';
import '../../core/settings.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../home/settings_page.dart' show qualityBlurb, qualityName;
import '../../widgets/controls.dart';
import '../../widgets/pressable.dart';
import 'feed.dart';

/// Room 01. Glass lives only on the controls: two round buttons, a tuning
/// panel and a navigation bar whose selection indicator is a draggable lens.
class GlassRoom extends StatefulWidget {
  const GlassRoom({super.key});

  @override
  State<GlassRoom> createState() => _GlassRoomState();
}

class _GlassRoomState extends State<GlassRoom> with TickerProviderStateMixin {
  static const double _barHeight = 68;
  static const double _lensInset = 4;

  int _tab = 0;
  int _settledTab = 0;
  double _material = 0.32; // 0 clear, 1 tinted
  bool _panelOpen = false;
  double _barWidth = 0;
  String? _notice;
  Timer? _noticeTimer;

  /// Which feed is centred, in tab units. Feeds sit side by side and this
  /// slides between them, so the content moves the way the lens moved.
  late final SpringValue _pager = SpringValue(
    this,
    spring: Motions.spatialSlow,
  );

  /// Lens centre, in pixels from the left edge of the bar.
  late final SpringValue _lensX = SpringValue(
    this,
    spring: Motions.expressive,
    settleDistance: 1.2,
    settleVelocity: 40,
  );

  /// 0 resting in the bar, 1 picked up by a finger.
  late final SpringValue _lift = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _panel = SpringValue(
    this,
    spring: Motions.expressiveFast,
    settleDistance: 0.02,
    settleVelocity: 0.3,
  );
  late final SpringValue _noticeIn = SpringValue(
    this,
    spring: Motions.expressive,
  );

  @override
  void initState() {
    super.initState();
    FrameStats.instance.governorEnabled = true;
    FrameStats.instance.lastDrop.addListener(_onTierDrop);
    _panel.addListener(_onPanelTick);
  }

  @override
  void dispose() {
    FrameStats.instance.governorEnabled = false;
    FrameStats.instance.lastDrop.removeListener(_onTierDrop);
    _noticeTimer?.cancel();
    _pager.dispose();
    _lensX.dispose();
    _lift.dispose();
    _panel.dispose();
    _noticeIn.dispose();
    super.dispose();
  }

  // The panel is removed from the tree once it has fully closed.
  bool _panelMounted = false;
  void _onPanelTick() {
    final bool mounted = _panelOpen || _panel.value > 0.02;
    if (mounted != _panelMounted) {
      setState(() => _panelMounted = mounted);
    }
  }

  void _onTierDrop() {
    final GlassQuality? tier = FrameStats.instance.lastDrop.value;
    if (tier == null || !mounted) {
      return;
    }
    setState(
      () => _notice =
          'Frames were missed. Glass lowered to ${qualityName(tier)}.',
    );
    _noticeIn.animateTo(1);
    _noticeTimer?.cancel();
    _noticeTimer = Timer(
      const Duration(seconds: 4),
      () => _noticeIn.animateTo(0, spring: Motions.spatial),
    );
  }

  double get _itemWidth => _barWidth / feeds.length;
  double _centerOf(int i) => _itemWidth * (i + 0.5);

  void _select(int i) {
    setState(() => _tab = i);
    _lensX.onSettle = () {
      // The tick lands when the lens does, and only if it landed somewhere new.
      if (_settledTab != _tab) {
        _settledTab = _tab;
        Haptics.tick();
      }
    };
    _lensX.animateTo(_centerOf(i), spring: Motions.expressive);
    _pager.animateTo(i.toDouble());
  }

  void _dragStart(DragStartDetails d) {
    _lensX.onSettle = null;
    _lift.animateTo(1, velocity: 8);
    _follow(d.localPosition.dx);
  }

  void _follow(double dx) {
    final double half = _itemWidth / 2;
    _lensX.animateTo(
      dx.clamp(half - 6, _barWidth - half + 6),
      spring: Motions.follow,
    );
  }

  void _dragEnd(DragEndDetails d) {
    _lift.animateTo(0);
    // Project where the throw would carry the lens, then land on that tab.
    final double projected =
        _lensX.value + d.velocity.pixelsPerSecond.dx * 0.14;
    final int i = ((projected - _itemWidth / 2) / _itemWidth).round().clamp(
      0,
      feeds.length - 1,
    );
    _select(i);
  }

  void _togglePanel() {
    setState(() => _panelOpen = !_panelOpen);
    _panel.onSettle = Haptics.settle;
    _panel.animateTo(
      _panelOpen ? 1 : 0,
      spring: _panelOpen ? Motions.expressiveFast : Motions.spatialFast,
    );
  }

  GlassStyle _barStyle(LumenColors c) => GlassStyle(
    blur: lerpDouble(7, 22, _material)!,
    tint: lerpDouble(0.05, 0.66, _material)!,
    refraction: 30,
    bevel: 20,
    fallbackColor: c.surfaceHigh,
  );

  GlassStyle _buttonStyle(LumenColors c) => GlassStyle(
    blur: lerpDouble(6, 18, _material)!,
    tint: lerpDouble(0.08, 0.66, _material)!,
    refraction: 18,
    bevel: 14,
    fallbackColor: c.surfaceHigh,
  );

  // Text-heavy floating UI gets the more opaque "regular" material.
  GlassStyle _panelStyle(LumenColors c) => GlassStyle(
    blur: 24,
    tint: lerpDouble(0.52, 0.82, _material)!,
    refraction: 24,
    bevel: 18,
    dispersion: 0.16,
    adapt: 0.3,
    fallbackColor: c.surfaceHigh,
  );

  GlassStyle _lensStyle(LumenColors c) => GlassStyle(
    blur: lerpDouble(0, 3.5, _material)!,
    tint: lerpDouble(0.03, 0.30, _material)!,
    refraction: 22,
    bevel: 13,
    dispersion: 0.2,
    magnify: 1.12,
    light: 0.9,
    saturation: 1.4,
    adapt: 0.42,
    shadow: 0.6,
    fallbackColor: Color.alphaBlend(
      c.accent.withValues(alpha: 0.92),
      c.surfaceHigh,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Size screen = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Content. No glass here.
          ListenableBuilder(
            listenable: _pager,
            builder: (BuildContext context, Widget? _) {
              final double p = _pager.value;
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  for (int i = 0; i < feeds.length; i++)
                    if ((i - p).abs() < 1)
                      Transform.translate(
                        key: ValueKey<int>(i),
                        offset: Offset((i - p) * screen.width, 0),
                        child: Feed(
                          index: i,
                          topInset: safe.top + 84,
                          bottomInset: safe.bottom + 150,
                        ),
                      ),
                ],
              );
            },
          ),

          // Tapping outside the panel closes it.
          if (_panelOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _togglePanel,
              ),
            ),

          Positioned(
            top: safe.top + 8,
            left: 16,
            child: _GlassButton(
              icon: Icons.arrow_back_rounded,
              label: 'Back',
              style: _buttonStyle(c),
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            top: safe.top + 8,
            right: 16,
            child: _GlassButton(
              icon: _panelOpen ? Icons.close_rounded : Icons.tune_rounded,
              label: 'Tune glass',
              style: _buttonStyle(c),
              onTap: _togglePanel,
            ),
          ),

          if (_panelMounted)
            Positioned(
              top: safe.top + 66,
              right: 16,
              width: (screen.width - 32).clamp(0.0, 340.0),
              child: ListenableBuilder(
                listenable: _panel,
                builder: (BuildContext context, Widget? child) {
                  final double v = _panel.value.clamp(0.02, 1.2);
                  return Transform.scale(
                    scale: v,
                    alignment: const Alignment(0.86, -1),
                    child: child,
                  );
                },
                child: Glass(
                  radius: 30,
                  style: _panelStyle(c),
                  child: _panelContent(c),
                ),
              ),
            ),

          // Notice when the governor lowers quality.
          if (_notice != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: safe.bottom + 16 + _barHeight + 14,
              child: IgnorePointer(
                child: ListenableBuilder(
                  listenable: _noticeIn,
                  builder: (BuildContext context, Widget? child) {
                    final double v = _noticeIn.value;
                    return Opacity(
                      opacity: v.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, (1 - v) * 16),
                        child: child,
                      ),
                    );
                  },
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: const ShapeDecoration(
                        color: Color(0xF0101216),
                        shape: StadiumBorder(),
                      ),
                      child: Text(
                        _notice!,
                        style: LumenType.text(
                          13,
                          weight: 560,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            left: 20,
            right: 20,
            bottom: safe.bottom + 16,
            height: _barHeight,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                if (_barWidth != box.maxWidth) {
                  final bool first = _barWidth == 0;
                  _barWidth = box.maxWidth;
                  if (first) {
                    _lensX.jumpTo(_centerOf(_tab));
                  } else {
                    scheduleMicrotask(() => _lensX.jumpTo(_centerOf(_tab)));
                  }
                }
                return _bar(c);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(LumenColors c) {
    return Semantics(
      container: true,
      label: 'Feed, ${feeds[_tab].name} selected',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (TapUpDetails d) {
          _lift.animateTo(0, velocity: 7); // a short swell as the lens leaves
          _select(
            (d.localPosition.dx / _itemWidth).floor().clamp(
              0,
              feeds.length - 1,
            ),
          );
        },
        onHorizontalDragStart: _dragStart,
        onHorizontalDragUpdate: (DragUpdateDetails d) =>
            _follow(d.localPosition.dx),
        onHorizontalDragEnd: _dragEnd,
        onHorizontalDragCancel: () {
          _lift.animateTo(0);
          _select(_tab);
        },
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[_lensX, _lift]),
          builder: (BuildContext context, Widget? _) {
            // Lens geometry: grows when lifted, stretches along its travel
            // and thins to keep its volume.
            final double lift = _lift.value;
            final double stretch = (_lensX.velocity.abs() / 70).clamp(
              0.0,
              28.0,
            );
            final double grow = 1 + 0.16 * lift;
            final double baseW = _itemWidth - _lensInset * 2;
            final double baseH = _barHeight - _lensInset * 2;
            final double w = baseW * grow + stretch;
            final double h = baseH * grow * (1 - stretch / 220);
            final Rect lens = Rect.fromCenter(
              center: Offset(_lensX.value, _barHeight / 2),
              width: w,
              height: h,
            );
            final RRect lensShape = RRect.fromRectAndRadius(
              lens,
              Radius.circular(h / 2),
            );
            final bool solid = settings.reduceTransparency;

            final Path barMinusLens = Path.combine(
              PathOperation.difference,
              Path()..addRRect(
                RRect.fromRectAndRadius(
                  Offset.zero & Size(_barWidth, _barHeight),
                  const Radius.circular(_barHeight / 2),
                ),
              ),
              Path()..addRRect(lensShape),
            );

            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // The bar leaves a hole where the lens is, so the lens looks
                // at the sharp content rather than the bar's blur.
                Positioned.fill(
                  child: Glass(
                    radius: _barHeight / 2,
                    style: _barStyle(c),
                    hole: solid ? null : lensShape.deflate(0.5),
                  ),
                ),
                // Resting labels, hidden under the lens.
                Positioned.fill(
                  child: ClipPath(
                    clipper: _PathClipper(barMinusLens),
                    child: _BarItems(
                      width: _barWidth,
                      color: c.glassInk.withValues(alpha: 0.74),
                      weight: 520,
                    ),
                  ),
                ),
                // The lens, carrying a magnified, brighter copy of the labels.
                Positioned.fromRect(
                  rect: lens,
                  child: Glass(
                    radius: h / 2,
                    style: _lensStyle(c),
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: _barWidth,
                        maxWidth: _barWidth,
                        minHeight: _barHeight,
                        maxHeight: _barHeight,
                        child: Transform.translate(
                          offset: -lens.topLeft,
                          child: Transform.scale(
                            scale: 1.1 + 0.06 * lift,
                            origin:
                                lens.center -
                                Offset(_barWidth / 2, _barHeight / 2),
                            child: _BarItems(
                              width: _barWidth,
                              color: solid ? c.onAccent : c.glassInk,
                              weight: 680,
                            ),
                          ),
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
    );
  }

  Widget _panelContent(LumenColors c) {
    final Color ink = c.glassInk;
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, Widget? _) {
        final GlassQuality q = settings.quality;
        final String blurb = !GlassShaders.available
            ? 'This device cannot run the glass shader, so Low is used.'
            : q == GlassQuality.auto
            ? 'Running ${qualityName(settings.effectiveQuality)}. Steps down if frames are missed.'
            : qualityBlurb(q);
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'MATERIAL',
                style: LumenType.label(color: ink.withValues(alpha: 0.7)),
              ),
              Row(
                children: <Widget>[
                  Text(
                    'Clear',
                    style: LumenType.text(13, weight: 560, color: ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LumenSlider(
                      value: _material,
                      ink: ink,
                      fill: ink,
                      onChanged: (double v) => setState(() => _material = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tinted',
                    style: LumenType.text(13, weight: 560, color: ink),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'QUALITY',
                style: LumenType.label(color: ink.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 2),
              Segmented<GlassQuality>(
                values: GlassQuality.values,
                labels: GlassQuality.values.map(qualityName).toList(),
                value: q,
                ink: ink,
                onGlass: true,
                onChanged: (GlassQuality v) {
                  settings.quality = v;
                  if (v == GlassQuality.auto) {
                    settings.resetAutoTier();
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 2, right: 2),
                child: Text(
                  blurb,
                  style: LumenType.text(
                    12.5,
                    color: ink.withValues(alpha: 0.78),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Solid fallback',
                      style: LumenType.text(14.5, weight: 560, color: ink),
                    ),
                  ),
                  LumenSwitch(
                    value: settings.reduceTransparency,
                    onChanged: (bool v) => settings.reduceTransparency = v,
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

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.style,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final GlassStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        scale: 0.88,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Glass(
            radius: 25,
            style: style,
            child: Icon(icon, size: 22, color: c.glassInk),
          ),
        ),
      ),
    );
  }
}

class _BarItems extends StatelessWidget {
  const _BarItems({
    required this.width,
    required this.color,
    required this.weight,
  });
  final double width;
  final Color color;
  final double weight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: _GlassRoomState._barHeight,
      child: Row(
        children: <Widget>[
          for (final FeedSpec f in feeds)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(f.icon, size: 23, color: color),
                  const SizedBox(height: 3),
                  Text(
                    f.name,
                    style: LumenType.text(
                      11,
                      weight: weight,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PathClipper extends CustomClipper<Path> {
  const _PathClipper(this.path);
  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PathClipper oldClipper) => true;
}
