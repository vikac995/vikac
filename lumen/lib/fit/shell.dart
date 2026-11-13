import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../core/glass.dart';
import '../core/haptics.dart';
import '../core/settings.dart';
import '../core/springs.dart';
import '../core/theme.dart';
import '../rooms/patterns/inputs_room.dart';
import '../widgets/controls.dart';
import '../widgets/panel.dart';
import '../widgets/pressable.dart';
import 'food_page.dart';
import 'home_page.dart';
import 'progress_page.dart';
import 'state.dart';
import 'train_page.dart';

const List<(IconData, String)> _tabs = <(IconData, String)>[
  (Icons.home_rounded, 'Home'),
  (Icons.fitness_center_rounded, 'Train'),
  (Icons.restaurant_rounded, 'Food'),
  (Icons.show_chart_rounded, 'Progress'),
];
const List<(String, IconData, Color)> _actions = <(String, IconData, Color)>[
  ('Workout', Icons.fitness_center_rounded, Color(0xFF865AC9)),
  ('Log food', Icons.restaurant_rounded, Color(0xFFD16944)),
  ('Scan', Icons.qr_code_scanner_rounded, Color(0xFF2F978F)),
  ('Weigh-in', Icons.monitor_weight_outlined, Color(0xFF4E6CC4)),
  ('Timer', Icons.timer_outlined, Color(0xFFD0892D)),
];

