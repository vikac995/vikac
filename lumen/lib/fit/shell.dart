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
import 'diag.dart';
import 'food_page.dart';
import 'home_page.dart';
import 'lens.dart';
import 'progress_page.dart';
import 'robot.dart';
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
  bool _sheetOpen = false;
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
  // The jiggle of a drop that has just landed: wider then taller, dying away.
  late final SpringValue _wob = SpringValue(
    this,
    spring: SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 520,
      ratio: 0.3,
    ),
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
    stiffness: 620,
    ratio: 0.52,
  );
  double _sheetWeight = 81.8, _sheetSeconds = 90;

  // The lens: the button, carried. See Lumen R51.
  static const double _lensSize = 107.5;
  late final SpringValue _glass = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _lx = SpringValue(this, spring: Motions.follow);
  late final SpringValue _ly = SpringValue(this, spring: Motions.follow);
  late final SpringValue _morph = SpringValue(this, spring: Motions.expressive);
  late final SpringValue _say = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  bool _carrying = false, _parked = false, _moved = false;
  Offset? _downAt;
  Offset _home = Offset.zero;
  LensTargetState? _target, _pill;
  // On its way home the lens is a blob of the button's colour, not glass.
  bool _returning = false;
  Offset _retFrom = Offset.zero;
  Color _retColor = const Color(0xFFFF6A47);
  double _pillW = 200;
  Rect _lensRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    Diag.instance.finished.addListener(_showReport);
    Diag.instance.autoScript = _robot;
    _lx.addListener(_lensMoved);
    _ly.addListener(_lensMoved);
    _glass.addListener(_lensMoved);
  }

  /// The automatic half of the test: one pass over everything, with real touch events.
  Future<void> _robot() async {
    if (!mounted) {
      return;
    }
    final Size sc = MediaQuery.sizeOf(context);
    final Offset b = _home;
    Offset tab(int i) => Offset(14 + _centre(i), b.dy);
    Offset blob(int i) {
      final double a = math.pi * (0.19 + 0.62 * i / 4);
      return b + Offset(-math.cos(a), -math.sin(a)) * _reach;
    }

    final Offset mid = Offset(sc.width / 2, sc.height * 0.12);
    Future<void> scroll() async {
      await Robot.drag(
        <Offset>[
          Offset(sc.width / 2, sc.height * 0.62),
          Offset(sc.width / 2, sc.height * 0.34),
        ],
        legMs: 180,
        flick: true,
        after: 850,
      );
      await Robot.drag(
        <Offset>[
          Offset(sc.width / 2, sc.height * 0.34),
          Offset(sc.width / 2, sc.height * 0.62),
        ],
        legMs: 180,
        flick: true,
        after: 850,
      );
    }

    // Start from a known place.
    await Robot.tap(tab(0));
    // 1. Every screen: arrive, flick down, flick back. On Train also tick a set and untick it.
    for (final int i in <int>[1, 2, 3, 0]) {
      await Robot.tap(tab(i), after: 900);
      await scroll();
      final Offset? tick = i == 1 ? Robot.spot('tick') : null;
      if (tick != null) {
        await Robot.tap(tick, after: 900);
        await Robot.tap(tick, after: 700);
      }
    }
    // 2. Tabs again, quickly, as someone hunting for something does.
    for (final int i in <int>[2, 1, 3, 0]) {
      await Robot.tap(tab(i), after: 500);
    }
    // 3. The blobs, open and closed, twice.
    for (int n = 0; n < 2; n++) {
      await Robot.tap(b, after: 700);
      await Robot.tap(b, after: 600);
    }
    // 4. Sheets: Weigh-in twice, then the fourth blob's neighbour, each dismissed by tapping above.
    for (final int i in <int>[3, 3, 1]) {
      await Robot.tap(b, after: 500);
      await Robot.tap(blob(i), after: 900);
      if (_sheetOpen) {
        await Robot.tap(mid, after: 700);
      } else if (_open) {
        await Robot.tap(b, after: 500);
      }
    }
    // 5. Carry the lens over every card on Home, top to bottom, twice.
    final List<Rect> cards =
        <Rect>[
          for (final LensTargetState t in LensBus.instance.targets)
            if (t.widget.page == 'home' && t.rect != null) t.rect!,
        ]..sort(
          (Rect x, Rect y) => x.top != y.top
              ? x.top.compareTo(y.top)
              : x.left.compareTo(y.left),
        );
    for (int n = 0; n < 2 && cards.isNotEmpty; n++) {
      // The glass rides 62 above the finger, so the finger aims that much lower.
      await Robot.drag(
        <Offset>[b, for (final Rect r in cards) r.center + const Offset(0, 62)],
        legMs: 380,
        dwell: 350,
        after: 900,
      );
      if (_parked || _carrying) {
        _lensHome();
        await Robot.wait(600);
      }
    }
    // Make sure nothing is left open for the next setting.
    if (_parked || _carrying) {
      _lensHome();
    }
    if (_open) {
      _setOpen(false);
    }
    await Robot.wait(400);
  }

  void _showReport() {
    final String? text = Diag.instance.finished.value;
    if (text == null || !mounted) {
      return;
    }
    Diag.instance.finished.value = null;
    Haptics.thud();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      pageBuilder: (BuildContext context, _, _) {
        final LumenColors c = LumenColors.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: ShapeDecoration(
                  color: c.surface,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(32),
                    side: BorderSide(color: c.hairline),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Test finished',
                      style: LumenType.display(26, weight: 700, color: c.ink),
                    ),
                    Text(
                      'Your settings are back as they were. Copy this and paste it to Claude.',
                      style: LumenType.text(
                        13.5,
                        color: c.inkMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            text,
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10.5,
                              height: 1.4,
                              color: c.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Pressable(
                      onTap: () async {
                        await Diag.instance.copy(text);
                        Haptics.settle();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: c.accent,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Copy report',
                          style: LumenType.text(
                            15.5,
                            weight: 700,
                            color: c.onAccent,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _lensMoved() {
    if (_returning) {
      // Landed when it has covered the whole way, even if a frame steps past the exact spot.
      final Offset way = _home - _retFrom,
          done = Offset(_lx.value, _ly.value) - _retFrom;
      final double whole = way.distanceSquared;
      if (whole < 4 || (done.dx * way.dx + done.dy * way.dy) / whole >= 0.985) {
        final double speed = Offset(_lx.velocity, _ly.velocity).distance;
        setState(() => _returning = false);
        _lx.jumpTo(_home.dx);
        _ly.jumpTo(_home.dy);
        _glass.jumpTo(0);
        // It hits and jiggles: the faster it arrived, the more.
        _wob.jumpTo((speed / 5000).clamp(0.07, 0.2));
        _wob.animateTo(0);
        Haptics.settle();
      }
    }
    // Only while held or placed. On its way home it is just a button again and must not wake the cards it passes.
    final bool live = _carrying || _parked;
    LensBus.instance.pos.value = live ? Offset(_lx.value, _ly.value) : null;
    if (!_carrying) {
      return;
    }
    final LensTargetState? t = LensBus.instance.over(
      _tabs[_tab].$2.toLowerCase(),
    );
    if (t == _target) {
      return;
    }
    // No setState: that rebuilt the whole app each time the lens crossed onto a card.
    // The lens layer repaints by itself because the springs below start moving.
    _target = t;
    if (t != null && t.widget.actions.isNotEmpty) {
      // Something can be done here: the glass stretches into a pill holding the actions.
      _pill = t;
      _pillW = math.min(
        MediaQuery.sizeOf(context).width - 24,
        t.widget.actions.fold<double>(
          0,
          (double w, (String, VoidCallback) a) => w + a.$1.length * 8.8 + 44,
        ),
      );
      _morph.animateTo(1);
      Haptics.settle();
    } else {
      _morph.animateTo(0, spring: Motions.spatial);
    }
    if (t != null) {
      _say.jumpTo(0.6);
      _say.animateTo(1);
      Haptics.tick();
      Diag.instance.event('lens on ${t.widget.title}');
    } else {
      _say.animateTo(0, spring: Motions.spatialFast);
    }
  }

  void _lensHome() {
    final bool away = _glass.value > 0.05, wasParked = _parked;
    _retFrom = Offset(_lx.value, _ly.value);
    _retColor =
        (_parked ? _pill?.widget.color : null) ??
        LumenColors.of(context).accent;
    setState(() {
      _returning = away;
      _carrying = false;
      _parked = false;
      _target = null;
    });
    if (away && !wasParked && _morph.value < 0.3) {
      // The glass rode above the finger and was large. The drop starts nearer the finger, and smaller.
      _ly.jumpTo(_ly.value + 34);
      if (_glass.value > 0.3) {
        _glass.jumpTo(0.3);
      }
      _retFrom = Offset(_lx.value, _ly.value);
    }
    _lx.animateTo(_home.dx, spring: Motions.expressive);
    _ly.animateTo(_home.dy, spring: Motions.expressive);
    LensBus.instance.pos.value = null;
    _glass.animateTo(0);
    _morph.animateTo(0, spring: Motions.spatial);
    _say.animateTo(0, spring: Motions.spatialFast);
    Diag.instance.overlay = '';
    Haptics.tick();
  }

  void _buttonMove(PointerMoveEvent e) {
    if (_downAt == null) {
      return;
    }
    final Size screen = MediaQuery.sizeOf(context);
    if (!_moved) {
      if ((e.position - _downAt!).distance < 10) {
        return;
      }
      // The button lifts off: from here on it is a lens.
      _moved = true;
      _setOpen(false);
      setState(() {
        _carrying = true;
        _returning = false;
      });
      _lx.jumpTo(_home.dx);
      _ly.jumpTo(_home.dy);
      _glass.animateTo(1);
      _kick.animateTo(1);
      Haptics.settle();
      Diag.instance
        ..overlay = '+lens'
        ..event('lens lifted');
    }
    // The glass rides above the thumb so the thumb does not cover it.
    _lx.animateTo(
      e.position.dx.clamp(_lensSize / 2, screen.width - _lensSize / 2),
    );
    _ly.animateTo(
      (e.position.dy - 62).clamp(
        _lensSize / 2 + 30,
        screen.height - _lensSize / 2,
      ),
    );
  }

  void _buttonUp() {
    _kick.animateTo(1);
    if (_downAt == null) {
      return;
    }
    _downAt = null;
    if (!_moved) {
      _setOpen(!_open);
    } else if (_target != null && _target!.widget.actions.isNotEmpty) {
      // Put down on something you can act on: the pill stays and is the buttons.
      setState(() {
        _carrying = false;
        _parked = true;
      });
      Haptics.settle();
    } else {
      _lensHome();
    }
  }

  void _pillTap(Offset at) {
    final LensTargetState? t = _pill;
    if (t == null) {
      _lensHome();
      return;
    }
    final List<(String, VoidCallback)> acts = t.widget.actions;
    double x =
        (at.dx - _lensRect.left) /
        _lensRect.width *
        acts.fold<int>(
          0,
          (int n, (String, VoidCallback) a) => n + a.$1.length + 5,
        );
    (String, VoidCallback) pick = acts.last;
    for (final (String, VoidCallback) a in acts) {
      x -= a.$1.length + 5;
      if (x <= 0) {
        pick = a;
        break;
      }
    }
    Diag.instance.event('lens action ${pick.$1}');
    _lensHome();
    pick.$2();
  }

  @override
  void dispose() {
    for (final Timer t in _fuses) {
      t.cancel();
    }
    Diag.instance.finished.removeListener(_showReport);
    LensBus.instance.pos.value = null;
    for (final SpringValue s in <SpringValue>[
      _glass,
      _lx,
      _ly,
      _morph,
      _say,
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
    Diag.instance
      ..page = _tabs[tab].$2.toLowerCase()
      ..event('tab ${_tabs[tab].$2}');
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
    Diag.instance
      ..overlay = v ? '+blobs' : ''
      ..event(v ? 'blobs open' : 'blobs close');
    _t.animateTo(v ? 1 : 0);
    for (final Timer t in _fuses) {
      t.cancel();
    }
    _fuses.clear();
    if (v) {
      for (int i = 0; i < 5; i++) {
        _fuses.add(
          Timer(
            Duration(milliseconds: i * 38),
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
    _sheetOpen = true;
    _rise.animateTo(1);
    Diag.instance
      ..overlay = '+sheet'
      ..event('sheet ${_actions[i].$1}');
  }

  void _closeSheet() {
    setState(() => _sheetOpen = false);
    _rise.animateTo(0);
    Diag.instance
      ..overlay = ''
      ..event('sheet close');
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Size screen = MediaQuery.sizeOf(context);
    final Offset bc = Offset(
      screen.width / 2,
      screen.height - safe.bottom - 14 - _barH / 2,
    );
    _home = bc;
    Offset rest(int i) {
      final double a = math.pi * (0.19 + 0.62 * i / 4);
      return bc + Offset(-math.cos(a), -math.sin(a)) * _reach;
    }

    // The system back button undoes the last thing that opened, one step at a time,
    // and only leaves the app from Home with nothing open.
    final bool nothingOpen = !_open && !_sheetOpen && !_parked && !_carrying;
    return PopScope(
      canPop: nothingOpen && _tab == 0,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) {
          return;
        }
        if (_sheetOpen) {
          Diag.instance.event('back: close sheet');
          _closeSheet();
        } else if (_parked || _carrying) {
          Diag.instance.event('back: lens home');
          _lensHome();
        } else if (_open) {
          Diag.instance.event('back: close blobs');
          _setOpen(false);
        } else {
          Diag.instance.event('back: to Home');
          _go(0);
        }
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: <Widget>[
            // The wallpaper: quiet, with a few soft lights for the glass to catch.
            Positioned.fill(
              child: ValueListenableBuilder<bool>(
                valueListenable: Diag.instance.wallpaperOn,
                builder: (BuildContext context, bool on, Widget? _) => on
                    ? _WallpaperImage(dark: c.dark)
                    : ColoredBox(color: c.bg),
              ),
            ),
            // The page.
            Positioned.fill(
              child: ListenableBuilder(
                listenable: _page,
                // A small slide only. Fading a whole page means drawing it twice, which is where the stutters on tab changes came from.
                builder: (BuildContext context, Widget? child) =>
                    Transform.translate(
                      offset: Offset(0, (1 - _page.value) * 14),
                      child: child,
                    ),
                // Its own layer, so sliding a page in moves a finished picture and repaints nothing.
                child: RepaintBoundary(
                  child: NotificationListener<ScrollStartNotification>(
                    onNotification: (ScrollStartNotification n) {
                      if (n.dragDetails != null) {
                        Diag.instance.event('scroll ${_tabs[_tab].$2}');
                      }
                      return false;
                    },
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
                          d.localPosition.dx.clamp(
                            _slot / 2,
                            _barW - _slot / 2,
                          ),
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
                      listenable: Listenable.merge(<Listenable>[
                        _lensX,
                        _lift,
                        Diag.instance.glassMode,
                        Diag.instance.autoLevel,
                      ]),
                      builder: (BuildContext context, Widget? _) {
                        // The lens swells when lifted, stretches along its travel and thins to keep its volume.
                        final double stretch = (_lensX.velocity.abs() / 70)
                            .clamp(0.0, 26.0);
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
                        final bool off = settings.reduceTransparency;
                        final int mode = Diag.instance.barMode;
                        final bool lensOut = _carrying || _parked;
                        final bool moving =
                            (_lensX.value - _lensX.target).abs() > 0.5 ||
                            _lift.value > 0.01;
                        // The bar itself, and the small lens that rides in it.
                        final bool barSolid =
                            off || mode == 3 || (mode == 1 && lensOut);
                        final bool riderSolid =
                            off ||
                            mode == 3 ||
                            (mode == 1 && (moving || lensOut));
                        final bool solid = barSolid || riderSolid;
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
                                  // In the new styles the solid bar is matched to the glass one, so swapping does not flash.
                                  fallbackColor: mode == 0
                                      ? c.surfaceHigh
                                      : Color.lerp(c.bg, c.surfaceHigh, 0.35),
                                ),
                                hole: solid ? null : shape.deflate(0.5),
                                solid: barSolid,
                                quality: mode == 2 ? GlassQuality.low : null,
                              ),
                            ),
                            Positioned.fromRect(
                              rect: lens,
                              child: Glass(
                                solid: riderSolid,
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
                                  fallbackColor: mode == 0
                                      ? c.accent.withValues(alpha: 0.3)
                                      : c.ink.withValues(alpha: 0.10),
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
            // The threads: each blob stays tied to the button until it arrives.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ThreadPainter(
                    from: bc,
                    to: <Offset>[for (int i = 0; i < 5; i++) rest(i)],
                    out: _out,
                    colors: <Color>[for (int i = 0; i < 5; i++) _actions[i].$3],
                  ),
                ),
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
                  final double st = (_out[i].velocity.abs() * 0.04).clamp(
                    0.0,
                    0.46,
                  );
                  final Offset dir = rest(i) - bc;
                  final double ang = math.atan2(dir.dy, dir.dx),
                      s =
                          0.14 +
                          0.86 * math.pow(p.clamp(0.0, 1.0), 1.5) +
                          (p > 1 ? (p - 1) * 0.35 : 0);
                  return Positioned(
                    left: b.dx - _blob / 2 - 20,
                    top: b.dy - _blob / 2,
                    width: _blob + 40,
                    child: IgnorePointer(
                      ignoring: !_open,
                      child: Opacity(
                        opacity: (p * 12).clamp(0.0, 1.0),
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
                              // The name appears once the blob is nearly there, not while it is a speck.
                              Opacity(
                                opacity: ((p - 0.6) / 0.4).clamp(0.0, 1.0),
                                child: Text(
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
                  onPointerDown: (PointerDownEvent e) {
                    _downAt = e.position;
                    _moved = false;
                    _kick.animateTo(0.92);
                  },
                  onPointerMove: _buttonMove,
                  onPointerCancel: (_) => _buttonUp(),
                  onPointerUp: (_) => _buttonUp(),
                  child: ListenableBuilder(
                    listenable: Listenable.merge(<Listenable>[
                      _t,
                      _kick,
                      _glass,
                      _wob,
                    ]),
                    builder: (BuildContext context, Widget? _) =>
                        Transform.scale(
                          scaleX: _kick.value * (1 + _wob.value),
                          scaleY: _kick.value * (1 - _wob.value),
                          child: _glass.value > 0.5 || _returning
                              // While the button is away, an empty ring marks where it lives.
                              ? Container(
                                  width: _button,
                                  height: _button,
                                  decoration: ShapeDecoration(
                                    shape: CircleBorder(
                                      side: BorderSide(
                                        color: c.glassInk.withValues(
                                          alpha: 0.35,
                                        ),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
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
                                    angle:
                                        _t.value.clamp(0.0, 1.2) * math.pi / 4,
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
            // The lens, its explanation, and (once put down) its buttons.
            ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[
                _glass,
                _lx,
                _ly,
                _morph,
                _say,
              ]),
              builder: (BuildContext context, Widget? _) {
                final double g = _glass.value;
                if (g <= 0.02 && !_returning) {
                  return const SizedBox.shrink();
                }
                final double m = _morph.value, mm = m.clamp(0.0, 1.0);
                final double size = _button + (_lensSize - _button) * g;
                final double lw = (size + (_pillW - size) * m).clamp(
                      40.0,
                      screen.width - 12,
                    ),
                    lh = size + (60 - size) * m.clamp(0.0, 1.15);
                final Offset at = Offset(_lx.value, _ly.value);
                final Rect lens = Rect.fromCenter(
                  center: Offset(
                    at.dx.clamp(lw / 2 + 6, screen.width - lw / 2 - 6),
                    at.dy,
                  ),
                  width: lw,
                  height: lh,
                );
                _lensRect = lens;
                if (_returning) {
                  return IgnorePointer(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _BlobPainter(
                        body: lens,
                        velocity: Offset(_lx.velocity, _ly.velocity),
                        home: _home,
                        from: _retFrom,
                        start: _retColor,
                        end: c.accent,
                        ink: c.onAccent,
                        button: _button,
                      ),
                    ),
                  );
                }
                final LensTarget? pill = _pill?.widget, said = _target?.widget;
                final bool above = lens.top > safe.top + 150;
                return Stack(
                  children: <Widget>[
                    if (_parked)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _lensHome,
                        ),
                      ),
                    Positioned.fromRect(
                      rect: lens,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: _parked
                            ? (TapUpDetails d) => _pillTap(d.globalPosition)
                            : null,
                        child: Glass(
                          radius: lh / 2,
                          // Clear and magnifying while it only looks; coloured and calm once it holds actions.
                          style: GlassStyle(
                            blur: 0.8 + 11 * mm,
                            tint: 0.05 + 0.5 * mm,
                            tintColor: mm > 0.02 ? pill?.color : null,
                            refraction: 19,
                            bevel: 13,
                            dispersion: 0.16,
                            magnify: 1.2 - 0.2 * mm,
                            light: 0.95,
                            saturation: 1.35,
                            adapt: 0.3,
                            shadow: 0.9,
                            fallbackColor: pill?.color ?? c.accent,
                          ),
                          child: pill == null || mm < 0.05
                              ? null
                              : Opacity(
                                  opacity: ((mm - 0.35) / 0.65).clamp(0.0, 1.0),
                                  child: Row(
                                    children: <Widget>[
                                      for (final (
                                            int i,
                                            (String, VoidCallback) a,
                                          )
                                          in pill.actions.indexed) ...<Widget>[
                                        if (i > 0)
                                          Container(
                                            width: 1,
                                            height: 26,
                                            color: Colors.white.withValues(
                                              alpha: 0.4,
                                            ),
                                          ),
                                        Expanded(
                                          flex: a.$1.length + 5,
                                          child: Center(
                                            child: Text(
                                              a.$1,
                                              maxLines: 1,
                                              softWrap: false,
                                              overflow: TextOverflow.fade,
                                              textScaler: TextScaler.noScaling,
                                              style: LumenType.text(
                                                15,
                                                weight: 700,
                                                color: Colors.white,
                                                height: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (said != null)
                      Positioned(
                        left: (at.dx - 134).clamp(12.0, screen.width - 280),
                        top: above ? null : lens.bottom + 96,
                        bottom: above ? screen.height - lens.top + 12 : null,
                        width: 268,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: _say.value.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.86 + 0.14 * _say.value,
                              alignment: above
                                  ? Alignment.bottomCenter
                                  : Alignment.topCenter,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  13,
                                ),
                                decoration: ShapeDecoration(
                                  color: c.dark
                                      ? const Color(0xF21B1E26)
                                      : const Color(0xF2FFFFFF),
                                  shape: RoundedSuperellipseBorder(
                                    borderRadius: BorderRadius.circular(22),
                                    side: BorderSide(
                                      color: said.color.withValues(alpha: 0.7),
                                      width: 1.5,
                                    ),
                                  ),
                                  shadows: <BoxShadow>[
                                    BoxShadow(
                                      color: c.shadow,
                                      blurRadius: 22,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      said.title,
                                      style: LumenType.text(
                                        15.5,
                                        weight: 700,
                                        color: c.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      said.explain,
                                      style: LumenType.text(
                                        14,
                                        color: c.inkMuted,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
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
                      // Solid, not glass: blurring this much of the screen was the costliest thing in the app to open.
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: c.surface,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(36),
                            side: BorderSide(color: c.hairline),
                          ),
                          shadows: <BoxShadow>[
                            BoxShadow(
                              color: c.shadow,
                              blurRadius: 30,
                              offset: const Offset(0, -6),
                            ),
                          ],
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
              color: c.ink.withValues(alpha: 0.35),
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
              style: LumenType.display(26, weight: 700, color: c.ink),
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
                    color: c.ink.withValues(alpha: 0.08),
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
                            color: c.ink,
                          ),
                        ),
                      ),
                      Text(
                        '${FitState.meals[m].$3} kcal',
                        style: LumenType.text(
                          14,
                          weight: 650,
                          color: c.ink.withValues(alpha: 0.7),
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
            style: LumenType.text(13, color: c.ink.withValues(alpha: 0.6)),
          ),
        ] else if (i == 3) ...<Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _sheetWeight.toStringAsFixed(1),
                textScaler: TextScaler.noScaling,
                style: LumenType.display(
                  54,
                  weight: 700,
                  color: c.ink,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 7, left: 6),
                child: Text('kg', style: LumenType.text(17, color: c.inkMuted)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // The big ruler from Lumen R23: drag it or flick it.
          Ruler(
            value: _sheetWeight,
            min: 30,
            max: 250,
            step: 0.1,
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
              color: c.ink.withValues(alpha: 0.75),
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
                listenable: Listenable.merge(<Listenable>[
                  settings,
                  Diag.instance.wallpaperOn,
                ]),
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
                    const SizedBox(height: 12),
                    SwitchLine(
                      label: 'Background lights (costs frames)',
                      value: Diag.instance.wallpaperOn.value,
                      onChanged: (bool v) =>
                          Diag.instance.wallpaperOn.value = v,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Glass style (Auto: Original if the phone keeps up, else Event)',
                      style: LumenType.label(color: c.inkMuted),
                    ),
                    const SizedBox(height: 8),
                    ListenableBuilder(
                      listenable: Diag.instance.glassMode,
                      builder: (BuildContext context, Widget? _) =>
                          Segmented<int>(
                            values: const <int>[4, 0, 1, 2, 3],
                            labels: const <String>[
                              'Auto',
                              'Orig.',
                              'One',
                              'Frost',
                              'Event',
                            ],
                            value: Diag.instance.glassMode.value,
                            onChanged: (int v) =>
                                Diag.instance.glassMode.value = v,
                          ),
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
                    const SizedBox(height: 18),
                    Text('Testing', style: LumenType.label(color: c.inkMuted)),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: Pressable(
                            onTap: () async {
                              await Diag.instance.copy();
                              Haptics.settle();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              decoration: ShapeDecoration(
                                color: c.accent,
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                'Copy test report',
                                style: LumenType.text(
                                  15,
                                  weight: 700,
                                  color: c.onAccent,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Pressable(
                            onTap: () {
                              Diag.instance.reset();
                              Haptics.tick();
                            },
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              decoration: ShapeDecoration(
                                shape: StadiumBorder(
                                  side: BorderSide(color: c.inkFaint),
                                ),
                              ),
                              child: Text(
                                'Start over',
                                style: LumenType.text(
                                  15,
                                  weight: 650,
                                  color: c.ink,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Pressable(
                      onTap: () {
                        Navigator.of(context).pop();
                        Diag.instance.startGuided();
                        Haptics.settle();
                      },
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: c.ink.withValues(alpha: 0.08),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Run the test (about ${(Diag.testSeconds / 60).toStringAsFixed(1)} min)',
                          style: LumenType.text(
                            15,
                            weight: 700,
                            color: c.ink,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The test runs in two parts under each glass setting: first the app drives itself (hands off), then you use it. One report at the end covers both.',
                      style: LumenType.text(
                        12.5,
                        color: c.inkMuted,
                        height: 1.35,
                      ),
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

/// The lens going home: a drop of the button's colour. It stretches along its
/// path, leaves a short tail and lands where the button lives. Flat colour only: no glass, no blur, no shadow.
class _BlobPainter extends CustomPainter {
  const _BlobPainter({
    required this.body,
    required this.velocity,
    required this.home,
    required this.from,
    required this.start,
    required this.end,
    required this.ink,
    required this.button,
  });
  final Rect body;
  final Offset velocity, home, from;
  final Color start, end, ink;
  final double button;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset at = body.center;
    final double whole = math.max((from - home).distance, 1);
    final double p = (1 - (at - home).distance / whole).clamp(0.0, 1.0);
    final Paint paint = Paint()
      ..color = Color.lerp(start, end, Curves.easeOut.transform(p))!;
    // The tail: three smaller drops left behind along the path.
    final double r = body.shortestSide / 2;
    // Spaced by speed, but never so far that the drops come apart.
    final double speed = velocity.distance;
    final Offset tail = speed < 1
        ? Offset.zero
        : velocity / speed * math.min(speed * 0.011, r * 0.6);
    for (int k = 1; k <= 3; k++) {
      canvas.drawCircle(at - tail * k.toDouble(), r * (1 - 0.24 * k), paint);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(r)), paint);
    // The plus draws itself in as the drop arrives.
    final double a = ((p - 0.7) / 0.3).clamp(0.0, 1.0);
    if (a > 0) {
      final Paint line = Paint()
        ..color = ink.withValues(alpha: a)
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round;
      const double l = 9.5;
      canvas
        ..drawLine(at - const Offset(l, 0), at + const Offset(l, 0), line)
        ..drawLine(at - const Offset(0, l), at + const Offset(0, l), line);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.body != body || old.velocity != velocity || old.start != start;
}

/// A blob leaving the button pulls a thread of its own colour behind it.
/// The thread thins as the blob travels and snaps when it arrives.
class _ThreadPainter extends CustomPainter {
  _ThreadPainter({
    required this.from,
    required this.to,
    required this.out,
    required this.colors,
  }) : super(repaint: Listenable.merge(out));
  final Offset from;
  final List<Offset> to;
  final List<SpringValue> out;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < out.length; i++) {
      final double p = out[i].value;
      // Only on the way out: closing, the blobs simply fall back in.
      if (p <= 0.02 || p >= 0.97 || out[i].target < 0.5) {
        continue;
      }
      final Offset at = from + (to[i] - from) * p;
      final double thick = 1.5 + 9 * (1 - p);
      // Thick at the button, thin at the blob.
      final Offset n =
          Offset(-(at - from).dy, (at - from).dx) /
          math.max((at - from).distance, 1);
      canvas.drawPath(
        Path()
          ..moveTo(from.dx + n.dx * thick, from.dy + n.dy * thick)
          ..lineTo(at.dx + n.dx * thick * 0.35, at.dy + n.dy * thick * 0.35)
          ..lineTo(at.dx - n.dx * thick * 0.35, at.dy - n.dy * thick * 0.35)
          ..lineTo(from.dx - n.dx * thick, from.dy - n.dy * thick)
          ..close(),
        Paint()
          ..color = colors[i].withValues(alpha: ((1 - p) * 5).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_ThreadPainter old) => old.from != from;
}
