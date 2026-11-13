import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
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
import 'look.dart';
import 'apps.dart';
import 'bubble.dart';
import 'drawer.dart';
import 'progress_page.dart';
import 'robot.dart';
import 'state.dart';
import 'still_glass.dart';
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

  // What the blobs are: Prism's own actions, or real apps.
  bool get _appBlobs => BlobApps.instance.on.value;
  int get _n => _appBlobs ? BlobApps.instance.apps.length : 5;
  String _blobName(int i) =>
      _appBlobs ? BlobApps.instance.apps[i].name : _actions[i].$1;
  Color _blobColor(int i) =>
      _appBlobs ? BlobApps.instance.apps[i].color : _actions[i].$3;
  void _blobsChanged() {
    if (mounted) {
      setState(() {});
      // The apps' pictures have arrived or the menu changed: the pinned lens may need its picture.
      _sendPin();
    }
  }

  void _pinChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// The name a blob is pinned under.
  String _pinKey(int i) =>
      _appBlobs ? 'app:${BlobApps.instance.apps[i].package}' : 'action:$i';

  /// A long press on a blob pins it: it then floats over the whole phone as a lens.
  /// A long press on the pinned one lets it go again.
  void _blobHold(int i) {
    final String key = _pinKey(i);
    final bool was = RestBubble.instance.pinned.value == key;
    RestBubble.instance.setPin(was ? null : key);
    Haptics.thud();
    Diag.instance.event(was ? 'blob unpinned' : 'blob pinned');
    _sendPin();
    if (!was && !RestBubble.instance.allowed.value) {
      // It cannot float until Android allows it; take the person to where that is granted.
      RestBubble.instance.ask();
    }
  }

  void _sendPinData() {
    // The colours as they are now, not as the last drawn frame had them: this also runs at the
    // moment the theme or the look changes, before anything has been redrawn.
    final bool dark = switch (settings.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      _ =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
    final LumenColors now = dark ? Look.instance.night : Look.instance.day;
    RestBubble.instance.tellData(<String, Object>{
      'light': !dark,
      'haptics': settings.haptics,
      'accent': now.accent.toARGB32(),
      'onAccent': now.onAccent.toARGB32(),
      'weight': fit.weight,
      'left': fit.left,
      'meals': <Map<String, Object>>[
        for (final int m in const <int>[1, 3, 0])
          <String, Object>{
            'i': m,
            'name': FitState.meals[m].$1,
            'what': FitState.meals[m].$2,
            'kcal': FitState.meals[m].$3,
          },
      ],
    });
  }

  /// One of Prism's own icons as a white picture, for the lens to show.
  static Future<Uint8List?> _iconPng(IconData icon) async {
    final ui.PictureRecorder rec = ui.PictureRecorder();
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 104,
          color: Colors.white,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(Canvas(rec), Offset((120 - tp.width) / 2, (120 - tp.height) / 2));
    final ui.Image image = await rec.endRecording().toImage(120, 120);
    return (await image.toByteData(format: ui.ImageByteFormat.png))?.buffer
        .asUint8List();
  }

  /// Tells Android what is pinned, with its name, colour and picture.
  Future<void> _sendPin() async {
    final String? key = RestBubble.instance.pinned.value;
    if (key == null) {
      RestBubble.instance.tellPin(null);
      return;
    }
    final String what = key.substring(key.indexOf(':') + 1);
    String name = '', package = '';
    Color color = const Color(0xFF5A6373);
    int index = 0;
    Uint8List? icon;
    bool picture = false;
    if (key.startsWith('action:')) {
      index = int.tryParse(what) ?? 0;
      name = _actions[index].$1;
      color = _actions[index].$3;
      icon = await _iconPng(_actions[index].$2);
    } else {
      package = what;
      final Iterable<BlobApp> found = BlobApps.instance.apps.where(
        (BlobApp a) => a.package == what,
      );
      if (found.isEmpty) {
        return; // Its app has not been found yet; this runs again when it has.
      }
      final BlobApp a = found.first;
      name = a.name;
      color = a.color;
      final ui.Image? image = a.glyph ?? a.picture ?? a.icon;
      picture = a.glyph == null;
      if (image != null) {
        icon = (await image.toByteData(format: ui.ImageByteFormat.png))?.buffer
            .asUint8List();
      }
    }
    RestBubble.instance.tellPin(<String, Object>{
      'key': key,
      'kind': key.startsWith('action:') ? 'action' : 'app',
      'index': index,
      'package': package,
      'name': name,
      'color': color.toARGB32(),
      'picture': picture,
      'icon': ?icon,
    });
  }

  Widget _blobFace(int i) {
    if (!_appBlobs) {
      return Icon(_actions[i].$2, color: Colors.white, size: 26);
    }
    final BlobApp a = BlobApps.instance.apps[i];
    if (a.glyph != null) {
      return Center(
        child: RawImage(
          image: a.glyph,
          width: 34,
          height: 34,
          filterQuality: FilterQuality.medium,
        ),
      );
    }
    if (a.icon != null) {
      return Center(
        child: ClipOval(
          child: RawImage(
            image: a.picture ?? a.icon,
            width: 36,
            height: 36,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
    }
    return Center(
      child: Text(
        a.name.substring(0, 1),
        textScaler: TextScaler.noScaling,
        style: LumenType.text(24, weight: 700, color: Colors.white, height: 1),
      ),
    );
  }

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
      stiffness: 1500,
      ratio: 0.36,
    ),
  );
  // The way home: quick, and still moving when it gets there, so it lands with a hit.
  static final SpringDescription _fall = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 560,
    ratio: 0.78,
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
    stiffness: 1150,
    ratio: 0.6,
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
  Offset? _downAt, _lastAt;
  final Stopwatch _held = Stopwatch();
  bool _drawerOpen = false, _lifted = false;
  Timer? _liftTimer;
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
    // The pinned thing: what its sheets ask of Prism, and keeping Android told.
    RestBubble.instance
      ..onWeigh = (double kg) {
        fit.weigh((kg * 10).round() / 10);
        Haptics.settle();
      }
      ..onFood = (int meal) {
        fit.addMeal(meal, 1);
        Haptics.settle();
      }
      ..onAction = (int action) {
        if (!mounted) {
          return;
        }
        if (_drawerOpen) {
          _setDrawer(false);
        }
        _run(action);
      }
      ..pinned.addListener(_pinChanged);
    fit.addListener(_sendPinData);
    // The sheets follow Prism's colours, so Android is told whenever those change.
    Look.instance.addListener(_sendPinData);
    settings.addListener(_sendPinData);
    RestBubble.instance.onTheme = _sendPinData;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendPinData();
      _sendPin();
    });
    // Pressing the home button while Prism is the home screen: everything closes and Home shows.
    const MethodChannel('lumen/device')
        .setMethodCallHandler((MethodCall call) async {
          if (RestBubble.instance.handle(call)) {
            Diag.instance.event('floating workout: ${call.method}');
            return;
          }
          if (call.method == 'train' && mounted) {
            // The floating rest timer was tapped: straight to the workout, nothing in the way.
            Diag.instance.event('timer bubble tapped');
            if (_drawerOpen) {
              _setDrawer(false);
            }
            if (_sheetOpen) {
              _closeSheet();
            }
            _setOpen(false);
            if (_tab != 1) {
              _go(1);
            }
          }
          if (call.method == 'home' && mounted) {
            Diag.instance.event('home button');
            if (_drawerOpen) {
              _setDrawer(false);
            }
            if (_sheetOpen) {
              _closeSheet();
            }
            if (_parked || _carrying) {
              _lensHome();
            }
            _setOpen(false);
            if (_tab != 0) {
              _go(0);
            }
          }
        });
    Diag.instance.extraLine = () =>
        'icon engine: ${Apps.instance.summary}\napp blobs: ${BlobApps.instance.apps.map((BlobApp a) => '${a.name} ${a.installed ? a.made : 'not found'} #${a.color.toARGB32().toRadixString(16).substring(2)}').join(', ')}';
    bool appsBefore = true;
    Diag.instance.onTest = (bool testing) {
      // The test taps the blobs; it must not open other apps.
      if (testing) {
        appsBefore = BlobApps.instance.on.value;
        BlobApps.instance.on.value = false;
      } else {
        BlobApps.instance.on.value = appsBefore;
      }
    };
    BlobApps.instance.addListener(_blobsChanged);
    BlobApps.instance.on.addListener(_blobsChanged);
    BlobApps.instance.load();
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
      final double a = math.pi * (0.19 + 0.62 * i / (_n - 1));
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
    // 0. The app drawer: flick it open, drag through two pages and back one, close it.
    await Robot.drag(
      <Offset>[b, b - const Offset(0, 90)],
      legMs: 90,
      flick: true,
      after: 900,
    );
    if (_drawerOpen) {
      final Offset mid = Offset(sc.width / 2, sc.height * 0.55);
      await Robot.drag(
        <Offset>[mid, mid - const Offset(0, 250)],
        legMs: 700,
        after: 500,
      );
      await Robot.drag(
        <Offset>[mid, mid + const Offset(0, 130)],
        legMs: 500,
        after: 500,
      );
      await Robot.tap(b, after: 700);
    }
    if (_drawerOpen) {
      _setDrawer(false);
      await Robot.wait(500);
    }
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
        _wob.jumpTo((speed / 3200).clamp(0.14, 0.3));
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
      // The glass rode above the finger. The drop appears under the finger itself, at the button's size.
      _ly.jumpTo(_ly.value + 62);
      _glass.jumpTo(0);
      _retFrom = Offset(_lx.value, _ly.value);
    }
    _lx.animateTo(_home.dx, spring: _fall);
    _ly.animateTo(_home.dy, spring: _fall);
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
    _lastAt = e.position;
    final Size screen = MediaQuery.sizeOf(context);
    final Offset travel = e.position - _downAt!;
    if (!_moved) {
      if (travel.distance < 10) {
        return;
      }
      _moved = true;
      _setOpen(false);
    }
    if (!_lifted) {
      // Not a lens yet. A quick upward movement is probably a flick for the app drawer, and a
      // flick should not light up the glass or wake the cards. The button only lifts off once
      // the movement is clearly a carry: slow, sideways or downward, or simply held long enough.
      final int ms = _held.elapsedMilliseconds;
      final bool upward = travel.dy < 0 && travel.dx.abs() < -travel.dy * 0.8;
      // A carry needs real evidence: a finger that has been down a while, or one that has gone
      // a fair way sideways or down. A short quick nudge is none of these and lifts nothing.
      final bool carry = ms >= 200 || (!upward && travel.distance > 22);
      if (_drawerOpen || !carry) {
        return;
      }
      _liftOff();
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

  /// The button leaves the bar and becomes the lens.
  void _liftOff() {
    _lifted = true;
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

  void _buttonUp() {
    _liftTimer?.cancel();
    _kick.animateTo(1);
    if (_downAt == null) {
      return;
    }
    final Offset travel = (_lastAt ?? _downAt!) - _downAt!;
    _downAt = null;
    if (_drawerOpen) {
      // While the drawer is up, the button only closes it.
      if (_lifted) {
        _lensQuiet();
      }
      _setDrawer(false);
    } else if (_moved &&
        !_lifted &&
        travel.dy < -26 &&
        travel.dx.abs() < -travel.dy * 0.8) {
      // A quick flick upward, let go before the button ever became a lens: the app drawer.
      _setDrawer(true);
    } else if (!_lifted) {
      // A tap, or a small nudge that was neither a flick nor a carry.
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

  /// Puts the lens away at once, with no flight home. Used when the drag turned out to be a flick.
  void _lensQuiet() {
    setState(() {
      _carrying = false;
      _parked = false;
      _returning = false;
      _target = null;
    });
    _lx.jumpTo(_home.dx);
    _ly.jumpTo(_home.dy);
    _glass.jumpTo(0);
    _morph.jumpTo(0);
    _say.jumpTo(0);
    LensBus.instance.pos.value = null;
  }

  // The bar is solid under the drawer and under sheets. Turning glass back on costs one slow
  // frame, so it waits until the closing animation is over: a slow frame while nothing moves
  // cannot be seen, one in the middle of an animation is a stutter.
  bool _coverHold = false;
  Timer? _coverTimer;
  void _cover(bool up) {
    _coverTimer?.cancel();
    if (up) {
      _coverHold = true;
    } else {
      _coverTimer = Timer(const Duration(milliseconds: 560), () {
        if (mounted && !_drawerOpen && !_sheetOpen) {
          setState(() => _coverHold = false);
        }
      });
    }
  }

  void _setDrawer(bool v) {
    if (v == _drawerOpen) {
      return;
    }
    _setOpen(false);
    _cover(v);
    setState(() => _drawerOpen = v);
    _t.animateTo(v ? 1 : 0);
    Diag.instance
      ..overlay = v ? '+drawer' : ''
      ..event(v ? 'drawer open' : 'drawer close');
    Haptics.settle();
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
    RestBubble.instance.page(tab == 1);
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
      for (int i = 0; i < _n; i++) {
        _fuses.add(
          Timer(
            Duration(milliseconds: i * 18),
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

  /// A blob was tapped. What that means depends on what the blobs are showing.
  void _blobTap(int i) {
    if (_appBlobs) {
      final BlobApp a = BlobApps.instance.apps[i];
      _setOpen(false);
      Diag.instance.event('open ${a.name}');
      // The app opens out of the blob that was tapped.
      final double dpr = MediaQuery.devicePixelRatioOf(context);
      final double angle = math.pi * (0.19 + 0.62 * i / (_n - 1));
      final Offset at =
          _home + Offset(-math.cos(angle), -math.sin(angle)) * _reach;
      BlobApps.instance
          .launch(
            a,
            from: Rect.fromCenter(
              center: at * dpr,
              width: _blob * dpr,
              height: _blob * dpr,
            ),
          )
          .then((bool ok) {
            if (!ok) {
              Haptics.thud();
            }
          });
      return;
    }
    _run(i);
  }

  /// One of Prism's own actions, by its place in the list. Cards on the pages call this too,
  /// so it must never depend on what the blobs currently show.
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
    _cover(true);
    _rise.animateTo(1);
    Diag.instance
      ..overlay = '+sheet'
      ..event('sheet ${_actions[i].$1}');
  }

  void _closeSheet() {
    _cover(false);
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
      final double a = math.pi * (0.19 + 0.62 * i / (_n - 1));
      return bc + Offset(-math.cos(a), -math.sin(a)) * _reach;
    }

    // The system back button undoes the last thing that opened, one step at a time,
    // and only leaves the app from Home with nothing open.
    return PopScope(
      // Prism is a home screen: there is nowhere further back to go, so back never leaves it.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) {
          return;
        }
        if (_drawerOpen) {
          Diag.instance.event('back: close drawer');
          _setDrawer(false);
        } else if (_sheetOpen) {
          Diag.instance.event('back: close sheet');
          _closeSheet();
        } else if (_parked || _carrying) {
          Diag.instance.event('back: lens home');
          _lensHome();
        } else if (_open) {
          Diag.instance.event('back: close blobs');
          _setOpen(false);
        } else if (_tab != 0) {
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
              child: ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[
                  Diag.instance.wallpaperOn,
                  Look.instance,
                ]),
                builder: (BuildContext context, Widget? _) =>
                    Diag.instance.wallpaperOn.value
                    ? _WallpaperImage(
                        dark: c.dark,
                        version: Look.instance.version,
                      )
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
                        Look.instance.frostReady,
                        Diag.instance.wallpaperOn,
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
                        // While the drawer or a sheet is up, the bar sits dimmed underneath it. Glass there
                        // is blurred again on every frame for something nobody is looking at: measured, it
                        // was most of the cost of turning pages in the drawer. So it goes solid meanwhile.
                        final bool covered =
                            _drawerOpen || _sheetOpen || _coverHold;
                        final bool barSolid =
                            off ||
                            covered ||
                            mode == 3 ||
                            (mode == 1 && lensOut);
                        final bool riderSolid =
                            off ||
                            covered ||
                            mode == 3 ||
                            (mode == 1 && (moving || lensOut));
                        final bool solid = barSolid || riderSolid;
                        // Whenever the bar is not real glass, it is still glass: the blurred copy of the
                        // background shows through it, so it keeps its colour and never goes flat.
                        final bool still =
                            barSolid &&
                            !off &&
                            Diag.instance.wallpaperOn.value &&
                            Look.instance.frost != null;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            if (still)
                              Positioned.fill(
                                child: StillGlass(
                                  radius: _barH / 2,
                                  tint: c.glassTint.withValues(alpha: 0.40),
                                  rim: Colors.white.withValues(
                                    alpha: c.dark ? 0.34 : 0.9,
                                  ),
                                  edge: 9,
                                  stamp: Look.instance.frostReady.value,
                                ),
                              ),
                            Positioned.fill(
                              child: Glass(
                                radius: _barH / 2,
                                style: GlassStyle(
                                  blur: 18,
                                  tint: 0.42,
                                  refraction: 30,
                                  bevel: 20,
                                  // In the new styles the solid bar is matched to the glass one, so swapping does not flash.
                                  fallbackColor: still
                                      ? const Color(0x00000000)
                                      : (mode == 0 && !covered
                                            ? c.surfaceHigh
                                            : Color.lerp(
                                                c.bg,
                                                c.surfaceHigh,
                                                0.35,
                                              )),
                                ),
                                hole: solid ? null : shape.deflate(0.5),
                                solid: barSolid,
                                quality: mode == 2 ? GlassQuality.low : null,
                              ),
                            ),
                            if (still)
                              // The lens around the selected tab: clear glass that enlarges what is behind it.
                              Positioned.fromRect(
                                rect: lens,
                                child: StillGlass(
                                  radius: h / 2,
                                  sharp: true,
                                  magnify: 1.22,
                                  edge: 7,
                                  tint: c.accent.withValues(alpha: 0.10),
                                  rim: Colors.white.withValues(
                                    alpha: c.dark ? 0.6 : 0.95,
                                  ),
                                  stamp: Look.instance.frostReady.value,
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
                                  fallbackColor: still
                                      ? const Color(0x00000000)
                                      : (mode == 0 && !covered
                                            ? c.accent.withValues(alpha: 0.3)
                                            : c.ink.withValues(alpha: 0.10)),
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
            // The app drawer, which grows out of the button.
            Positioned.fill(
              child: AppDrawer(
                open: _drawerOpen,
                origin: bc,
                button: _button,
                onClose: () => _setDrawer(false),
              ),
            ),
            // The threads: each blob stays tied to the button until it arrives.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ThreadPainter(
                    from: bc,
                    to: <Offset>[for (int i = 0; i < _n; i++) rest(i)],
                    out: _out,
                    colors: <Color>[for (int i = 0; i < _n; i++) _blobColor(i)],
                  ),
                ),
              ),
            ),
            // The blobs.
            for (int i = 0; i < _n; i++)
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
                          onTap: () => _blobTap(i),
                          onLongPress: () => _blobHold(i),
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
                                          _blobColor(i),
                                          Colors.white,
                                          0.14,
                                        )!,
                                        _blobColor(i),
                                      ],
                                    ),
                                    shape: CircleBorder(
                                      side: BorderSide(
                                        // The pinned blob wears a bright ring: this is the one that floats.
                                        color: Colors.white.withValues(
                                          alpha:
                                              RestBubble
                                                      .instance
                                                      .pinned
                                                      .value ==
                                                  _pinKey(i)
                                              ? 0.95
                                              : 0.2,
                                        ),
                                        width:
                                            RestBubble.instance.pinned.value ==
                                                _pinKey(i)
                                            ? 2.5
                                            : 1,
                                      ),
                                    ),
                                  ),
                                  child: _blobFace(i),
                                ),
                              ),
                              const SizedBox(height: 7),
                              // The name appears once the blob is nearly there, not while it is a speck.
                              Opacity(
                                opacity: ((p - 0.6) / 0.4).clamp(0.0, 1.0),
                                child: Text(
                                  _blobName(i),
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
                    _lastAt = e.position;
                    _held
                      ..reset()
                      ..start();
                    _moved = false;
                    _lifted = false;
                    // A finger that moved and then stopped sends no more movement, so the wait is also timed.
                    _liftTimer?.cancel();
                    _liftTimer = Timer(const Duration(milliseconds: 200), () {
                      if (_downAt != null &&
                          _moved &&
                          !_lifted &&
                          !_drawerOpen &&
                          mounted) {
                        _liftOff();
                        final Offset at = _lastAt ?? _home;
                        _lx.animateTo(at.dx);
                        _ly.animateTo(at.dy - 62);
                      }
                    });
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
              // Tall enough to hold everything on a large phone, and it scrolls on a small one.
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.88,
              ),
              child: ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[
                  settings,
                  Diag.instance.wallpaperOn,
                  Look.instance,
                ]),
                builder: (BuildContext context, Widget? _) => SingleChildScrollView(
                  child: Column(
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
                      Text('Colour', style: LumenType.label(color: c.inkMuted)),
                      const SizedBox(height: 8),
                      // Room at both ends for the ring around the chosen colour, which sits outside its circle.
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 3,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            for (final double h in Look.hues)
                              Pressable(
                                onTap: () {
                                  Look.instance.choose(hue: h);
                                  Haptics.tick();
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: ShapeDecoration(
                                    color: Look.accentFor(h, c.dark),
                                    shape: CircleBorder(
                                      side: BorderSide(
                                        color: Look.instance.hue == h
                                            ? c.ink
                                            : Colors.transparent,
                                        width: 2.5,
                                        strokeAlign:
                                            BorderSide.strokeAlignOutside,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Background',
                        style: LumenType.label(color: c.inkMuted),
                      ),
                      const SizedBox(height: 8),
                      Segmented<int>(
                        values: const <int>[0, 1, 2],
                        labels: Look.vibes,
                        value: Look.instance.vibe,
                        onChanged: (int v) => Look.instance.choose(vibe: v),
                      ),
                      if (Look.instance.vibe != 0) ...<Widget>[
                        const SizedBox(height: 10),
                        Segmented<int>(
                          values: const <int>[0, 1, 2, 3],
                          labels: Look.patterns,
                          value: Look.instance.pattern,
                          onChanged: (int v) =>
                              Look.instance.choose(pattern: v),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text('Theme', style: LumenType.label(color: c.inkMuted)),
                      const SizedBox(height: 8),
                      // System follows the phone: light by day and dark by night, if that is how the phone is set.
                      Segmented<ThemeMode>(
                        values: const <ThemeMode>[
                          ThemeMode.system,
                          ThemeMode.light,
                          ThemeMode.dark,
                        ],
                        labels: const <String>['System', 'Light', 'Dark'],
                        value: settings.themeMode,
                        onChanged: (ThemeMode v) => Look.instance.theme(v),
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
                        label: 'Background lights',
                        value: Diag.instance.wallpaperOn.value,
                        onChanged: (bool v) =>
                            Diag.instance.wallpaperOn.value = v,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Glass style (Auto and Orig.: real glass, shows what scrolls under it. Event: still glass, cheaper, shows only the background)',
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
                      const SizedBox(height: 12),
                      ListenableBuilder(
                        listenable: RestBubble.instance.allowed,
                        builder: (BuildContext context, Widget? _) =>
                            SwitchLine(
                              label: 'Workout floats over other apps',
                              value: RestBubble.instance.allowed.value,
                              // Android decides this, on its own screen. The switch only takes you there.
                              onChanged: (bool _) => RestBubble.instance.ask(),
                            ),
                      ),
                      const SizedBox(height: 12),
                      ListenableBuilder(
                        listenable: BlobApps.instance.on,
                        builder: (BuildContext context, Widget? _) =>
                            SwitchLine(
                              label: 'Blobs open real apps',
                              value: BlobApps.instance.on.value,
                              onChanged: (bool v) =>
                                  BlobApps.instance.on.value = v,
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
                      Text(
                        'Testing',
                        style: LumenType.label(color: c.inkMuted),
                      ),
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
    final Look look = Look.instance;
    final Color ground = (dark ? look.night : look.day).bg;
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    // A glow: many faint discs laid on top of each other, smallest last, so it
    // falls off smoothly without relying on how a renderer handles gradients.
    void glow(Offset at, double r, Color col, double a) {
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

    // Where things go: low down, where the glass bar sits over them, and off the top corner,
    // clear of titles and of the numbers people read.
    final List<(Offset, double)> places = <(Offset, double)>[
      (Offset(size.width * 0.04, size.height * 0.86), size.width * 0.40),
      (Offset(size.width * 1.02, size.height * 0.10), size.width * 0.22),
      (Offset(size.width * 0.70, size.height * 0.955), size.width * 0.075),
    ];
    final bool flow = look.vibe != 1, pattern = look.vibe != 0;
    final double w = size.width, h = size.height;
    final double strong = dark ? 1.0 : 1.25;
    Paint line(Color col, double a, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = col.withValues(alpha: (a * strong).clamp(0.0, 1.0));
    Paint fill(Color col, double a) =>
        Paint()..color = col.withValues(alpha: (a * strong).clamp(0.0, 1.0));

    // The glows come first: they are the light every pattern is drawn in.
    for (final (Offset at, double r) in places) {
      glow(at, r * 2.3, look.mid, dark ? 0.26 : 0.20);
    }
    if (pattern && look.pattern == 1) {
      // Contours: lines like the height lines on a map, or wind on sand. Each follows the one
      // before it but drifts a little, and they swell where the light is.
      const int lines = 30;
      for (int i = 0; i < lines; i++) {
        final double t = i / (lines - 1);
        final double y0 = h * (-0.04 + 1.08 * t);
        final Path p = Path();
        for (int k = 0; k <= 48; k++) {
          final double x = w * k / 48, u = k / 48;
          // Taller waves low on the left, where the large light is; calmer toward the top right.
          final double swell = 0.35 + 1.25 * t * (1 - u * 0.55);
          final double y =
              y0 +
              h * 0.020 * swell * math.sin(u * 2 * math.pi * 1.15 + i * 0.36) +
              h * 0.008 * swell * math.sin(u * 2 * math.pi * 2.9 - i * 0.23);
          if (k == 0) {
            p.moveTo(x, y);
          } else {
            p.lineTo(x, y);
          }
        }
        canvas.drawPath(
          p,
          line(
            Color.lerp(look.light, look.deep, t)!,
            0.10 + 0.20 * t,
            w / 420 * (0.8 + t),
          ),
        );
      }
    } else if (pattern && look.pattern == 2) {
      // Arcs: a few large, plain shapes, each a part of a circle, overlapping like cut paper.
      // Big quiet areas first, then the thin rings that tie them together.
      canvas
        ..drawCircle(Offset(0, h), w * 0.80, fill(look.mid, 0.15))
        ..drawCircle(Offset(w, h * 0.40), w * 0.30, fill(look.deep, 0.24))
        ..drawCircle(Offset(w, 0), w * 0.36, fill(look.light, 0.10))
        ..drawCircle(
          Offset(w * 0.24, h * 0.215),
          w * 0.062,
          fill(look.light, 0.26),
        )
        ..drawArc(
          Rect.fromCircle(center: Offset(0, h), radius: w * 1.00),
          -math.pi / 2,
          math.pi / 2,
          false,
          line(look.light, 0.20, w * 0.050),
        )
        ..drawArc(
          Rect.fromCircle(center: Offset(0, h), radius: w * 1.17),
          -math.pi / 2,
          math.pi / 2,
          false,
          line(look.light, 0.30, w * 0.006),
        )
        ..drawArc(
          Rect.fromCircle(center: Offset(w, h * 0.40), radius: w * 0.41),
          math.pi / 2,
          math.pi,
          false,
          line(look.light, 0.20, w * 0.028),
        )
        ..drawArc(
          Rect.fromCircle(center: Offset(w, h * 0.40), radius: w * 0.50),
          math.pi / 2,
          math.pi,
          false,
          line(look.mid, 0.30, w * 0.005),
        )
        ..drawCircle(
          Offset(w * 0.24, h * 0.215),
          w * 0.105,
          line(look.light, 0.30, w * 0.005),
        )
        ..drawArc(
          Rect.fromCircle(center: Offset(w, 0), radius: w * 0.47),
          math.pi / 2,
          math.pi / 2,
          false,
          line(look.mid, 0.26, w * 0.005),
        );
    } else if (pattern && look.pattern == 3) {
      // Weave: two sets of fine straight lines at slightly different slants. Where they cross
      // they make slow bands of their own, like silk held to the light. Nothing is drawn to
      // make the bands; they come from the crossing.
      final double gap = w / 34;
      final Paint a = line(look.light, 0.13, w / 520),
          b = line(look.mid, 0.13, w / 520);
      for (double d = -h; d < w + h; d += gap) {
        canvas.drawLine(Offset(d, 0), Offset(d + h * 0.92, h), a);
      }
      for (double d = -h; d < w + h; d += gap * 1.045) {
        canvas.drawLine(Offset(d, 0), Offset(d + h * 0.80, h), b);
      }
    } else if (pattern) {
      // Ripples: rings spreading from where the lights are, each a little further from the last
      // and a little fainter, as on water. A fine grain of dots lies under them.
      final Paint dot = fill(look.mid, 0.15);
      final double gap = w / 15;
      for (double y = gap / 2; y < h; y += gap) {
        for (double x = gap / 2; x < w; x += gap) {
          canvas.drawCircle(Offset(x, y), w / 440, dot);
        }
      }
      for (final (Offset at, double r) in places) {
        double rr = r * (flow ? 1.08 : 0.34);
        for (int k = 0; k < 9; k++) {
          canvas.drawCircle(
            at,
            rr,
            line(
              look.light,
              0.36 * math.pow(1 - k / 9.5, 1.4),
              w / 300 * (1.5 - k / 9),
            ),
          );
          rr += r * 0.17 * math.pow(1.2, k);
        }
      }
    }
    if (flow) {
      for (final (Offset at, double r) in places) {
        // An orb: discs shrinking toward a highlight up and to the left, as on a lit sphere,
        // shading from the deeper neighbour colour through the colour itself to the lighter one.
        const int steps = 56;
        for (int i = 0; i < steps; i++) {
          final double t = i / (steps - 1);
          final Color col = Color.lerp(
            Color.lerp(look.deep, look.mid, (t * 2).clamp(0.0, 1.0))!,
            look.light,
            ((t - 0.5) * 2).clamp(0.0, 1.0),
          )!;
          canvas.drawPath(
            Path()..addOval(
              Rect.fromCircle(
                center: at + Offset(-r, -r) * (0.3 * t),
                radius: r * (1 - 0.82 * t),
              ),
            ),
            Paint()..color = col,
          );
        }
      }
    }
    // Text sits straight on this picture on some pages, so the whole of it is held back a little.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = ground.withValues(alpha: flow ? 0.30 : 0.12),
    );
  }

  @override
  bool shouldRepaint(_Wallpaper old) => old.dark != dark;
}

/// The wallpaper, drawn once into a small picture and then shown stretched.
/// Drawing the soft lights live cost the phone about half its frames; a
/// picture costs almost nothing, and the stretching smooths the lights.
class _WallpaperImage extends StatefulWidget {
  const _WallpaperImage({required this.dark, required this.version});
  final bool dark;

  /// Which look this picture is for. A new number means: draw it again, once.
  final int version;

  @override
  State<_WallpaperImage> createState() => _WallpaperImageState();
}

class _WallpaperImageState extends State<_WallpaperImage> {
  ui.Image? _image;
  Size _size = Size.zero;
  bool? _dark;
  int _version = -1;

  Future<void> _render(Size size, bool dark) async {
    _size = size;
    _dark = dark;
    _version = widget.version;
    final Size small = Size(
      (size.width / (Look.instance.vibe == 0 ? 2 : 1.4)).ceilToDouble(),
      (size.height / (Look.instance.vibe == 0 ? 2 : 1.4)).ceilToDouble(),
    );
    final ui.PictureRecorder rec = ui.PictureRecorder();
    _Wallpaper(dark).paint(Canvas(rec), small);
    final ui.Picture pic = rec.endRecording();
    final ui.Image img = await pic.toImage(
      small.width.toInt(),
      small.height.toInt(),
    );
    pic.dispose();
    // The same picture, blurred once. Every piece of still glass shows a part of this.
    final ui.PictureRecorder rec2 = ui.PictureRecorder();
    // The same softness as the real glass bar (18 on the screen), scaled to this smaller picture,
    // so still glass and real glass look alike.
    final double sigma = 18 * small.width / size.width;
    Canvas(rec2).drawImage(
      img,
      Offset.zero,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        ),
    );
    final ui.Picture pic2 = rec2.endRecording();
    final ui.Image frost = await pic2.toImage(
      small.width.toInt(),
      small.height.toInt(),
    );
    pic2.dispose();
    if (!mounted) {
      img.dispose();
      frost.dispose();
      return;
    }
    Look.instance
      ..crisp = img
      ..frost = frost
      ..frostScreen = size
      ..frostReady.value += 1;
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
        if (size != _size ||
            widget.dark != _dark ||
            widget.version != _version) {
          _render(size, widget.dark);
        }
        return ColoredBox(
          color: widget.dark ? Look.instance.night.bg : Look.instance.day.bg,
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
    final double r = body.shortestSide / 2;
    final double speed = velocity.distance;
    if (body.width > body.height * 1.25) {
      // Still a pill, just let go of: it rounds up as it leaves.
      canvas.drawRRect(
        RRect.fromRectAndRadius(body, Radius.circular(r)),
        paint,
      );
    } else {
      // One drop, no tail. It appears small and swells in the first stretch of the way,
      // and is pulled long by its own speed, thinner as it gets longer, as liquid is.
      final double grow =
          0.55 + 0.45 * Curves.easeOut.transform((p / 0.14).clamp(0.0, 1.0));
      final double st = (speed / 3600).clamp(0.0, 0.42);
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(speed < 1 ? 0 : velocity.direction)
        ..drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: 2 * r * grow * (1 + st),
            height: 2 * r * grow * (1 - st * 0.45),
          ),
          paint,
        )
        ..restore();
    }
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
    for (int i = 0; i < to.length; i++) {
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
  bool shouldRepaint(_ThreadPainter old) =>
      old.from != from ||
      old.to.length != to.length ||
      old.colors.first != colors.first;
}