/// Prism's frame: a wallpaper, four pages, and the only glass that is always
/// on screen, the bar at the bottom with a lens that rides between its tabs.
/// Glass is kept for things that float over content: the bar, the lens, the
/// round buttons at the top, sheets, the rest timer. Content itself is solid.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with TickerProviderStateMixin {
  static const double _barH = 66, _button = 64, _blob = 62, _reach = 178;
  int _tab = 0;
  double _barW = 0;
  bool _open = false;
  int? _sheet; // index into _actions
  late final SpringValue _lensX = SpringValue(this, spring: Motions.follow);
  late final SpringValue _lift = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _t = SpringValue(this, spring: Motions.spatialFast);
  late final List<SpringValue> _out = <SpringValue>[
    for (int i = 0; i < 5; i++) SpringValue(this),
  ];
  late final SpringValue _kick = SpringValue(
    this,
    value: 1,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _rise = SpringValue(this, spring: Motions.spatial);
  late final SpringValue _page = SpringValue(
    this,
    value: 1,
    spring: Motions.effects,
  );
  final List<Timer> _fuses = <Timer>[];
  static final SpringDescription _shoot = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 950,
    ratio: 0.62,
  );
  double _sheetWeight = 81.8, _sheetSeconds = 90;

  @override
  void dispose() {
    for (final Timer t in _fuses) {
      t.cancel();
    }
    for (final SpringValue s in <SpringValue>[
      _lensX,
      _lift,
      _t,
      _kick,
      _rise,
      _page,
      ..._out,
    ]) {
      s.dispose();
    }
    super.dispose();
  }

  // Five slots across the bar: two tabs, the button, two tabs.
  double get _slot => _barW / 5;
  double _centre(int tab) => _slot * ((tab < 2 ? tab : tab + 1) + 0.5);

  void _go(int tab) {
    if (tab == _tab) {
      return;
    }
    setState(() => _tab = tab);
    _lensX.animateTo(_centre(tab));
    _page.jumpTo(0);
    _page.animateTo(1);
    Haptics.tick();
  }

  void _setOpen(bool v) {
    if (v == _open) {
      return;
    }
    setState(() => _open = v);
    _t.animateTo(v ? 1 : 0);
    for (final Timer t in _fuses) {
      t.cancel();
    }
    _fuses.clear();
    if (v) {
      for (int i = 0; i < 5; i++) {
        _fuses.add(
          Timer(
            Duration(milliseconds: (i - 2).abs() * 14),
            () => _out[i].animateTo(1, spring: _shoot),
          ),
        );
      }
      _kick.jumpTo(0.84);
      _kick.animateTo(1);
    } else {
      for (final SpringValue o in _out) {
        o.animateTo(0, spring: Motions.spatialFast);
      }
    }
    Haptics.tick();
  }

  void _run(int i) {
    _setOpen(false);
    Haptics.settle();
    if (i == 0) {
      _go(1);
      return;
    }
    setState(() {
      _sheet = i;
      _sheetWeight = fit.weight;
    });
    _rise.animateTo(1);
  }

  void _closeSheet() => _rise.animateTo(0);

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Size screen = MediaQuery.sizeOf(context);
    final Offset bc = Offset(
      screen.width / 2,
      screen.height - safe.bottom - 14 - _barH / 2,
    );
    Offset rest(int i) {
      final double a = math.pi * (0.19 + 0.62 * i / 4);
      return bc + Offset(-math.cos(a), -math.sin(a)) * _reach;
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          // The wallpaper: quiet, with a few soft lights for the glass to catch.
          Positioned.fill(child: _WallpaperImage(dark: c.dark)),
          // The page.
          Positioned.fill(
            child: ListenableBuilder(
              listenable: _page,
              builder: (BuildContext context, Widget? child) => Opacity(
                opacity: _page.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - _page.value) * 14),
                  child: child,
                ),
              ),
              child: IndexedStack(
                index: _tab,
                children: <Widget>[
                  HomePage(
                    onStart: () => _go(1),
                    onFood: () => _run(1),
                    onWeigh: () => _run(3),
                  ),
                  const TrainPage(),
                  const FoodPage(),
                  const ProgressPage(),
                ],
              ),
            ),
          ),
          // Content scrolls away under the status bar instead of colliding with the clock.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: safe.top + 18,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      c.bg.withValues(alpha: 0.92),
                      c.bg.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Dim behind the blobs.
          ListenableBuilder(
            listenable: _t,
            builder: (BuildContext context, Widget? _) => IgnorePointer(
              ignoring: !_open,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setOpen(false),
                child: ColoredBox(
                  color: Colors.black.withValues(
                    alpha: 0.46 * _t.value.clamp(0.0, 1.0),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          // The bar.
          Positioned(
            left: 14,
            right: 14,
            bottom: safe.bottom + 14,
            height: _barH,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                if (_barW != box.maxWidth) {
                  _barW = box.maxWidth;
                  scheduleMicrotask(() => _lensX.jumpTo(_centre(_tab)));
                }
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (TapUpDetails d) {
                    final int s = (d.localPosition.dx / _slot).floor().clamp(
                      0,
                      4,
                    );
                    if (s != 2) {
                      _lift.animateTo(0, velocity: 7);
                      _go(s < 2 ? s : s - 1);
                    }
                  },
                  // Slide along the bar and the lens comes with you.
                  onHorizontalDragStart: (_) => _lift.animateTo(1),
                  onHorizontalDragUpdate: (DragUpdateDetails d) =>
                      _lensX.animateTo(
                        d.localPosition.dx.clamp(_slot / 2, _barW - _slot / 2),
                      ),
                  onHorizontalDragEnd: (_) {
                    _lift.animateTo(0);
                    int best = 0;
                    for (int i = 1; i < 4; i++) {
                      if ((_centre(i) - _lensX.target).abs() <
                          (_centre(best) - _lensX.target).abs()) {
                        best = i;
                      }
                    }
                    if (best == _tab) {
                      _lensX.animateTo(_centre(best));
                    } else {
                      _go(best);
                    }
                  },
                  child: ListenableBuilder(
                    listenable: Listenable.merge(<Listenable>[_lensX, _lift]),
                    builder: (BuildContext context, Widget? _) {
                      // The lens swells when lifted, stretches along its travel and thins to keep its volume.
                      final double stretch = (_lensX.velocity.abs() / 70).clamp(
                        0.0,
                        26.0,
                      );
                      final double grow = 1 + 0.14 * _lift.value;
                      final double w = (_slot - 8) * grow + stretch,
                          h = (_barH - 12) * grow * (1 - stretch / 220);
                      final Rect lens = Rect.fromCenter(
                        center: Offset(_lensX.value, _barH / 2),
                        width: w,
                        height: h,
                      );
                      final RRect shape = RRect.fromRectAndRadius(
                        lens,
                        Radius.circular(h / 2),
                      );
                      final bool solid = settings.reduceTransparency;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Positioned.fill(
                            child: Glass(
                              radius: _barH / 2,
                              style: GlassStyle(
                                blur: 18,
                                tint: 0.42,
                                refraction: 30,
                                bevel: 20,
                                fallbackColor: c.surfaceHigh,
                              ),
                              hole: solid ? null : shape.deflate(0.5),
                            ),
                          ),
                          Positioned.fromRect(
                            rect: lens,
                            child: Glass(
                              radius: h / 2,
                              style: GlassStyle(
                                blur: 2.5,
                                tint: 0.16,
                                refraction: 22,
                                bevel: 13,
                                dispersion: 0.2,
                                magnify: 1.12,
                                light: 0.9,
                                saturation: 1.4,
                                adapt: 0.42,
                                shadow: 0.6,
                                fallbackColor: c.accent.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          Row(
                            children: <Widget>[
                              for (int s = 0; s < 5; s++)
                                Expanded(
                                  child: s == 2
                                      ? const SizedBox.shrink()
                                      : Builder(
                                          builder: (BuildContext context) {
                                            final int i = s < 2 ? s : s - 1;
                                            // Brightness follows the lens, not the tap, so it reads as the lens lighting the tab.
                                            final double on =
                                                (1 -
                                                        ((_centre(i) -
                                                                    _lensX
                                                                        .value)
                                                                .abs() /
                                                            _slot))
                                                    .clamp(0.0, 1.0);
                                            return Semantics(
                                              button: true,
                                              selected: i == _tab,
                                              label: _tabs[i].$2,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: <Widget>[
                                                  Transform.scale(
                                                    scale: 1 + 0.12 * on,
                                                    child: Icon(
                                                      _tabs[i].$1,
                                                      size: 23,
                                                      color: Color.lerp(
                                                        c.glassInk.withValues(
                                                          alpha: 0.6,
                                                        ),
                                                        c.glassInk,
                                                        on,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    _tabs[i].$2,
                                                    textScaler:
                                                        TextScaler.noScaling,
                                                    style: LumenType.text(
                                                      10.5,
                                                      weight: 560 + 140 * on,
                                                      color: Color.lerp(
                                                        c.glassInk.withValues(
                                                          alpha: 0.6,
                                                        ),
                                                        c.glassInk,
                                                        on,
                                                      ),
                                                      height: 1.1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
          // The blobs.
          for (int i = 0; i < 5; i++)
            ListenableBuilder(
              listenable: _out[i],
              builder: (BuildContext context, Widget? _) {
                final double p = _out[i].value;
                if (p <= 0.001) {
                  return const SizedBox.shrink();
                }
                final Offset b = bc + (rest(i) - bc) * p;
                final double st = (_out[i].velocity.abs() * 0.028).clamp(
                  0.0,
                  0.34,
                );
                final Offset dir = rest(i) - bc;
                final double ang = math.atan2(dir.dy, dir.dx),
                    s = 0.5 + 0.5 * p;
                return Positioned(
                  left: b.dx - _blob / 2 - 20,
                  top: b.dy - _blob / 2,
                  width: _blob + 40,
                  child: IgnorePointer(
                    ignoring: !_open,
                    child: Opacity(
                      opacity: (p * 2.4).clamp(0.0, 1.0),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _run(i),
                        child: Column(
                          children: <Widget>[
                            Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationZ(ang)
                                ..scaleByDouble(
                                  s * (1 + st),
                                  s * (1 - st * 0.5),
                                  1,
                                  1,
                                )
                                ..rotateZ(-ang),
                              child: Container(
                                width: _blob,
                                height: _blob,
                                decoration: ShapeDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[
                                      Color.lerp(
                                        _actions[i].$3,
                                        Colors.white,
                                        0.14,
                                      )!,
                                      _actions[i].$3,
                                    ],
                                  ),
                                  shape: CircleBorder(
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  _actions[i].$2,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _actions[i].$1,
                              maxLines: 1,
                              softWrap: false,
                              textScaler: TextScaler.noScaling,
                              style: LumenType.text(
                                13.5,
                                weight: 650,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          // The button: one flat colour, in the middle of the bar.
          Positioned(
            left: bc.dx - _button / 2,
            top: bc.dy - _button / 2,
            child: Semantics(
              button: true,
              label: 'Actions',
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _kick.animateTo(0.92),
                onPointerCancel: (_) => _kick.animateTo(1),
                onPointerUp: (_) {
                  _kick.animateTo(1);
                  _setOpen(!_open);
                },
                child: ListenableBuilder(
                  listenable: Listenable.merge(<Listenable>[_t, _kick]),
                  builder: (BuildContext context, Widget? _) => Transform.scale(
                    scale: _kick.value,
                    child: Container(
                      width: _button,
                      height: _button,
                      decoration: ShapeDecoration(
                        color: c.accent,
                        shape: const CircleBorder(),
                        shadows: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Transform.rotate(
                        angle: _t.value.clamp(0.0, 1.2) * math.pi / 4,
                        child: Icon(
                          Icons.add_rounded,
                          color: c.onAccent,
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // A quick action: a glass sheet over the page. You never leave where you were.
          ListenableBuilder(
            listenable: _rise,
            builder: (BuildContext context, Widget? _) {
              final double t = _rise.value;
              final int? i = _sheet;
              if (t <= 0.001 || i == null) {
                return const SizedBox.shrink();
              }
              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _closeSheet,
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: 0.4 * t.clamp(0.0, 1.0),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: safe.bottom + 10 - (1 - t) * 420,
                    child: Glass(
                      radius: 36,
                      // The heavier, more opaque glass: there is text to read on it.
                      style: GlassStyle(
                        blur: 26,
                        tint: 0.72,
                        refraction: 22,
                        bevel: 18,
                        fallbackColor: c.surface,
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          child: _sheetBody(c, i),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sheetBody(LumenColors c, int i) {
    final (String title, IconData icon, Color col) = _actions[i];
    Widget cta(String label, VoidCallback onTap) => Pressable(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: c.accent,
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: LumenType.text(
            15.5,
            weight: 700,
            color: c.onAccent,
            height: 1,
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: ShapeDecoration(
              color: c.glassInk.withValues(alpha: 0.35),
              shape: const StadiumBorder(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: ShapeDecoration(
                color: col,
                shape: const CircleBorder(),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: LumenType.display(26, weight: 700, color: c.glassInk),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (i == 1) ...<Widget>[
          for (final int m in const <int>[1, 3, 0])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Pressable(
                scale: 0.98,
                onTap: () {
                  fit.addMeal(m, 1);
                  Haptics.settle();
                  _closeSheet();
                },
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: c.glassInk.withValues(alpha: 0.08),
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          FitState.meals[m].$2,
                          style: LumenType.text(
                            15.5,
                            weight: 600,
                            color: c.glassInk,
                          ),
                        ),
                      ),
                      Text(
                        '${FitState.meals[m].$3} kcal',
                        style: LumenType.text(
                          14,
                          weight: 650,
                          color: c.glassInk.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.add_circle_rounded, color: c.accent),
                    ],
                  ),
                ),
              ),
            ),
          Text(
            'Your three most recent. One tap logs it.',
            style: LumenType.text(13, color: c.glassInk.withValues(alpha: 0.6)),
          ),
        ] else if (i == 3) ...<Widget>[
          DragDial(
            value: _sheetWeight,
            step: 0.5,
            fineStep: 0.1,
            min: 30,
            max: 250,
            unit: 'kg',
            onChanged: (double v) => setState(() => _sheetWeight = v),
          ),
          const SizedBox(height: 14),
          cta('Save ${_sheetWeight.toStringAsFixed(1)} kg', () {
            fit.weigh(_sheetWeight);
            Haptics.settle();
            _closeSheet();
          }),
        ] else if (i == 4) ...<Widget>[
          DragDial(
            value: _sheetSeconds,
            step: 5,
            fineStep: 1,
            min: 5,
            max: 900,
            unit: 's',
            onChanged: (double v) => setState(() => _sheetSeconds = v),
          ),
          const SizedBox(height: 14),
          cta('Start ${_sheetSeconds.round()} s', _closeSheet),
        ] else ...<Widget>[
          Text(
            'The camera would open here, in this sheet, and close itself once it reads a barcode.',
            style: LumenType.text(
              14.5,
              color: c.glassInk.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          cta('Close', _closeSheet),
        ],
      ],
    );
  }
}

/// Opens Prism's settings as a glass sheet. Used by the round button at the top of Home.
void showPrismSettings(BuildContext context) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (BuildContext context, _, _) {
      final LumenColors c = LumenColors.of(context);
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            10,
            0,
            10,
            MediaQuery.paddingOf(context).bottom + 10,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: ShapeDecoration(
                color: c.surface,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(36),
                  side: BorderSide(color: c.hairline),
                ),
              ),
              child: ListenableBuilder(
                listenable: settings,
                builder: (BuildContext context, Widget? _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Prism',
                      style: LumenType.display(26, weight: 700, color: c.ink),
                    ),
                    Text(
                      'A fitness app prototype in the Lumen glass design. Data is made up.',
                      style: LumenType.text(
                        13.5,
                        color: c.inkMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchLine(
                      label: 'Dark',
                      value: settings.themeMode == ThemeMode.dark,
                      onChanged: (bool v) => settings.themeMode = v
                          ? ThemeMode.dark
                          : ThemeMode.light,
                    ),
                    const SizedBox(height: 12),
                    SwitchLine(
                      label: 'Frame-rate readout',
                      value: settings.showFps,
                      onChanged: (bool v) => settings.showFps = v,
                    ),
                    const SizedBox(height: 12),
                    SwitchLine(
                      label: 'Haptics',
                      value: settings.haptics,
                      onChanged: (bool v) => settings.haptics = v,
                    ),
                    const SizedBox(height: 12),
                    SwitchLine(
                      label: 'Reduce transparency',
                      value: settings.reduceTransparency,
                      onChanged: (bool v) => settings.reduceTransparency = v,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Glass quality',
                      style: LumenType.label(color: c.inkMuted),
                    ),
                    const SizedBox(height: 8),
                    Segmented<GlassQuality>(
                      values: const <GlassQuality>[
                        GlassQuality.auto,
                        GlassQuality.full,
                        GlassQuality.medium,
                        GlassQuality.low,
                      ],
                      labels: const <String>['Auto', 'Full', 'Medium', 'Low'],
                      value: settings.quality,
                      onChanged: (GlassQuality v) => settings.quality = v,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder:
        (BuildContext context, Animation<double> a, _, Widget child) =>
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child,
            ),
  );
}

class _Wallpaper extends CustomPainter {
  const _Wallpaper(this.dark);
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xFF0B0D13) : const Color(0xFFF2EEE7),
    );
    // Each light is many faint discs laid on top of each other, smallest last, so it
    // falls off smoothly without relying on how a renderer handles gradients.
    void light(Offset at, double r, Color col, double a) {
      const int rings = 96;
      final Paint p = Paint()..color = col.withValues(alpha: a * 1.9 / rings);
      for (int i = 0; i < rings; i++) {
        final double f = 1 - i / rings;
        canvas.drawPath(
          Path()..addOval(
            Rect.fromCircle(
              center: at,
              radius: r * f * f.clamp(0.35, 1.0) + r * 0.04,
            ),
          ),
          p,
        );
      }
    }

    final double k = dark ? 0.6 : 0.45;
    light(
      Offset(size.width * 0.12, size.height * 0.10),
      size.width * 0.85,
      const Color(0xFFFF6B4A),
      0.30 * k,
    );
    light(
      Offset(size.width * 1.0, size.height * 0.34),
      size.width * 0.8,
      const Color(0xFF7C5CFF),
      0.26 * k,
    );
    light(
      Offset(size.width * 0.05, size.height * 0.72),
      size.width * 0.8,
      const Color(0xFF1FB7A6),
      0.22 * k,
    );
    light(
      Offset(size.width * 0.9, size.height * 0.98),
      size.width * 0.75,
      const Color(0xFFF5B301),
      0.22 * k,
    );
  }

  @override
  bool shouldRepaint(_Wallpaper old) => old.dark != dark;
}

/// The wallpaper, drawn once into a small picture and then shown stretched.
/// Drawing the soft lights live cost the phone about half its frames; a
/// picture costs almost nothing, and the stretching smooths the lights.
class _WallpaperImage extends StatefulWidget {
  const _WallpaperImage({required this.dark});
  final bool dark;

  @override
  State<_WallpaperImage> createState() => _WallpaperImageState();
}

class _WallpaperImageState extends State<_WallpaperImage> {
  ui.Image? _image;
  Size _size = Size.zero;
  bool? _dark;

  Future<void> _render(Size size, bool dark) async {
    _size = size;
    _dark = dark;
    final Size small = Size(
      (size.width / 4).ceilToDouble(),
      (size.height / 4).ceilToDouble(),
    );
    final ui.PictureRecorder rec = ui.PictureRecorder();
    _Wallpaper(dark).paint(Canvas(rec), small);
    final ui.Picture pic = rec.endRecording();
    final ui.Image img = await pic.toImage(
      small.width.toInt(),
      small.height.toInt(),
    );
    pic.dispose();
    if (!mounted) {
      img.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = img;
    });
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final Size size = box.biggest;
        if (size != _size || widget.dark != _dark) {
          _render(size, widget.dark);
        }
        return ColoredBox(
          color: widget.dark
              ? const Color(0xFF0B0D13)
              : const Color(0xFFF2EEE7),
          child: _image == null
              ? const SizedBox.expand()
              : RawImage(
                  image: _image,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                ),
        );
      },
    );
  }
}
