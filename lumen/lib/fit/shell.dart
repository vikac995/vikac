import 'dart:async';
import 'dart:io';
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
import 'gestures.dart';
import 'home_page.dart';
import 'lens.dart';
import 'long_test.dart';
import 'look.dart';
import 'apps.dart';
import 'blob_sign.dart';
import 'bubble.dart';
import 'drawer.dart';
import 'progress_page.dart';
import 'recorder.dart';
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

class _ShellState extends State<Shell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ---- Giving memory back.
  // Prism is a home screen: it must be there all day. Android closes apps that hold a lot of
  // memory when they are out of sight. So whatever can be made again is let go: when Android
  // asks, and when Prism has been out of sight for two minutes.
  Timer? _freeLater;

  void _freeMemory() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    _imagePngs.clear();
    _markPngs.clear();
    Diag.instance.event('memory given back');
  }

  @override
  void didHaveMemoryPressure() => _freeMemory();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _freeLater?.cancel();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _freeLater = Timer(const Duration(minutes: 2), _freeMemory);
    }
  }

  /// Every setting as it is now, a few lines, for reports.
  List<String> _settingsNow() {
    final RestBubble b = RestBubble.instance;
    String onOff(bool v) => v ? 'on' : 'off';
    return <String>[
      '  colour ${Look.instance.hue.round()}  ·  background ${Look.vibes[Look.instance.vibe]}${Look.instance.vibe != 0 ? ' ${Look.instance.pattern}' : ''}  ·  theme ${settings.themeMode.name}',
      '  frame-rate readout ${onOff(settings.showFps)}  ·  haptics ${onOff(settings.haptics)}  ·  reduce transparency ${onOff(settings.reduceTransparency)}  ·  background lights ${onOff(Diag.instance.wallpaperOn.value)}',
      '  glass style ${const <String>['Orig.', 'One', 'Frost', 'Event', 'Auto'][Diag.instance.glassMode.value.clamp(0, 4)]}${Diag.instance.glassMode.value == 4 ? ' (now ${const <String>['Orig.', 'One', 'Frost', 'Event'][Diag.instance.autoLevel.value.clamp(0, 3)]})' : ''}  ·  glass quality ${settings.quality.name}  ·  Prism icons: app list ${onOff(Apps.instance.prismIcons)}, blobs ${onOff(Apps.instance.blobPrismIcons)}',
      '  floats over other apps ${onOff(b.allowed.value)}  ·  lens is a container ${onOff(b.container.value)}  ·  notification counts ${onOff(Notes.instance.allowed.value)}  ·  blobs open real apps ${onOff(BlobApps.instance.on.value)}',
      '  blob: in Prism ${onOff(b.floatIn.value)}  ·  over other apps ${onOff(b.floatOut.value)}  ·  labels ${onOff(BlobSlots.instance.names)}  ·  floating ${b.pinned.value ?? 'nothing'}',
      '  blobs: ${<String>[for (int i = 0; i < _n; i++) _pinKey(i)].join(', ')}',
      '  swipes: ${<String>[for (int g = 0; g < 4; g++) '${GestureSlots.names[g]} ${GestureSlots.instance.keys[g]}'].join(', ')}',
    ];
  }

  /// What Prism's side holds in pictures, in bytes: the picture cache, and the apps' icons.
  (int cache, int icons) _pictureBytes() {
    int icons = 0;
    int of(ui.Image? i) => i == null ? 0 : i.width * i.height * 4;
    for (final AppTile t in Apps.instance.all) {
      icons += of(t.glyph) + of(t.picture);
    }
    for (final BlobApp a in BlobApps.instance.apps) {
      icons += of(a.glyph) + of(a.icon) + of(a.picture);
    }
    return (PaintingBinding.instance.imageCache.currentSizeBytes, icons);
  }

  static const double _barH = 66, _button = 64, _blob = 62, _reach = 178;
  int _tab = 0;
  double _barW = 0;
  bool _open = false;
  int? _sheet; // index into _actions

  // What the blobs are. Prism starts with its own actions or five real apps; any one of the
  // five places can then be given something else, an action or an app, by editing.
  bool get _appBlobs => BlobApps.instance.on.value;
  int get _n => 5;

  /// Whether place [i] holds nothing: its blob was taken away. It is then not among the blobs.
  /// While they are being changed it is shown, as an outline in the middle of the screen, and
  /// a tap on it there gives it something again.
  bool _isEmpty(int i) => _pinKey(i).startsWith('empty:');

  // How far each place is out in the middle of the screen as an empty place: 0 among the
  // blobs, 1 out there. Only on the way does anything move; out there it is drawn and left.
  late final List<SpringValue> _gone = <SpringValue>[
    for (int i = 0; i < 5; i++)
      SpringValue(this, value: 0, spring: Motions.spatialFast),
  ];
  // A place that has just been given something: it comes down from the middle to join the others.
  int? _joinI;

  /// The red minus on a blob was tapped: its place is empty. What is left closes ranks, and
  /// the empty place goes to the middle of the screen, where it can be given something else.
  // Where each empty place stands across the middle, from the middle of the screen. The empty
  // places are always centred as a group: one alone is in the middle, the next joins it and
  // both move over, and so on.
  late final List<SpringValue> _midX = <SpringValue>[
    for (int i = 0; i < 5; i++)
      SpringValue(this, value: 0, spring: Motions.spatialFast),
  ];

  void _recentre({bool jump = false}) {
    final List<int> empty = <int>[
      for (int i = 0; i < _n; i++)
        if (_isEmpty(i)) i,
    ];
    for (int k = 0; k < empty.length; k++) {
      final double x = (k - (empty.length - 1) / 2) * 74.0;
      // One that is only now on its way out goes straight to its spot.
      if (jump || _gone[empty[k]].value < 0.05) {
        _midX[empty[k]].jumpTo(x);
      } else {
        _midX[empty[k]].animateTo(x);
      }
    }
  }

  /// The blobs that would come out of the button, for its sign: where each sits and its colour.
  List<(double, Color)> get _fanBlobs => <(double, Color)>[
    for (int i = 0; i < _n; i++)
      if (!_floating(i) && !_isEmpty(i))
        (_seatAngle(_seat[i].target), _blobColor(i)),
  ];

  // How far the button's X has turned into the cog: 0 the X, 1 the cog.
  late final SpringValue _cog = SpringValue(
    this,
    value: 0,
    spring: Motions.spatialFast,
  );

  // The cog showing itself off, once: a turn that settles and one glint round the button's rim.
  // It runs for well under a second and then nothing moves. Only the first few times.
  late final AnimationController _cogHint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: 1,
  );

  // How far the button's sign has turned, in radians: see [_ButtonSign].
  late final SpringValue _signTurn = SpringValue(this, spring: Motions.snappy);

  // The bouncy shot of a sign that does not turn: how far it has jumped up out of its place
  // (it starts with a kick and springs back, a little past). At rest 0, and nothing runs.
  late final SpringValue _signShot = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );

  // What was open when the sign was last told: 0 nothing, 1 the blobs, 2 the app list.
  int _signWas = 0;

  /// The cog is the button's sign only while the blobs are out and being changed.
  void _signSync() {
    final int now = _drawerOpen ? 2 : (_open ? 1 : 0);
    if (BlobSign.of(Apps.instance.blobLook).turns) {
      _signTurn.animateTo(now == 2 ? math.pi : (now == 1 ? math.pi / 3 : 0));
    } else {
      // The others stay pointing up, and shoot out a little as something opens.
      _signTurn.animateTo(0);
      if (now != 0 && now != _signWas) {
        _signShot.animateTo(0, velocity: 14);
      }
    }
    _signWas = now;
    final bool want = _editing && _open;
    if (want && _cog.target != 1 && Apps.instance.takeCogHint()) {
      _cogHint.forward(from: 0);
    }
    _cog.animateTo(want ? 1 : 0);
  }

  void _removeBlob(int i) {
    Haptics.thud();
    Diag.instance.event('blob removed');
    _gone[i].animateTo(1);
    BlobSlots.instance.put(i, 'empty:');
    _reseat();
    _recentre();
  }

  /// Whether place [i] holds something of the phone's own: its notifications.
  bool _isPhone(int i) => _pinKey(i).startsWith('phone:');

  /// Whether place [i] holds an app, rather than one of Prism's own actions or pages.
  bool _isApp(int i) => _pinKey(i).startsWith('app:');

  /// Whether place [i] holds one of Prism's own pages, and which.
  bool _isScreen(int i) => _pinKey(i).startsWith('screen:');
  int _screenAt(int i) =>
      (int.tryParse(_pinKey(i).substring(7)) ?? 0).clamp(0, _tabs.length - 1);

  /// The colour of the mark on Prism's own colour: dark on a light one, white on a dark one.
  Color _onAccent() {
    final LumenColors c = LumenColors.of(context);
    return c.accent.computeLuminance() > 0.45
        ? const Color(0xFF15171C)
        : Colors.white;
  }

  /// Which of Prism's actions place [i] holds.
  int _actionAt(int i) => (int.tryParse(_pinKey(i).substring(7)) ?? 0).clamp(
    0,
    _actions.length - 1,
  );

  /// The app in place [i] as one of the five Prism knows by heart, if it is one.
  BlobApp? _blobApp(int i) {
    final String package = _pinKey(i).substring(4);
    for (final BlobApp a in BlobApps.instance.apps) {
      if (a.package == package) {
        return a;
      }
    }
    return null;
  }

  /// The app in place [i] as it is in the drawer, if it is any other app.
  AppTile? _tile(int i) {
    final String package = _pinKey(i).substring(4);
    for (final AppTile t in Apps.instance.all) {
      if (t.package == package) {
        return t;
      }
    }
    return null;
  }

  String _blobName(int i) => _isEmpty(i)
      ? ''
      : _isPhone(i)
      ? 'Notifications'
      : _isApp(i)
      ? (_blobApp(i)?.name ?? _tile(i)?.label ?? '')
      : (_isScreen(i) ? _tabs[_screenAt(i)].$2 : _actions[_actionAt(i)].$1);
  // A page of Prism's is in Prism's own colour, whatever that is at the moment.
  Color _blobColor(int i) => _isEmpty(i)
      ? const Color(0x00000000)
      : _isPhone(i)
      ? const Color(0xFF5A6373)
      : _isApp(i)
      ? (_blobApp(i)?.color ?? _tile(i)?.color ?? const Color(0xFF5A6373))
      : (_isScreen(i)
            ? LumenColors.of(context).accent
            : _actions[_actionAt(i)].$3);

  /// The package an app's notifications come under. One known only by the name on the home
  /// screen has them under its real package.
  String _notesPackage(String package) {
    if (package.startsWith('label:')) {
      final String name = package.substring(6).toLowerCase();
      for (final AppTile t in Apps.instance.all) {
        if (t.label.toLowerCase() == name) {
          return t.package;
        }
      }
      return '';
    }
    return package;
  }

  /// How many notifications the app in place [i] has. Nothing for actions and pages.
  int _blobNotes(int i) =>
      _isApp(i) ? Notes.instance.of(_notesPackage(_pinKey(i).substring(4))) : 0;

  // Changing the blobs: hold any one of them. Every blob then wears an edit mark, and a tap on
  // one brings up the app drawer to choose what takes its place. The X, a tap elsewhere, or
  // back ends it.
  bool _editing = false;
  int? _editSlot;

  void _setEditing(bool v) {
    if (v == _editing) {
      return;
    }
    if (!v && _dragI != null) {
      // One of them is in the hand: it is put down among the others first.
      _blobDrop(_dragI!, _home, Offset.zero);
    }
    setState(() => _editing = v);
    _signSync();
    v ? Haptics.settle() : Haptics.tick();
    Diag.instance.event(v ? 'blobs: editing' : 'blobs: done editing');
  }

  /// While editing, a blob was tapped: the drawer comes up to choose what takes its place.
  void _pickFor(int i) {
    Haptics.tick();
    Diag.instance.event('blob: change');
    setState(() => _editSlot = i);
    _setDrawer(true);
  }

  // The two-finger swipes. One recogniser for the whole of Prism, made once.
  late final Map<Type, GestureRecognizerFactory>
  _twoFingers = <Type, GestureRecognizerFactory>{
    TwoFingerSwipe: GestureRecognizerFactoryWithHandlers<TwoFingerSwipe>(
      () => TwoFingerSwipe(
        onSwipe: _twoFinger,
        // Only where a swipe means something: on a page with nothing open, or while
        // the blobs are being changed, where it chooses which swipe to set up.
        wanted: () =>
            mounted &&
            !_drawerOpen &&
            !_sheetOpen &&
            !_carrying &&
            !_parked &&
            _dragI == null &&
            (!_open || _editing),
      ),
      (TwoFingerSwipe _) {},
    ),
  };

  /// Two fingers went [way]: 0 down, 1 up, 2 left, 3 right.
  void _twoFinger(int way) {
    if (_open && _editing) {
      _pickGesture(way);
    } else if (!_open) {
      _useGesture(way);
    }
  }

  /// While the blobs are being changed, a swipe was made or its place tapped: the drawer comes
  /// up to choose what that swipe does.
  void _pickGesture(int g) {
    Haptics.tick();
    Diag.instance.event('gesture ${GestureSlots.names[g]}: change');
    setState(() => _editSlot = 100 + g);
    _setDrawer(true);
  }

  /// Does what the swipe [g] has been given. One that has been given nothing does nothing.
  void _useGesture(int g) {
    final int i = 100 + g;
    if (_isEmpty(i)) {
      return;
    }
    Diag.instance.event('gesture ${GestureSlots.names[g]}: ${_blobName(i)}');
    if (_isPhone(i)) {
      Haptics.settle();
      GestureSlots.shade().then((bool ok) {
        if (!ok) {
          Haptics.thud();
        }
      });
    } else if (_isScreen(i)) {
      Haptics.settle();
      _go(_screenAt(i));
    } else if (_isApp(i)) {
      final BlobApp? a = _blobApp(i);
      final AppTile? t = _tile(i);
      final Size screen = MediaQuery.sizeOf(context);
      final double dpr = MediaQuery.devicePixelRatioOf(context);
      // The app opens out of the middle of the screen.
      final Rect from = Rect.fromCenter(
        center: screen.center(Offset.zero) * dpr,
        width: _blob * dpr,
        height: _blob * dpr,
      );
      Haptics.settle();
      if (a != null) {
        BlobApps.instance.launch(a, from: from).then((bool ok) {
          if (!ok) {
            Haptics.thud();
          }
        });
      } else if (t != null) {
        Apps.instance.launch(t, from: from);
      } else {
        Haptics.thud();
      }
    } else {
      _run(_actionAt(i));
    }
  }

  /// Something was chosen in the drawer for the place being changed.
  void _picked(String key) {
    final int? i = _editSlot;
    if (i != null && i >= 100) {
      GestureSlots.instance.put(i - 100, key);
      Diag.instance.event('gesture ${GestureSlots.names[i - 100]} set');
      _setDrawer(false);
      return;
    }
    if (i != null) {
      // An empty place given something comes down from the middle to join the others.
      _joinI = _isEmpty(i) ? i : null;
      BlobSlots.instance.put(i, key);
      Diag.instance.event(_joinI == null ? 'blob replaced' : 'blob added');
    }
    _setDrawer(false);
  }

  /// A notification came or went. Only blobs that are out need drawing again; Android's own
  /// lens reads the numbers for itself, so nothing is sent anywhere.
  void _notesChanged() {
    if (mounted && _open) {
      setState(() {});
    }
  }

  void _appsChanged() {
    // Only places that hold an app from the drawer take their look from it.
    if (_appBlobs ||
        BlobSlots.instance.keys.any(
          (String? k) => k != null && k.startsWith('app:'),
        )) {
      _blobsChanged();
    }
  }

  void _blobsChanged() {
    if (mounted) {
      setState(() {});
      // The apps' pictures have arrived or the menu changed: the pinned lens may need its picture,
      // and the floating lens's own menu shows these same blobs.
      _sendPin();
      _sendBlobs();
      _reseat();
      _recentre();
    }
  }

  void _pinChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    // What floats is out of the menu, and what has stopped floating is back in it.
    _reseat();
    if (_open) {
      for (int i = 0; i < _n; i++) {
        if (_floating(i)) {
          _out[i].animateTo(0, spring: Motions.spatialFast);
        } else if (_out[i].target < 0.5 && _shotI != i) {
          _out[i].animateTo(1, spring: _shoot);
        }
      }
    }
    // The floating lens's own menu holds the same blobs.
    _sendBlobs();
  }

  // Where each blob sits along the fan, counted in places from the middle. With all five in,
  // they sit at -2 to 2. A blob that is floating as the lens is out of the menu, and so is one
  // that has been dragged away from it: the ones left close ranks around the middle, so that
  // four in the menu looks like a way it can stay, not a gap waiting to be filled.
  late final List<SpringValue> _seat = <SpringValue>[
    for (int i = 0; i < 5; i++)
      SpringValue(this, value: i - 2.0, spring: Motions.spatialFast),
  ];
  final Set<int> _seated = <int>{0, 1, 2, 3, 4};
  // The blob that has been picked up out of the others, if one has.
  int? _awayI;
  // How far from the button the blobs sit. With their names switched off they sit a little
  // nearer: there is nothing under them to make room for.
  static const double _reachBare = 156;
  late final SpringValue _far = SpringValue(
    this,
    value: _reach,
    spring: Motions.spatialFast,
  );

  /// Shows or hides the names under the blobs. The blobs move in or out to suit.
  void _setNames(bool v) {
    Haptics.tick();
    Diag.instance.event(v ? 'blob names on' : 'blob names off');
    BlobSlots.instance.setNames(v);
    _far.animateTo(v ? _reach : _reachBare);
    _tellFan();
    setState(() {});
  }

  /// The side Blob was dropped on the button: the button takes it in, with one small gulp.
  void _fused() {
    if (!mounted) {
      return;
    }
    Haptics.thud();
    Diag.instance.event('side blob fused with the button');
    _kick
      ..jumpTo(0.8)
      ..animateTo(1, spring: Motions.expressiveFast);
  }

  /// While the blobs are out Android knows where they sit, so a lens let go among them is put back.
  void _tellFan() {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    // (And where the button itself is, always: the side Blob dropped on it fuses with it.)
    RestBubble.instance.tellButton(_home * dpr);
    RestBubble.instance.tellFan(
      _open
          ? <double>[
              _home.dx * dpr,
              _home.dy * dpr,
              (_far.target - 58) * dpr,
              (_far.target + 62) * dpr,
              // How far round from straight up still counts as among them (as a cosine).
              math.cos(math.pi * (0.155 * _reach / _far.target) * 2.75),
            ]
          : null,
    );
  }

  /// Where the floating elements may be seen. Opened from the cog on the button.
  void _showFloating() {
    Haptics.tick();
    Diag.instance.event('floating elements: settings');
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: panelTime,
      transitionBuilder: panelNoFade,
      pageBuilder: (BuildContext context, _, _) {
        final LumenColors c = LumenColors.of(context);
        final RestBubble b = RestBubble.instance;
        return PanelRise(
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
                    b.floatIn,
                    b.floatOut,
                    Apps.instance,
                  ]),
                  builder: (BuildContext context, Widget? _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Its name, and a plain way out: the round X in the corner.
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Blob',
                              style: LumenType.display(
                                22,
                                weight: 700,
                                color: c.ink,
                              ),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Close',
                            child: GestureDetector(
                              key: Robot.key('floatClose'),
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchLine(
                        key: Robot.key('floatIn'),
                        label: 'In Prism',
                        value: b.floatIn.value,
                        onChanged: (bool v) => _setFloating(inPrism: v),
                      ),
                      const SizedBox(height: 12),
                      SwitchLine(
                        key: Robot.key('floatOut'),
                        label: 'Over other apps',
                        value: b.floatOut.value,
                        onChanged: (bool v) => _setFloating(overApps: v),
                      ),
                      const SizedBox(height: 12),
                      // The blobs' own choice; the app list has its own, behind its cog.
                      // Two choices of two each: the glass segmented picker, as everywhere.
                      Text(
                        'Icons',
                        style: LumenType.text(15, weight: 560, color: c.ink),
                      ),
                      const SizedBox(height: 8),
                      Segmented<bool>(
                        values: const <bool>[true, false],
                        labels: const <String>['Prism', 'Regular'],
                        value: Apps.instance.blobPrismIcons,
                        onChanged: (bool v) =>
                            Apps.instance.setPrismIcons(v, blobs: true),
                      ),
                      const SizedBox(height: 16),
                      // Vivid: black glass and colours at full strength. Mellow: as before.
                      Text(
                        'Colours',
                        style: LumenType.text(15, weight: 560, color: c.ink),
                      ),
                      const SizedBox(height: 8),
                      Segmented<bool>(
                        key: Robot.key('blobVivid'),
                        values: const <bool>[false, true],
                        labels: const <String>['Mellow', 'Vivid'],
                        value: Apps.instance.blobVivid,
                        onChanged: (bool v) {
                          Apps.instance.setBlobVivid(v);
                          RestBubble.instance.tellVivid(v);
                          Diag.instance.event(v ? 'blob vivid' : 'blob mellow');
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      // The Blob's sign, on the button here and on the floating blob over other
                      // apps: each look drawn as it will be, with these blobs' own colours.
                      Text(
                        'Look',
                        style: LumenType.text(15, weight: 560, color: c.ink),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 12,
                        children: <Widget>[
                          for (final BlobLook look in BlobSign.looks)
                            GestureDetector(
                              key: Robot.key('blobLook-${look.id}'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                Haptics.tick();
                                Apps.instance.setBlobLook(look.id);
                                RestBubble.instance.tellLook(look.id);
                                Diag.instance.event('blob look: ${look.name}');
                                // (A look that turns, or does not: the sign takes it up at once.)
                                _signSync();
                                setState(() {});
                              },
                              child: SizedBox(
                                width: 70,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      decoration: ShapeDecoration(
                                        shape: CircleBorder(
                                          side: BorderSide(
                                            width: 2.5,
                                            color: c.accent.withValues(
                                              alpha:
                                                  BlobSign.of(
                                                        Apps.instance.blobLook,
                                                      ) ==
                                                      look
                                                  ? 1
                                                  : 0,
                                            ),
                                          ),
                                        ),
                                      ),
                                      child: SizedBox(
                                        width: 56,
                                        height: 56,
                                        child: CustomPaint(
                                          painter: _LensDisc(c.accent),
                                          foregroundPainter: BlobSignPreview(
                                            look.id,
                                            <Color>[
                                              for (final (double, Color) b
                                                  in _fanBlobs)
                                                b.$2,
                                            ],
                                            vivid: Apps.instance.blobVivid,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      look.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      style: LumenType.text(
                                        12.5,
                                        weight:
                                            BlobSign.of(
                                                  Apps.instance.blobLook,
                                                ) ==
                                                look
                                            ? 650
                                            : 500,
                                        color:
                                            BlobSign.of(
                                                  Apps.instance.blobLook,
                                                ) ==
                                                look
                                            ? c.ink
                                            : c.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _setFloating({bool? inPrism, bool? overApps}) {
    Haptics.tick();
    RestBubble.instance.setFloating(inPrism: inPrism, overApps: overApps);
    if (!RestBubble.instance.canFloat &&
        RestBubble.instance.pinned.value != null) {
      // Nothing floats any more: what was floating is a blob in the menu again.
      RestBubble.instance.setPin(null);
      _sendPin();
    }
  }

  // The blob being carried is held against a side of the screen, where the lens rests.
  bool _stuck = false;
  // How large the lens is, as Android last said, so a blob stops where the lens would rest.
  double _floatSize = 84;
  // How large a thing coming back to its seat starts out, against its own size: a blob let go
  // by the finger is its own size; one handed back by the lens starts the size it was in there.
  double _backScale = 1;
  // The seat kept open among the others for the thing being carried over them (a blob that was
  // picked up, or the floating lens): where it would sit if let go now. Null while it is clear
  // of them, and then the others close ranks.
  int? _gapAt;

  /// Whether the thing in place [i] is the one floating as the lens.
  bool _floating(int i) => RestBubble.instance.pinned.value == _pinKey(i);

  /// Whether place [i] is, for now, not one of the blobs in the menu.
  bool _leftOut(int i) =>
      _floating(i) || i == _awayI || i == _shotI || _isEmpty(i);

  /// Gives every blob left in the menu its seat. One that was out and is back takes its seat
  /// at once; the others move over to theirs.
  void _reseat({bool jump = false}) {
    final List<int> shown = <int>[
      for (int i = 0; i < _n; i++)
        if (!_leftOut(i)) i,
    ];
    final int? gap = _gapAt;
    final int count = shown.length + (gap == null ? 0 : 1);
    for (int j = 0; j < shown.length; j++) {
      final int i = shown[j];
      final double to = (gap != null && j >= gap ? j + 1 : j) - (count - 1) / 2;
      if (jump || !_seated.contains(i)) {
        _seat[i].jumpTo(to);
      } else {
        _seat[i].animateTo(to);
      }
    }
    _seated
      ..clear()
      ..addAll(shown);
  }

  /// The places still in the menu other than [i]: not floating, not on their way out.
  List<int> _others(int i) => <int>[
    for (int k = 0; k < _n; k++)
      if (k != i && !_floating(k) && k != _shotI && !_isEmpty(k)) k,
  ];

  /// Which seat among [others] other blobs something at [at] would take, or null if that is
  /// not among the blobs. [now] is the seat it has at the moment: it keeps that one until it
  /// is clearly over another, and stays among the blobs a little further out than it came in.
  int? _seatFor(Offset at, int others, int? now) {
    final Offset v = at - _home;
    final double d = v.distance, slack = now == null ? 0 : 14;
    if (d < _far.value - 58 - slack || d > _far.value + 62 + slack) {
      return null;
    }
    final int count = others + 1;
    final double seat = (math.atan2(-v.dy, -v.dx) / math.pi - 0.5) / _step;
    if (seat.abs() > (count - 1) / 2 + 0.75 + (now == null ? 0 : 0.1)) {
      return null;
    }
    final double place = seat + (count - 1) / 2;
    if (now != null && (place - now).abs() < 0.62) {
      return now;
    }
    return place.round().clamp(0, count - 1);
  }

  /// The thing in place [i] is put down among the blobs at seat [gap], coming from [from]. If
  /// that is a different seat from the one it had, the places change order to match, and that
  /// is how they stay.
  void _settle(
    int i,
    int gap,
    Offset from, {
    bool hold = false,
    double scale = 1,
  }) {
    _backScale = scale;
    final List<int> others = _others(i);
    final List<int> order = <int>[
      for (int k = 0; k < _n; k++)
        if (k != i) k,
    ];
    order.insert(
      others.isEmpty
          ? order.length
          : (gap < others.length
                ? order.indexOf(others[gap])
                : order.indexOf(others.last) + 1),
      i,
    );
    bool same = BlobSlots.instance.paused;
    if (!same) {
      same = true;
      for (int k = 0; k < _n; k++) {
        same = same && order[k] == k;
      }
    }
    int to = i;
    if (!same) {
      // Each thing moves to its new place, and is drawn where it already was.
      final List<String> keys = <String>[for (final int k in order) _pinKey(k)];
      final List<double> seats = <double>[
        for (final int k in order) _seat[k].value,
      ];
      final List<double> outs = <double>[
        for (final int k in order) _out[k].value,
      ];
      final List<double> gones = <double>[
        for (final int k in order) _gone[k].target,
      ];
      final Set<int> was = <int>{..._seated};
      to = order.indexOf(i);
      _awayI = null;
      _gapAt = null;
      BlobSlots.instance.putAll(keys);
      _seated.clear();
      for (int k = 0; k < _n; k++) {
        _seat[k].jumpTo(seats[k]);
        _gone[k].jumpTo(gones[k]);
        _out[k].jumpTo(_floating(k) ? 0 : (k == to ? 1 : outs[k]));
        if (!_floating(k) && !_isEmpty(k) && _open && outs[k] < 1) {
          _out[k].animateTo(1, spring: Motions.spatialFast);
        }
        if (k != to && was.contains(order[k])) {
          _seated.add(k);
        }
      }
      Diag.instance.event('blobs reordered');
    }
    _dropAt = from;
    setState(() {
      _dragI = null;
      _backI = to;
      _awayI = null;
      _gapAt = null;
    });
    _reseat();
    _dragBack.jumpTo(1);
    if (!hold) {
      _dragBack.animateTo(0);
    }
    Haptics.settle();
    if (!same) {
      _sendBlobs();
    }
  }

  /// The place of the thing floating as the lens, if one of the blobs is.
  int? get _floatingI {
    for (int i = 0; i < _n; i++) {
      if (_floating(i)) {
        return i;
      }
    }
    return null;
  }

  /// The floating lens is being carried over the blobs: they make room where it would sit.
  void _lensOver(Offset? at) {
    final int? f = _floatingI;
    if (!mounted || !_open || f == null || _dragI != null) {
      return;
    }
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int? gap = at == null
        ? null
        : _seatFor(at / dpr, _others(f).length, _gapAt);
    if (gap != _gapAt) {
      _gapAt = gap;
      _reseat();
      Haptics.tick();
    }
  }

  /// The floating lens was let go among the blobs: it is one of them again, in that seat.
  void _lensBack(Offset at, double inner) {
    final int? f = _floatingI;
    if (!mounted || f == null || !_open) {
      _gapAt = null;
      RestBubble.instance.setPin(null);
      _sendPin();
      RestBubble.instance.taken();
      return;
    }
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int n = _others(f).length;
    final int gap = _seatFor(at / dpr, n, _gapAt) ?? _gapAt ?? (n + 1) ~/ 2;
    Diag.instance.event('lens put back with the blobs');
    // It is drawn where the lens is, the size it was in the lens, and held there. Two frames
    // on it is on the screen: Android is told, the lens goes, and it travels to its seat,
    // coming up to its own size on the way.
    _awayI = f;
    _backI = f;
    _out[f].jumpTo(1);
    RestBubble.instance.setPin(null);
    _sendPin();
    _settle(
      f,
      gap,
      at / dpr,
      hold: true,
      scale: inner > 0 ? (inner / dpr / _blob).clamp(0.4, 2.0) : 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        RestBubble.instance.taken();
        if (mounted) {
          _dragBack.animateTo(0);
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  /// How far apart, round the fan, one seat is from the next: about 28 degrees with the blobs
  /// at their usual distance. Nearer the button (their names switched off) they are spread
  /// wider by as much, so that the gap between one blob and the next stays what it was.
  double get _step => 0.155 * _reach / _far.value;

  /// How far round the fan a seat is: straight up in the middle.
  double _seatAngle(double seat) => math.pi * (0.5 + seat * _step);

  /// The name a blob is pinned under.
  // (Places from 100 on are not blobs: they are what the two-finger swipes do, kept the same
  // way, so that everything that draws, names or changes a blob works for them as it is.)
  String _pinKey(int i) => i >= 100
      ? GestureSlots.instance.keys[i - 100]
      : BlobSlots.instance.at(i) ??
            (_appBlobs
                ? 'app:${BlobApps.instance.apps[i].package}'
                : 'action:$i');

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
      'container': RestBubble.instance.container.value,
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
  // The pictures sent to Android, kept once they have been made. The blobs are sent again
  // whenever anything about them changes (one is put down, one comes back, their order), and
  // making a picture into a file takes real work: it is done once for each picture, not each time.
  static final Map<int, Uint8List> _markPngs = <int, Uint8List>{};
  static final Map<ui.Image, Uint8List> _imagePngs = <ui.Image, Uint8List>{};

  /// A picture as the file Android reads, made the first time it is asked for.
  static Future<Uint8List?> _pngOf(ui.Image image) async {
    final Uint8List? had = _imagePngs[image];
    if (had != null) {
      return had;
    }
    final Uint8List? made = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))?.buffer.asUint8List();
    if (made != null) {
      // (Apps get new pictures when they are updated; the old ones are not kept for ever.)
      if (_imagePngs.length > 60) {
        _imagePngs.clear();
      }
      _imagePngs[image] = made;
    }
    return made;
  }

  static Future<Uint8List?> _iconPng(
    IconData icon, {
    Color color = Colors.white,
  }) async {
    final int which = Object.hash(icon.codePoint, icon.fontFamily, color);
    final Uint8List? had = _markPngs[which];
    if (had != null) {
      return had;
    }
    final ui.PictureRecorder rec = ui.PictureRecorder();
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 104,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(Canvas(rec), Offset((120 - tp.width) / 2, (120 - tp.height) / 2));
    final ui.Image image = await rec.endRecording().toImage(120, 120);
    final Uint8List? made = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))?.buffer.asUint8List();
    // The picture was only needed to make the file.
    image.dispose();
    if (made != null) {
      _markPngs[which] = made;
    }
    return made;
  }

  /// Tells Android what is pinned, with its name, colour and picture.
  Future<void> _sendPin() async {
    final String? key = RestBubble.instance.pinned.value;
    if (key == null) {
      RestBubble.instance.tellPin(null);
      return;
    }
    final Map<String, Object>? blob = await _blobMap(key);
    if (blob != null) {
      RestBubble.instance.tellPin(blob);
    }
  }

  /// Tells Android what all the blobs in the menu are, in order.
  Future<void> _sendBlobs() async {
    RestBubble.instance.tellNames(BlobSlots.instance.names);
    RestBubble.instance.tellLook(Apps.instance.blobLook);
    RestBubble.instance.tellVivid(Apps.instance.blobVivid);
    final List<Map<String, Object>> all = <Map<String, Object>>[];
    for (int i = 0; i < _n; i++) {
      if (_floating(i)) {
        continue; // It is in the lens, not in the menu.
      }
      final Map<String, Object>? blob = await _blobMap(_pinKey(i));
      if (blob != null) {
        // Which place it is in, so the floating lens's menu can ask for that place to be changed.
        all.add(<String, Object>{...blob, 'slot': i});
      }
    }
    RestBubble.instance.tellBlobs(all);
  }

  /// One blob as Android needs it: its name, colour and picture. Null if its app is not known yet.
  Future<Map<String, Object>?> _blobMap(String key) async {
    if (!mounted || key.startsWith('empty:')) {
      return null;
    }
    // Prism's own colour as it is now, read before anything is waited for.
    final Color accent = LumenColors.of(context).accent;
    final Color onAccent = _onAccent();
    final String what = key.substring(key.indexOf(':') + 1);
    String name = '', package = '';
    Color color = const Color(0xFF5A6373);
    int index = 0;
    Uint8List? icon;
    bool picture = false;
    if (key.startsWith('action:')) {
      index = (int.tryParse(what) ?? 0).clamp(0, _actions.length - 1);
      name = _actions[index].$1;
      color = _actions[index].$3;
      icon = await _iconPng(_actions[index].$2);
    } else if (key.startsWith('screen:')) {
      index = (int.tryParse(what) ?? 0).clamp(0, _tabs.length - 1);
      name = _tabs[index].$2;
      color = accent;
      icon = await _iconPng(_tabs[index].$1, color: onAccent);
    } else {
      package = what;
      final Iterable<BlobApp> found = BlobApps.instance.apps.where(
        (BlobApp a) => a.package == what,
      );
      final Iterable<AppTile> tiles = Apps.instance.all.where(
        (AppTile t) => t.package == what,
      );
      if (found.isEmpty && tiles.isEmpty) {
        return null; // Its app has not been found yet; this runs again when it has.
      }
      ui.Image? image;
      if (found.isNotEmpty) {
        final BlobApp a = found.first;
        name = a.name;
        color = a.color;
        image = a.glyph ?? a.picture ?? a.icon;
        picture = a.glyph == null;
      } else {
        final AppTile t = tiles.first;
        name = t.label;
        color = t.color;
        image = t.glyph ?? t.picture;
        picture = t.glyph == null;
      }
      // With Prism's icons switched off, the floating blob shows the app's own icon too.
      final ui.Image? own = _ownIcon(what);
      if (own != null) {
        image = own;
        picture = true;
      }
      if (image != null) {
        icon = await _pngOf(image);
      }
    }
    return <String, Object>{
      'key': key,
      'kind': key.substring(0, key.indexOf(':')),
      'index': index,
      'package': package,
      // The package its notifications come under, where it is known only by its name.
      'notesFor': _notesPackage(package),
      'name': name,
      'color': color.toARGB32(),
      // The colour of the small number on it: the one opposite its own.
      'badge': Notes.colourFor(color, accent).toARGB32(),
      'picture': picture,
      'icon': ?icon,
    };
  }

  /// The small number on an app's blob: how many notifications it has, on the colour opposite
  /// the app's own, with a dark edge that cuts it clear of the blob.
  Widget _noteBadge(int i) {
    final int n = _blobNotes(i);
    return Container(
      constraints: const BoxConstraints(minWidth: 25, minHeight: 25),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: Notes.colourFor(_blobColor(i), LumenColors.of(context).accent),
        shape: const StadiumBorder(
          side: BorderSide(color: Color(0xEB101216), width: 2),
        ),
      ),
      child: Text(
        n > 99 ? '99+' : '$n',
        textScaler: TextScaler.noScaling,
        style: LumenType.text(
          11.5,
          weight: 720,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }

  /// The disc of a blob: its colour, lighter at the top, and its mark.
  /// With Prism's icons switched off: the app's own icon, as the phone has it, if it is there.
  ui.Image? _ownIcon(String package) {
    if (Apps.instance.blobPrismIcons) {
      return null;
    }
    for (final AppTile t in Apps.instance.all) {
      if (t.package == package) {
        return t.own;
      }
    }
    return null;
  }

  Widget _blobDisc(int i) {
    final ui.Image? own = _isApp(i) ? _ownIcon(_pinKey(i).substring(4)) : null;
    if (own != null) {
      // The app's own icon fills the blob.
      return Container(
        width: _blob,
        height: _blob,
        decoration: ShapeDecoration(
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
        ),
        child: ClipOval(
          child: RawImage(
            image: own,
            width: _blob,
            height: _blob,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
    }
    if (_isEmpty(i)) {
      // An empty place: a plain white line, nothing filled, nothing that moves.
      return Container(
        width: _blob,
        height: _blob,
        decoration: ShapeDecoration(
          shape: CircleBorder(
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.62),
              width: 1.6,
            ),
          ),
        ),
        // A plus in the same white as the line: something can be put here.
        child: Icon(
          Icons.add_rounded,
          size: 30,
          color: Colors.white.withValues(alpha: 0.62),
        ),
      );
    }
    return Container(
      width: _blob,
      height: _blob,
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(_blobColor(i), Colors.white, 0.14)!,
            _blobColor(i),
          ],
        ),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
      ),
      child: _blobFace(i),
    );
  }

  /// A blob picked up out of the menu follows the finger. Near the button it is drawn onto it
  /// and the button swells to take it: letting go there launches it. Over the other blobs they
  /// make room where it would sit; clear of them, they close ranks.
  ///
  /// While the blobs are being changed a drag only puts them in another order: the button takes
  /// nothing in, a side holds nothing, and the seat last made for it stays open wherever the
  /// finger goes.
  void _blobDrag(int i, Offset at, Offset button) {
    if (_dragI != i) {
      return;
    }
    final bool free = !_editing;
    final bool near =
        free &&
        RestBubble.instance.canFloat &&
        (at - button).distance < (_armed ? 80 : 62);
    if (near != _armed) {
      _armed = near;
      near ? Haptics.settle() : Haptics.tick();
      _kick.animateTo(near ? 1.2 : 1);
    }
    // At a side of the screen it stops where the lens rests, and goes no further however far
    // the finger does: let go there, it is the lens at once, with nowhere left to travel.
    final Size screen = MediaQuery.sizeOf(context);
    final double half = _floatSize / 2, side = 8 + half;
    final bool stuck =
        free && !near && (at.dx <= side || at.dx >= screen.width - side);
    if (stuck) {
      at = Offset(
        at.dx <= side ? side : screen.width - side,
        at.dy.clamp(48 + half, math.max(48 + half, screen.height - 48 - half)),
      );
    }
    if (stuck != _stuck) {
      _stuck = stuck;
      stuck ? Haptics.settle() : Haptics.tick();
    }
    _dragAt.value = near ? button + (at - button) * 0.22 : at;
    final int? gap = near
        ? null
        : (_seatFor(at, _others(i).length, _gapAt) ?? (free ? null : _gapAt));
    if (gap != _gapAt || _awayI != i) {
      setState(() {
        _awayI = i;
        _gapAt = gap;
      });
      _reseat();
      if (!near) {
        Haptics.tick();
      }
    }
  }

  void _blobDrop(int i, Offset button, Offset velocity) {
    if (_dragI != i) {
      return;
    }
    final Offset coast = _dragAt.value + velocity * 0.16;
    if (_editing) {
      // While the blobs are being changed a drag only rearranges them. Let go anywhere, it
      // sits in the seat the others are keeping open for it.
      _kick.animateTo(1);
      _stuck = false;
      _settle(
        i,
        _gapAt ?? _others(i).where((int k) => k < i).length,
        _dragAt.value,
      );
      return;
    }
    if (!RestBubble.instance.canFloat) {
      // Floating elements are switched off: it goes back among the others, where it was or
      // where they made room for it.
      _kick.animateTo(1);
      _stuck = false;
      Haptics.thud();
      _settle(
        i,
        _gapAt ?? _others(i).where((int k) => k < i).length,
        _dragAt.value,
      );
      return;
    }
    // On the button, or flicked at it: the button shoots it out to the side.
    if (_armed || (velocity.distance > 700 && (coast - button).distance < 84)) {
      _gapAt = null;
      _sendBack(i, button);
      return;
    }
    _kick.animateTo(1);
    // Let go among the blobs: it sits there, in the seat they made for it. A flick that would
    // carry it clear of them is not that.
    final int? gap = _gapAt;
    final int n = _others(i).length;
    if (gap != null &&
        (velocity.distance < 900 || _seatFor(coast, n, gap) != null)) {
      _settle(i, gap, _dragAt.value);
      return;
    }
    // Put down anywhere else, or flicked away: it floats there. Held against a side, it is
    // already where it will stay, so nothing carries it on.
    _gapAt = null;
    _sendBack(i, _dragAt.value);
    _stuck = false;
  }

  /// A blob put down away from the others, or dropped on the button, goes back to its place.
  /// (Both used to make it that app's own floating blob. The floating blob is the Blob itself
  /// now, at the side, and nothing is put in it.)
  void _sendBack(int i, Offset from) {
    _armed = false;
    _dropAt = from;
    setState(() {
      _dragI = null;
      _shotI = null;
      _awayI = null;
      _backI = i;
    });
    _reseat();
    _kick.animateTo(1);
    _dragBack
      ..jumpTo(1)
      ..animateTo(0);
    Diag.instance.event('blob put down: back to its place');
  }

  void _shotTick() {
    if (_shotI == null || _landed || _shot.target < 0.5) {
      return;
    }
    if (_shot.value >= 1 || (!_shot.isAnimating && _shot.value > 0.9)) {
      // It has hit its place: the lens shows itself, drawn over this blob, which then goes.
      _landed = true;
      Haptics.settle();
      RestBubble.instance.landed();
      Future<void>.delayed(const Duration(milliseconds: 90), () {
        if (mounted) {
          setState(() => _shotI = null);
          _reseat();
        }
      });
    }
  }

  Widget _blobFace(int i) {
    if (_isEmpty(i)) {
      return const SizedBox.shrink();
    }
    if (_isPhone(i)) {
      return const Icon(
        Icons.notifications_rounded,
        color: Colors.white,
        size: 26,
      );
    }
    if (_isScreen(i)) {
      return Icon(_tabs[_screenAt(i)].$1, color: _onAccent(), size: 26);
    }
    if (!_isApp(i)) {
      return Icon(_actions[_actionAt(i)].$2, color: Colors.white, size: 26);
    }
    final BlobApp? a = _blobApp(i);
    if (a == null) {
      // Any other app: its look is the one the drawer gave it.
      final AppTile? t = _tile(i);
      if (t?.glyph != null) {
        return Center(
          child: RawImage(
            image: t!.glyph,
            width: 34,
            height: 34,
            filterQuality: FilterQuality.medium,
          ),
        );
      }
      if (t?.picture != null) {
        return Center(
          child: ClipOval(
            child: RawImage(
              image: t!.picture,
              width: 36,
              height: 36,
              filterQuality: FilterQuality.medium,
            ),
          ),
        );
      }
      final String name = _blobName(i);
      return Center(
        child: Text(
          name.isEmpty ? '?' : name.substring(0, 1),
          textScaler: TextScaler.noScaling,
          style: LumenType.text(
            24,
            weight: 700,
            color: Colors.white,
            height: 1,
          ),
        ),
      );
    }
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
  // A blob picked up out of the open menu: which one, where its middle is, and whether it is
  // over the button, where letting go launches it.
  int? _dragI;
  final ValueNotifier<Offset> _dragAt = ValueNotifier<Offset>(Offset.zero);
  Offset _dragGrab = Offset.zero;
  // Where the finger was when a hold on a blob was recognised.
  Offset _holdFrom = Offset.zero;

  bool _armed = false;
  // Let go anywhere else, it goes back to its place: 1 is where it was let go, 0 is home.
  int? _backI;
  Offset _dropAt = Offset.zero;
  late final SpringValue _dragBack = SpringValue(
    this,
    spring: Motions.spatialFast,
  );
  // Dropped on the button: taken in, held for a moment, then shot out to the side, where it
  // becomes the floating lens.
  int? _shotI;
  bool _landed = false;
  Offset _shotFrom = Offset.zero, _shotTo = Offset.zero;
  double _shotScale = 1;
  late final SpringValue _gulp = SpringValue(this, spring: Motions.spatialFast);
  late final SpringValue _shot = SpringValue(
    this,
    // Quick, and still moving when it gets there, so it arrives with a hit.
    spring: SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 430,
      ratio: 0.76,
    ),
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
  late final SpringValue _rise = SpringValue(this, spring: Motions.spatial)
    ..addListener(_sheetMoved);
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
  )..addListener(_darkSync);

  // The black the glass lays behind a triangle while it rests on it (1), and not while it is
  // away (0). It has its own fade: quick as the glass is lifted, gentle once the glass has
  // landed back, and never all at once.
  late final SpringValue _dark = SpringValue(this, value: 1);

  void _darkSync() {
    if (!mounted) {
      return;
    }
    final double want =
        !_returning && _glass.target < 0.5 && _glass.value < 0.25 ? 1 : 0;
    if (_dark.target != want) {
      _dark.animateTo(
        want,
        spring: want == 1 ? Motions.effectsSlow : Motions.effectsFast,
      );
    }
  }

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
  // When, counted from the finger coming down, the button became the lens, and when the
  // finger first moved.
  int _liftedAt = 0, _movedAt = 0;
  // Holding the button while the blobs are out: they can all be changed, as when a blob is held.
  Timer? _holdTimer;
  bool _heldEdit = false;
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
    WidgetsBinding.instance.addObserver(this);
    Diag.instance.autoScript = _robot;
    Diag.instance.longTest = _longTest;
    Diag.instance.settingsLines = () => <String>[
      'SETTINGS:',
      ..._settingsNow(),
    ];
    Diag.instance.glassTest = () =>
        _longTest(rounds: 0, glass: true, title: 'glass settings test');
    Diag.instance.drainTest = () => _longTest(
      rounds: 0,
      still: 150,
      drain: true,
      title: 'chat-head battery test',
    );
    // The same, four rounds and longer stretches of sitting still: about an hour, and quiet.
    // The same again and again for about two and a half hours: whether smoothness, memory and
    // heat hold up over a long session.
    Diag.instance.soakTest = () => _longTest(
      rounds: 15,
      still: 120,
      quiet: true,
      title: '2½-hour stability test',
    );
    Diag.instance.hourTest = () =>
        _longTest(rounds: 4, still: 180, quiet: true, title: 'hour-long test');
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
        if (action >= 100) {
          // One of Prism's own pages, asked for from the floating lens.
          if (_sheetOpen) {
            _closeSheet();
          }
          _setOpen(false);
          _go((action - 100).clamp(0, _tabs.length - 1));
          return;
        }
        _run(action);
      }
      ..onFused = _fused
      ..onPinned = (String? key) {
        // Put in the floating lens from its own menu: Prism keeps it, and it leaves the menu.
        RestBubble.instance.setPin(key);
        _sendPin();
      }
      ..onLensAt = _lensOver
      ..onReturned = _lensBack
      ..container.addListener(_sendPinData)
      ..pinned.addListener(_pinChanged);
    _shot.addListener(_shotTick);
    fit.addListener(_sendPinData);
    // The sheets follow Prism's colours, so Android is told whenever those change.
    Look.instance.addListener(_sendPinData);
    settings.addListener(_sendPinData);
    RestBubble.instance.onTheme = _sendPinData;
    // (On a computer the long test can be started by itself, to see that it runs.)
    if (Platform.environment['PRISM_GLASS_TEST'] != null) {
      Future<void>.delayed(
        const Duration(seconds: 9),
        () => Diag.instance.glassTest?.call(),
      );
    } else if (Platform.environment['PRISM_LONG_TEST'] != null) {
      Future<void>.delayed(
        const Duration(seconds: 9),
        () => _longTest(
          rounds: int.tryParse(Platform.environment['PRISM_LONG_TEST']!) ?? 1,
          still: 4,
          title: 'dry run',
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RestBubble.instance.tellFloating();
      RestBubble.instance.tellTab(_tab);
      // (Where the button is, for the side Blob to fuse with.)
      _tellFan();
      _sendPinData();
      _sendPin();
      _sendBlobs();
    });
    // Pressing the home button while Prism is the home screen: everything closes and Home shows.
    const MethodChannel('lumen/device').setMethodCallHandler((
      MethodCall call,
    ) async {
      if (call.method == 'editSlot' && mounted) {
        // A blob was tapped in the floating lens's own menu while its blobs were being
        // changed: Prism has come to the front to choose what takes its place.
        if (_sheetOpen) {
          _closeSheet();
        }
        // Afterwards Prism's own blobs are out, being changed, as they would be here.
        _editing = true;
        _pickFor((call.arguments as num).toInt().clamp(0, _n - 1));
        return;
      }
      if (call.method == 'notes') {
        // Android says how many notifications each app has.
        Notes.instance.take(call.arguments);
        return;
      }
      if (call.method == 'blobOrder' && mounted) {
        // The blobs were put in a new order in the floating lens's own menu: the places
        // those blobs are in, as they now stand. What floats keeps its place.
        final List<int> order = <int>[
          for (final Object? o in call.arguments as List<Object?>)
            (o! as num).toInt().clamp(0, _n - 1),
        ];
        final List<int> places = <int>[...order]..sort();
        final List<String> keys = <String>[
          for (int k = 0; k < _n; k++) _pinKey(k),
        ];
        final List<String> next = <String>[...keys];
        for (int j = 0; j < order.length; j++) {
          next[places[j]] = keys[order[j]];
        }
        Diag.instance.event('blobs reordered from the lens');
        BlobSlots.instance.putAll(next);
        return;
      }
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
        BlobSlots.instance.paused = true;
        BlobApps.instance.on.value = false;
      } else {
        BlobSlots.instance.paused = false;
        BlobApps.instance.on.value = appsBefore;
      }
    };
    BlobApps.instance.addListener(_blobsChanged);
    BlobSlots.instance
      ..load()
      ..addListener(_blobsChanged);
    GestureSlots.instance.load();
    Apps.instance.loadIconChoice();
    _reseat(jump: true);
    _far.jumpTo(BlobSlots.instance.names ? _reach : _reachBare);
    for (int i = 0; i < _n; i++) {
      _gone[i].jumpTo(_isEmpty(i) ? 1 : 0);
    }
    _recentre(jump: true);
    Apps.instance.addListener(_appsChanged);
    // The numbers on the blobs follow the notifications.
    Notes.instance.counts.addListener(_notesChanged);
    Notes.instance.refresh();
    if (BlobSlots.instance.keys.any(
      (String? k) => k != null && k.startsWith('app:'),
    )) {
      // A place holds an app from the drawer: its look comes from there.
      Apps.instance.refresh();
    }
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
      return b + Offset(-math.cos(a), -math.sin(a)) * _far.value;
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

  bool _testing = false;

  /// The long test. Prism drives all of itself with a finger that is not there, and asks
  /// Android to do the same to the floating lens. After each step it checks that things are
  /// as they should be; while things move it keeps how every frame was made; and at the end
  /// it sits still in one state after another and writes down what that costs. Nothing is
  /// left changed: the blobs, their names and what floats are put back as they were.
  Future<void> _longTest({
    int rounds = 1,
    int still = 60,
    bool quiet = false,
    bool drain = false,
    bool glass = false,
    String title = 'long test',
  }) async {
    if (_testing || !mounted) {
      return;
    }
    _testing = true;
    Robot.begin();
    // What the banner said when the person pressed Stop, if they did.
    String? stoppedAt;
    final TestRun t = TestRun();
    final bool hapticsWere = Haptics.enabled;
    String lap = '';
    final Size sc = MediaQuery.sizeOf(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final double top = MediaQuery.paddingOf(context).top;
    final RestBubble lensOf = RestBubble.instance;
    void say(String what) =>
        Diag.instance.banner.value = 'Test$lap: $what. Hands off, please.';
    Offset tab(int i) => Offset(14 + _centre(i), _home.dy);
    Offset seat(int i) {
      final double a = _seatAngle(_seat[i].value);
      return _home + Offset(-math.cos(a), -math.sin(a)) * _far.value;
    }

    Offset spare(int i) =>
        Offset(sc.width / 2 + (i - 2) * 74.0, sc.height * 0.42);
    // A place on the page that is beside everything the test opens.
    // (Clear of the swipes' places at the top and of the empty places in the middle.)
    final Offset beside = Offset(sc.width / 2, sc.height * 0.56);
    List<double> px(Offset o) => <double>[o.dx * dpr, o.dy * dpr];
    int shown() => _others(-1).length;
    // The app put in front when the test needs "another app": one that is on the phone and
    // that leaves floating windows alone (Android's Settings hides them).
    String standIn() {
      for (final String p in const <String>[
        'com.sec.android.app.popupcalculator',
        'com.google.android.calculator',
        'com.sec.android.app.clockpackage',
        'com.google.android.deskclock',
        'com.android.chrome',
        'com.sec.android.app.sbrowser',
        'com.android.calculator2',
      ]) {
        if (Apps.instance.all.any((AppTile a) => a.package == p)) {
          return p;
        }
      }
      return 'com.android.settings';
    }

    // (Chosen once the list of the phone's apps is there: see "getting ready".)
    String otherPkg = 'com.android.settings';
    const List<String> five = <String>[
      'action:0',
      'action:1',
      'action:2',
      'action:3',
      'action:4',
    ];
    Future<void> calm() async {
      if (_parked || _carrying) {
        _lensHome();
      }
      if (_drawerOpen) {
        _setDrawer(false);
      }
      if (_sheetOpen) {
        _closeSheet();
      }
      if (_editing) {
        _setEditing(false);
      }
      if (_open) {
        _setOpen(false);
      }
      await Robot.wait(700);
    }

    // As things are now, to be put back at the end.
    final List<String?> keysWere = <String?>[...BlobSlots.instance.keys];
    final bool namesWere = BlobSlots.instance.names;
    final String? pinWas = lensOf.pinned.value;
    final bool inWas = lensOf.floatIn.value, outWas = lensOf.floatOut.value;
    final bool fpsWas = settings.showFps;
    final bool lightsWas = Diag.instance.wallpaperOn.value;
    final int vibeWas = Look.instance.vibe;
    final bool solidWas = settings.reduceTransparency;
    final GlassQuality qualityWas = settings.quality;
    final int glassWas = Diag.instance.glassMode.value;
    // What the test set differently for itself.
    final List<String> adjusted = <String>[];
    // Every setting as it was when the test began, for the top of the report.
    final List<String> settingsWere = <String>[
      'SETTINGS when the test began:',
      ..._settingsNow(),
    ];
    String build = Diag.build;
    try {
      say('getting ready');
      // The list of the phone's apps is only read when the app list is first opened. It is
      // read now, so that "another app" can be chosen from it.
      if (Platform.isAndroid) {
        unawaited(Apps.instance.refresh());
        for (int i = 0; i < 100 && Apps.instance.all.isEmpty; i++) {
          await Robot.wait(100);
        }
      }
      otherPkg = standIn();
      t.other = otherPkg == 'com.android.settings' ? null : otherPkg;
      if (t.other == null) {
        t.note(
          'none of the usual apps (Calculator, Clock, Chrome) was found among ${Apps.instance.all.length} apps, so Android\'s Settings stood in for "another app": Settings hides floating windows, so whatever floated was not on the screen',
        );
      } else {
        t.note('"another app" in this test is $otherPkg');
      }
      if (quiet) {
        // Left running while someone sleeps: no buzzes, here or from Android.
        Haptics.enabled = false;
        await t.lens(<String, Object?>{'op': 'quiet', 'on': true});
      }
      await calm();
      // The test's own setup: whatever would spoil a reading is set right for it, and put
      // back afterwards. What was changed is written at the top of the report.
      if (settings.showFps) {
        settings.showFps = false;
        adjusted.add('frame-rate readout off (it draws all the time)');
      }
      if (Diag.instance.glassMode.value != 4) {
        Diag.instance.glassMode.value = 4;
        adjusted.add('glass style to Auto');
      }
      if (settings.quality != GlassQuality.auto) {
        settings.quality = GlassQuality.auto;
        adjusted.add('glass quality to Auto');
      }
      if (!inWas || !outWas) {
        adjusted.add('the blob allowed in Prism and over other apps');
      }
      lensOf.onStop?.call();
      lensOf.setPin(null);
      _sendPin();
      lensOf.setFloating(inPrism: true, overApps: true);
      BlobSlots.instance.putAll(five);
      if (!BlobSlots.instance.names) {
        _setNames(true);
      }
      if (_tab != 0) {
        _go(0);
      }
      await Robot.wait(900);
      Map<String, Object?> s = await t.lens(<String, Object?>{'op': 'begin'});
      final Map<String, Object?> begun = s;
      final bool floats = s['allowed'] == true;
      final double w = (s['w'] as num?)?.toDouble() ?? sc.width * dpr,
          h = (s['h'] as num?)?.toDouble() ?? sc.height * dpr,
          dp = (s['dp'] as num?)?.toDouble() ?? dpr;
      if (!floats) {
        t.note(
          'Prism is not allowed over other apps, so nothing about the floating lens was tested. Android\'s screen for it was opened: allow Prism there and run the test again.',
        );
        if (Platform.isAndroid) {
          lensOf.ask();
        }
        if (drain) {
          // Without it there is nothing to measure.
          throw StateError(
            'Prism is not allowed over other apps; allow it and start again',
          );
        }
      }
      if (s['plugged'] == true) {
        t.note(
          'THE PHONE WAS CHARGING when the test began: every current reading below means nothing. Unplug it and run the test again.',
        );
        say(
          'the phone is charging: unplug it, or the battery readings mean nothing',
        );
        await Robot.wait(4000);
      }
      Future<Map<String, Object?>> where() =>
          t.lens(<String, Object?>{'op': 'state'});
      // The cross a floating thing is dropped on to send it away.
      final Offset cross = Offset(sc.width / 2, (h - 104 * dp) / dpr);
      Future<Map<String, Object?>> press(
        String name,
        List<Offset> path, {
        int legMs = 300,
        int holdMs = 60,
        int endMs = 0,
        bool flick = false,
        int settleMs = 1600,
        bool fromLens = true,
      }) async {
        final Map<String, Object?> m = await t.lens(<String, Object?>{
          'op': 'press',
          'path': <List<double>>[for (final Offset o in path) px(o)],
          'fromLens': fromLens,
          'legMs': legMs,
          'holdMs': holdMs,
          'endMs': endMs,
          'flick': flick,
          'settleMs': settleMs,
        }, extraMs: holdMs + legMs * path.length + endMs + settleMs);
        t.lensRun(name, m);
        return m;
      }

      // One round of everything that can be done. The hour-long test does several, to see
      // whether anything changes with use.
      Future<void> round() async {
        // ---------------------------------------------------------------- pages
        say('1 of 9, the pages');
        await t.scene('switching tabs', () async {
          for (final int i in <int>[1, 2, 3, 0, 2, 1, 3, 0]) {
            await Robot.tap(tab(i), after: 700);
          }
        });
        t.check('tabs: ends on Home', _tab == 0, 'tab $_tab');
        await t.scene('scrolling every page', () async {
          for (final int i in <int>[1, 2, 3, 0]) {
            await Robot.tap(tab(i), after: 800);
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
        });

        // ---------------------------------------------------------------- blobs
        say('2 of 9, the blobs');
        await t.scene('blobs opening and closing', () async {
          for (int n = 0; n < 6; n++) {
            await Robot.tap(_home, after: 650);
          }
        });
        t.check('blobs: closed after opening and closing three times', !_open);
        await Robot.tap(_home, after: 800);
        t.check('blobs: a tap on the button opens them', _open && shown() == 5);
        await t.scene('holding a blob', () async {
          await Robot.hold(seat(2), after: 500);
        });
        t.check('changing: holding a blob starts it', _editing && _open);
        t.check(
          'sign: while the blobs are being changed it is the cog',
          _cog.target == 1,
        );
        await Robot.tap(beside, after: 500);
        t.check(
          'changing: a tap beside the blobs ends it and leaves the blobs out',
          !_editing && _open,
        );
        await Robot.hold(_home, ms: 650, after: 500);
        t.check('changing: holding the X starts it', _editing && _open);
        await Robot.tap(beside, after: 500);
        t.check(
          'changing: a tap beside the blobs ends it first',
          !_editing && _open,
        );
        await Robot.hold(seat(2), after: 500);
        final Offset? names = Robot.spot('names');
        t.check('names: the switch is there while changing', names != null);
        if (names != null) {
          await t.scene('names off, blobs move in', () async {
            await Robot.tap(names, after: 900);
          });
          t.check(
            'names: off, and the blobs are nearer the button',
            !BlobSlots.instance.names && (_far.value - _reachBare).abs() < 1,
            'at ${_far.value.round()}',
          );
          await t.scene('names on, blobs move out', () async {
            await Robot.tap(Robot.spot('names') ?? names, after: 900);
          });
          t.check(
            'names: on again, and the blobs are back out',
            BlobSlots.instance.names && (_far.value - _reach).abs() < 1,
            'at ${_far.value.round()}',
          );
        }
        // Taking a blob away and giving the place something again.
        await t.scene('taking a blob away', () async {
          await Robot.tap(seat(2) + const Offset(-21, -21), after: 900);
        });
        t.check('minus: the third place is empty', _isEmpty(2));
        t.check(
          'minus: the one empty place stands in the middle',
          _midX[2].target == 0,
          '${_midX[2].target}',
        );
        t.check('minus: four blobs are left', shown() == 4, '${shown()}');
        await t.scene('an empty place opens the list', () async {
          await Robot.tap(spare(2), after: 1300);
        });
        t.check(
          'empty place: a tap opens "Add a blob"',
          _drawerOpen && _editSlot == 2,
        );
        Offset? first = Robot.spot('choice0');
        t.check('picker: the first choice can be found', first != null);
        if (first != null) {
          await t.scene('choosing, and the new blob joins', () async {
            await Robot.tap(first!, after: 1700);
          });
        }
        t.check('add: the third place holds something again', !_isEmpty(2));
        t.check(
          'add: back at the blobs, still being changed',
          _open && _editing && !_drawerOpen,
        );
        if (_drawerOpen) {
          _setDrawer(false);
          await Robot.wait(700);
        }
        // The pencil.
        await Robot.tap(seat(1), after: 1300);
        t.check(
          'pencil: a tap on a blob opens "Replace"',
          _drawerOpen && _editSlot == 1,
        );
        first = Robot.spot('choice0');
        if (first != null) {
          await Robot.tap(first, after: 1600);
        }
        t.check(
          'replace: the second place is what was chosen',
          _pinKey(1) == 'action:0',
          _pinKey(1),
        );
        if (_drawerOpen) {
          _setDrawer(false);
          await Robot.wait(700);
        }
        // The cog.
        await Robot.tap(_home, after: 900);
        final Offset? inPrism = Robot.spot('floatIn');
        t.check('cog: a tap on it opens its panel', inPrism != null);
        final Offset? shut = Robot.spot('floatClose');
        if (shut != null) {
          await Robot.tap(shut, after: 700);
          t.check(
            'cog: the X in the panel closes it',
            Robot.spot('floatIn') == null,
          );
          await Robot.tap(_home, after: 900);
        }
        if (inPrism != null) {
          await Robot.tap(inPrism, after: 500);
          t.check('floating: "In Prism" switches off', !lensOf.floatIn.value);
          await Robot.tap(inPrism, after: 500);
          t.check('floating: and on again', lensOf.floatIn.value);
          await Robot.tap(Offset(sc.width / 2, top + 60), after: 800);
          t.check(
            'floating: a tap outside closes the panel',
            Robot.spot('floatIn') == null,
          );
        }
        if (_editing) {
          await Robot.tap(beside, after: 500);
        }
        BlobSlots.instance.putAll(five);
        await Robot.wait(500);
        // Putting them in another order.
        if (!_open) {
          await Robot.tap(_home, after: 800);
        }
        await t.scene('dragging the first blob to the far end', () async {
          // (A pause at each seat, the last included: it is put down, not thrown.)
          await Robot.drag(
            <Offset>[seat(0), seat(1), seat(2), seat(3), seat(4)],
            legMs: 220,
            dwell: 160,
            after: 900,
          );
        });
        t.check(
          'order: the first blob is now the last',
          _pinKey(4) == 'action:0',
          <String>[for (int i = 0; i < _n; i++) _pinKey(i)].join(' '),
        );
        await Robot.drag(
          <Offset>[seat(4), seat(3), seat(2), seat(1), seat(0)],
          legMs: 220,
          dwell: 160,
          after: 900,
        );
        t.check(
          'order: and back where it was',
          _pinKey(0) == 'action:0' && _pinKey(4) == 'action:4',
          <String>[for (int i = 0; i < _n; i++) _pinKey(i)].join(' '),
        );
        t.check(
          'order: moving a blob along the row did not make it float',
          lensOf.pinned.value == null,
          '${lensOf.pinned.value}',
        );
        // The same while the blobs are being changed. First held, then dragged in one touch.
        if (!_open) {
          await Robot.tap(_home, after: 800);
        }
        String order() =>
            <String>[for (int i = 0; i < _n; i++) _pinKey(i)].join(' ');
        await t.scene(
          'holding a blob, then dragging it without letting go',
          () async {
            await Robot.drag(
              <Offset>[
                seat(0),
                seat(0) + const Offset(0, 1),
                seat(0) + const Offset(0, 2),
                seat(0) + const Offset(0, 1),
                seat(1),
                seat(2),
                seat(3),
                seat(4),
              ],
              legMs: 220,
              dwell: 160,
              after: 900,
            );
          },
        );
        t.check(
          'changing: held and then dragged, the blobs can be changed and the first is now the last',
          _editing && _pinKey(4) == 'action:0',
          '${_editing ? 'changing' : 'not changing'}; ${order()}',
        );
        if (!_editing) {
          await Robot.hold(seat(2), after: 600);
        }
        await t.scene('dragging a blob while they are being changed', () async {
          await Robot.drag(
            <Offset>[seat(4), seat(3), seat(2), seat(1), seat(0)],
            legMs: 220,
            dwell: 160,
            after: 900,
          );
        });
        t.check(
          'changing: dragged, it goes to another seat, and they can still be changed',
          _editing && _pinKey(0) == 'action:0' && _pinKey(4) == 'action:4',
          '${_editing ? 'changing' : 'not changing'}; ${order()}',
        );
        // Dragged right away from the others and let go: it goes back among them.
        await Robot.drag(
          <Offset>[seat(2), seat(2) - const Offset(0, 230)],
          legMs: 400,
          dwell: 300,
          after: 1000,
        );
        t.check(
          'changing: dragged away and let go, it goes back to its seat and nothing floats',
          _dragI == null &&
              lensOf.pinned.value == null &&
              _pinKey(2) == 'action:2' &&
              _open,
          '${lensOf.pinned.value}; ${order()}',
        );
        if (lensOf.pinned.value != null) {
          lensOf.setPin(null);
          _sendPin();
        }
        if (_editing) {
          await Robot.tap(beside, after: 500);
        }
        // The two-finger swipes.
        final List<String> swipes = <String>[...GestureSlots.instance.keys];
        final bool wasOut = _open;
        if (!_open) {
          await Robot.tap(_home, after: 800);
        }
        await Robot.hold(seat(2), after: 600);
        final Offset? side = Robot.spot('gesture2');
        t.check(
          'swipes: their places are shown while the blobs are being changed',
          side != null,
        );
        if (side != null) {
          await Robot.tap(side, after: 1300);
          t.check(
            'swipes: a tap on a place asks what that swipe should do',
            _drawerOpen && _editSlot == 102,
          );
          final Offset? pick = Robot.spot('choice0');
          if (pick != null) {
            await Robot.tap(pick, after: 1600);
          }
          t.check(
            'swipes: what was chosen is what it does',
            GestureSlots.instance.keys[2] == 'phone:shade',
            GestureSlots.instance.keys[2],
          );
          if (_drawerOpen) {
            _setDrawer(false);
            await Robot.wait(700);
          }
          final Offset? off = Robot.spot('gestureOff2');
          if (off != null) {
            await Robot.tap(off, after: 600);
          }
          t.check(
            'swipes: the minus leaves that swipe doing nothing',
            GestureSlots.instance.keys[2] == 'empty:',
            GestureSlots.instance.keys[2],
          );
        }
        if (_open && _editing) {
          await Robot.swipe2(
            Offset(sc.width / 2, sc.height * 0.5),
            const Offset(0, -150),
            after: 1300,
          );
          t.check(
            'swipes: made while the blobs are being changed, the swipe asks what it should do',
            _drawerOpen && _editSlot == 101,
            '$_editSlot',
          );
          if (_drawerOpen) {
            _setDrawer(false);
            await Robot.wait(700);
          }
        }
        if (_editing) {
          await Robot.tap(beside, after: 500);
        }
        if (_open) {
          await Robot.tap(_home, after: 800);
        }
        GestureSlots.instance.put(1, 'action:2');
        await t.scene('two fingers up', () async {
          await Robot.swipe2(
            Offset(sc.width / 2, sc.height * 0.5),
            const Offset(0, -150),
            after: 1100,
          );
        });
        t.check(
          'swipes: two fingers up, with nothing open, does what it was given',
          _sheetOpen && _sheet == 2,
          _sheetOpen ? 'sheet $_sheet' : 'no sheet',
        );
        if (_sheetOpen) {
          _closeSheet();
          await Robot.wait(800);
        }
        final int tabWas = _tab;
        await Robot.swipe2(
          Offset(sc.width / 2, sc.height * 0.5),
          const Offset(150, 0),
          after: 800,
        );
        t.check(
          'swipes: one that was given nothing does nothing',
          !_sheetOpen && !_drawerOpen && !_open && _tab == tabWas,
        );
        for (int g = 0; g < 4; g++) {
          GestureSlots.instance.put(g, swipes[g]);
        }
        if (wasOut && !_open) {
          await Robot.tap(_home, after: 800);
        }
        if (lensOf.pinned.value != null) {
          lensOf.setPin(null);
          _sendPin();
        }
        BlobSlots.instance.putAll(five);
        await calm();

        // ---------------------------------------------------------------- app list
        say('3 of 9, the app list');
        // (Whether the magnifying glass, or a card under it, wakes at any moment of the flick.)
        bool woke = false;
        void waking() => woke = woke || LensBus.instance.pos.value != null;
        LensBus.instance.pos.addListener(waking);
        _glass.addListener(waking);
        void lifting() => woke = woke || _carrying;
        _glass.addListener(lifting);
        await t.scene('app list opening', () async {
          await Robot.drag(
            <Offset>[_home, _home - const Offset(0, 90)],
            legMs: 90,
            flick: true,
            after: 1000,
          );
        });
        LensBus.instance.pos.removeListener(waking);
        _glass.removeListener(waking);
        _glass.removeListener(lifting);
        t.check('app list: a flick up from the button opens it', _drawerOpen);
        t.check(
          'app list: the flick wakes neither the magnifying glass nor a card',
          !woke,
        );
        t.check(
          'sign: with the app list up it is not the cog',
          _cog.target == 0,
        );
        if (_drawerOpen) {
          final Offset mid = Offset(sc.width / 2, sc.height * 0.55);
          await t.scene('app list turning pages', () async {
            await Robot.drag(
              <Offset>[mid, mid - const Offset(0, 250)],
              legMs: 700,
              after: 600,
            );
            await Robot.drag(
              <Offset>[mid, mid + const Offset(0, 130)],
              legMs: 500,
              after: 600,
            );
          });
          await t.scene('app list closing', () async {
            await Robot.tap(_home, after: 800);
          });
        }
        t.check('app list: the button closes it', !_drawerOpen);
        await calm();

        // ---------------------------------------------------------------- magnifying glass
        say('4 of 9, the magnifying glass');
        final List<Rect> cards =
            <Rect>[
              for (final LensTargetState c in LensBus.instance.targets)
                if (c.widget.page == 'home' && c.rect != null) c.rect!,
            ]..sort(
              (Rect x, Rect y) => x.top != y.top
                  ? x.top.compareTo(y.top)
                  : x.left.compareTo(y.left),
            );
        t.check(
          'glass: there are cards on Home to carry it over',
          cards.isNotEmpty,
        );
        if (cards.isNotEmpty) {
          bool lifted = false;
          void seen() => lifted = lifted || _carrying;
          _glass.addListener(seen);
          await t.scene('carrying the glass over every card', () async {
            await Robot.drag(
              <Offset>[
                _home,
                for (final Rect r in cards) r.center + const Offset(0, 62),
              ],
              legMs: 380,
              dwell: 300,
              after: 900,
            );
          });
          _glass.removeListener(seen);
          t.check('glass: dragging from the button brings it out', lifted);
        }
        await calm();
        // Put down on something with things to do, and dragged off again from there.
        final List<LensTargetState> doing = <LensTargetState>[
          for (final LensTargetState c in LensBus.instance.targets)
            if (c.widget.page == 'home' &&
                c.rect != null &&
                c.widget.actions.isNotEmpty &&
                c.rect!.center.dy > top + 140 &&
                c.rect!.center.dy < _home.dy - 150)
              c,
        ];
        if (doing.length >= 2) {
          // The glass rides 62 above the finger.
          const Offset under = Offset(0, 62);
          await Robot.drag(
            <Offset>[_home, doing[0].rect!.center + under],
            legMs: 500,
            dwell: 450,
            after: 900,
          );
          t.check(
            'glass: put down on a card with something to do, it stays there',
            _parked && _pill == doing[0],
            _pill?.widget.title ?? 'on nothing',
          );
          await t.scene('picking the put-down glass up again', () async {
            await Robot.drag(
              <Offset>[_lensRect.center, doing[1].rect!.center + under],
              legMs: 500,
              dwell: 450,
              after: 900,
            );
          });
          t.check(
            'glass: dragged from where it was put down, it goes to another card and stays',
            _parked && _pill == doing[1],
            _pill?.widget.title ?? 'on nothing',
          );
          // Somewhere with nothing to do under the glass.
          Offset? bare;
          for (
            double y = top + 120;
            y < _home.dy - 80 && bare == null;
            y += 24
          ) {
            for (final double x in <double>[
              sc.width * 0.5,
              sc.width * 0.2,
              sc.width * 0.8,
            ]) {
              final Offset p = Offset(x, y);
              if (!doing.any((LensTargetState c) => c.near(p) > 0.5)) {
                bare = p;
                break;
              }
            }
          }
          if (bare != null && _parked) {
            await Robot.drag(
              <Offset>[_lensRect.center, bare + under],
              legMs: 500,
              dwell: 350,
              after: 1100,
            );
            t.check(
              'glass: dragged off and let go over nothing to do, it goes home',
              !_parked && !_carrying,
            );
          } else if (_parked) {
            await Robot.tap(_home, after: 900);
          }
        } else {
          t.note(
            'fewer than two cards on Home offer something to do where the glass can reach, so picking it up again was not tested',
          );
        }
        await calm();
        // A flick must still be the app list, however the glass has been tuned.
        await Robot.drag(
          <Offset>[_home, _home - const Offset(0, 110)],
          legMs: 160,
          flick: true,
          after: 900,
        );
        t.check(
          'glass: a slower flick up is still the app list',
          _drawerOpen && !_carrying,
        );
        await calm();

        // ---------------------------------------------------------------- sheets
        say('5 of 9, the sheets');
        for (final int i in <int>[3, 1]) {
          await Robot.tap(_home, after: 700);
          final String name = _blobName(i);
          await t.scene('sheet from "$name"', () async {
            await Robot.tap(seat(i), after: 1100);
          });
          t.check('sheet: "$name" opens one', _sheetOpen);
          if (_sheetOpen) {
            await Robot.tap(Offset(sc.width / 2, top + 40), after: 900);
          }
          t.check('sheet: a tap above "$name" closes it', !_sheetOpen);
          await calm();
        }

        // ---------------------------------------------------------------- workout page
        say('6 of 9, the workout page');
        await Robot.tap(tab(1), after: 900);
        final Offset? tick = Robot.spot('tick');
        t.check('workout: a set can be found to tick', tick != null);
        if (tick != null) {
          await t.scene('ticking a set and unticking it', () async {
            await Robot.tap(tick, after: 1200);
            await Robot.tap(tick, after: 900);
          });
        }
        lensOf.onStop?.call();
        await Robot.tap(tab(0), after: 900);

        // ---------------------------------------------------------------- the side Blob
        if (floats) {
          say('7 of 9, the side Blob');
          await calm();
          Map<String, Object?> s = await t.lens(<String, Object?>{
            'op': 'side',
            'on': true,
          });
          await Robot.wait(900);
          s = await where();
          t.check(
            'side Blob: it is there in Prism, as the Blob itself',
            s['lens'] == true && s['pin'] == 'blob:side' && s['guest'] == true,
            'shown ${s['lens']}, in it ${s['pin']}, the side Blob ${s['guest']}',
          );
          t.check(
            'side Blob: Prism has nothing pinned of its own',
            lensOf.pinned.value == null,
            '${lensOf.pinned.value}',
          );
          final double sideX = (s['x'] as num?)?.toDouble() ?? -1,
              sideY = (s['y'] as num?)?.toDouble() ?? -1;
          if (Apps.instance.all.any((AppTile a) => a.package == otherPkg)) {
            s = await t.lens(<String, Object?>{
              'op': 'away',
              'pkg': otherPkg,
              'ms': 1200,
            });
            await Robot.wait(1500);
            s = await where();
            t.check(
              'side Blob: over another app it is still there, in the same spot',
              s['fg'] == false &&
                  s['lens'] == true &&
                  s['pin'] == 'blob:side' &&
                  ((s['x'] as num?)?.toDouble() ?? -9) == sideX &&
                  ((s['y'] as num?)?.toDouble() ?? -9) == sideY,
              'in front ${s['fg']}, shown ${s['lens']}, in it ${s['pin']}, at ${s['x']},${s['y']} (was $sideX,$sideY)',
            );
            s = await t.lens(<String, Object?>{'op': 'side', 'on': false});
            s = await where();
            t.check(
              'side Blob: sent away, it is gone',
              s['lens'] != true,
              'shown ${s['lens']}',
            );
            s = await t.lens(<String, Object?>{'op': 'front'}, extraMs: 4000);
            await calm();
            s = await where();
            t.check(
              'side Blob: sent away, it stays away in Prism too',
              s['lens'] != true,
              'shown ${s['lens']}',
            );
            s = await t.lens(<String, Object?>{
              'op': 'away',
              'pkg': otherPkg,
              'bring': true,
              'ms': 1200,
            });
            await Robot.wait(1500);
            s = await where();
            t.check(
              'side Blob: the next app opened brings it back, where it was',
              s['lens'] == true &&
                  s['pin'] == 'blob:side' &&
                  ((s['x'] as num?)?.toDouble() ?? -9) == sideX,
              'shown ${s['lens']}, in it ${s['pin']}, at ${s['x']} (was $sideX)',
            );
            s = await t.lens(<String, Object?>{'op': 'front'}, extraMs: 4000);
            await calm();
          } else {
            t.note(
              '$otherPkg is not among the apps, so the side Blob was only tested in Prism',
            );
          }

          // ---------------------------------------------------------------- the workout's timer
          say('8 of 9, the floating timer');
          // (From here what is asked of Android's side is asked of the timer, not the blob.)
          t.timer = true;
          await Robot.tap(tab(1), after: 900);
          await Robot.tap(tab(0), after: 900);
          final void Function(int)? rest = lensOf.testRest;
          t.check('timer: the test can start a rest', rest != null);
          if (rest != null) {
            rest(90);
            await Robot.wait(1800);
            s = await where();
            t.check(
              'timer: with a rest running it floats',
              s['lens'] == true && s['mode'] == 1,
              'mode ${s['mode']}',
            );
            final double d0 = (s['draws'] as num?)?.toDouble() ?? 0;
            final int t0 = t.clock.elapsedMilliseconds;
            await Robot.wait(8000);
            s = await where();
            final double rate =
                (((s['draws'] as num?)?.toDouble() ?? 0) - d0) /
                ((t.clock.elapsedMilliseconds - t0) / 1000);
            t.check(
              'timer: on a 90 second rest it is drawn 3 to 9 times a second',
              rate >= 3 && rate <= 9,
              '${rate.toStringAsFixed(1)} a second',
            );
            s = await press(
              'timer tapped: its sheet opens',
              <Offset>[],
              holdMs: 40,
              settleMs: 1300,
            );
            t.check('timer: a tap opens its sheet', s['sheet'] == true);
            if (s['sheet'] == true) {
              Map<String, Object?> m = await t.lens(<String, Object?>{
                'op': 'sheet',
                'what': 'texts',
              });
              t.note(
                'the timer\'s sheet showed: ${(m['texts'] as List<Object?>? ?? <Object?>[]).join(' | ')}',
              );
              m = await t.lens(<String, Object?>{
                'op': 'sheet',
                'what': 'back',
              });
              t.check('sheet: back folds it away', m['sheet'] != true);
              s = await press(
                'timer tapped again',
                <Offset>[],
                holdMs: 40,
                settleMs: 1300,
              );
              if (s['sheet'] == true) {
                m = await t.lens(<String, Object?>{
                  'op': 'sheet',
                  'what': 'outside',
                });
                t.check(
                  'sheet: a touch outside folds it away',
                  m['sheet'] != true,
                );
              }
            }
            // The blob and the timer are two: both can be there.
            lensOf.setPin('action:1');
            _sendPin();
            await Robot.wait(1500);
            t.timer = false;
            Map<String, Object?> b = await where();
            t.timer = true;
            s = await where();
            t.check(
              'two: a blob and the timer float at once, each its own',
              b['lens'] == true &&
                  b['mode'] == 2 &&
                  s['lens'] == true &&
                  s['mode'] == 1,
              'blob ${b['lens']} mode ${b['mode']}, timer ${s['lens']} mode ${s['mode']}',
            );
            // A blob gives a tenth and no more, however large it is asked to be.
            t.timer = false;
            b = await t.lens(<String, Object?>{'op': 'size', 'dp': 300});
            t.timer = true;
            final double most = 84 * 1.1 * dp + 2;
            t.check(
              'size: a blob asked to be very large is a tenth over its own size at most',
              b['lens'] == true &&
                  ((b['size'] as num?)?.toDouble() ?? 1e9) <= most,
              '${b['size']} px, at most ${most.round()}',
            );
            lensOf.setPin(null);
            _sendPin();
            await Robot.wait(900);

            // The small timer's three places at the foot.
            s = await t.lens(<String, Object?>{'op': 'size', 'dp': 84});
            final double x0 = (s['x'] as num?)?.toDouble() ?? 0,
                y0 = (s['y'] as num?)?.toDouble() ?? 0;
            s = await press(
              'timer dropped on pause',
              <Offset>[cross - const Offset(104, 0)],
              legMs: 650,
              endMs: 300,
              settleMs: 1600,
            );
            await Robot.wait(500);
            s = await where();
            t.check(
              'places: dropped on pause, the timer stands',
              s['paused'] == true && s['lens'] == true,
              'paused ${s['paused']}',
            );
            t.check(
              'places: and it is back where it was picked up from',
              (((s['x'] as num?)?.toDouble() ?? 1e9) - x0).abs() < 14 * dp &&
                  (((s['y'] as num?)?.toDouble() ?? 1e9) - y0).abs() < 14 * dp,
              'now ${s['x']}, ${s['y']}; was ${x0.round()}, ${y0.round()}',
            );
            await press(
              'timer dropped on pause again',
              <Offset>[cross - const Offset(104, 0)],
              legMs: 650,
              endMs: 300,
              settleMs: 1600,
            );
            await Robot.wait(500);
            s = await where();
            t.check(
              'places: dropped there again, it goes on',
              s['paused'] != true,
              'paused ${s['paused']}',
            );
            final bool wasUp = lensOf.countUp.value;
            if (wasUp) {
              lensOf.toggleMode();
              await Robot.wait(400);
            }
            await press(
              'timer dropped on count up',
              <Offset>[cross + const Offset(104, 0)],
              legMs: 650,
              endMs: 300,
              settleMs: 1600,
            );
            await Robot.wait(500);
            s = await where();
            t.check(
              'places: dropped on count up, it counts up, and is still there',
              lensOf.countUp.value && s['lens'] == true,
              'counting up ${lensOf.countUp.value}',
            );
            if (lensOf.countUp.value != wasUp) {
              lensOf.toggleMode();
              await Robot.wait(400);
            }
            // Large, it carries its controls under it.
            s = await t.lens(<String, Object?>{'op': 'size', 'dp': 230});
            await Robot.wait(1500);
            s = await where();
            t.check(
              'controls: made large, the timer has its three under it',
              s['tray'] == true,
              'size ${s['size']} px',
            );
            if (s['tray'] == true) {
              s = await t.lens(<String, Object?>{'op': 'tray', 'i': 0});
              t.check(
                'controls: a tap on pause, and it stands',
                s['paused'] == true,
                'paused ${s['paused']}',
              );
              s = await t.lens(<String, Object?>{'op': 'tray', 'i': 0});
              t.check(
                'controls: a tap again, and it goes on',
                s['paused'] != true,
                'paused ${s['paused']}',
              );
            }
            s = await t.lens(<String, Object?>{'op': 'size', 'dp': 84});
            await Robot.wait(1200);
            s = await where();
            t.check(
              'controls: made small again, they are gone',
              s['tray'] != true,
            );
            // The cross stops the timer and takes it off the screen; a new rest brings it back.
            s = await press(
              'timer dropped on the cross',
              <Offset>[cross],
              legMs: 650,
              endMs: 300,
              settleMs: 1500,
            );
            await Robot.wait(700);
            s = await where();
            t.check(
              'timer: dropped on the cross, it is closed',
              s['lens'] != true,
            );
            t.check(
              'timer: and it is stopped, not running out of sight',
              s['off'] == true,
              'off ${s['off']}',
            );
            rest(5);
            await Robot.wait(1500);
            s = await where();
            t.check(
              'timer: a new rest brings it back',
              s['lens'] == true && s['mode'] == 1,
              'mode ${s['mode']}',
            );
            await Robot.wait(5300);
            s = await where();
            final double off =
                ((s['buzzAt'] as num?)?.toDouble() ?? 0) -
                ((s['endsAt'] as num?)?.toDouble() ?? 0);
            t.check(
              'buzz: given when the rest ends',
              off.abs() < 500,
              'off by ${off.round()} ms',
            );
            lensOf.onStop?.call();
            await Robot.wait(600);
          }
        }
      }

      if (rounds > 0) {
        // The flight recorder keeps what is done, and gives it back when asked.
        await Robot.tap(_home, after: 600);
        await Robot.tap(_home, after: 600);
        final String rec = await Recorder.instance.export('a test note');
        t.check(
          'recorder: it kept what was just done, and gives it back with the note',
          rec.contains('blobs open') &&
              rec.contains('blobs close') &&
              rec.contains('YOUR NOTE: a test note') &&
              rec.contains('SETTINGS:'),
          '${rec.split('\n').length} lines',
        );
      }
      for (int n = 1; n <= rounds; n++) {
        lap = rounds > 1 ? ', round $n of $rounds' : '';
        try {
          t.roundStart();
          await round();
        } catch (e, where) {
          if (e is TestStopped) {
            rethrow;
          }
          t.check('round $n ran to its end', false, '$e\n$where');
        }
        await calm();
        // Whatever a round left behind, the next starts from the same place.
        lensOf.onStop?.call();
        if (lensOf.pinned.value != null) {
          lensOf.setPin(null);
          _sendPin();
        }
        t.timer = false;
        lensOf.setFloating(inPrism: true, overApps: true);
        BlobSlots.instance.putAll(five);
        if (!BlobSlots.instance.names) {
          _setNames(true);
        }
        final Map<String, Object?> here = await t.lens(<String, Object?>{
          'op': 'memory',
        });
        if (here['fg'] == false) {
          await t.lens(<String, Object?>{'op': 'front'}, extraMs: 4000);
        }
        if (_tab != 0) {
          _go(0);
        }
        final (int cache, int icons) = _pictureBytes();
        t.roundEnd(n, <String, Object?>{...here, 'pictures': cache + icons});
        if (rounds <= 4) {
          t.note(
            'after round $n: Prism was using ${(((here['pss'] as num?) ?? 0) / 1024).toStringAsFixed(0)} MB, ${t.clock.elapsed.inMinutes} min in',
          );
        }
        TestRun.keep(
          t.report(<String>[
            '${Diag.build}  ·  $title  ·  UNFINISHED: this is as far as it had got after round $n of $rounds',
            ...settingsWere,
          ]),
        );
        await Robot.wait(800);
      }
      lap = '';

      // ---------------------------------------------------------------- the glass settings
      if (glass) {
        // The same movements under each setting, changed one at a time from a starting point,
        // so that what each one costs can be read off. Twice over, in the same order.
        final bool listIconsWere = Apps.instance.prismIcons,
            blobIconsWere = Apps.instance.blobPrismIcons;
        Future<void> icons(bool prism) async {
          await Apps.instance.setPrismIcons(prism);
          await Apps.instance.setPrismIcons(prism, blobs: true);
        }

        void base() {
          Diag.instance.glassMode.value = 0;
          settings.quality = GlassQuality.full;
          Diag.instance.wallpaperOn.value = true;
          if (Look.instance.vibe != 0) {
            Look.instance.choose(vibe: 0);
          }
          settings.reduceTransparency = false;
        }

        final List<(String, void Function())>
        configs = <(String, void Function())>[
          ('A  starting point: Orig. glass, Full, lights on, Flow', () {}),
          (
            'B  glass quality Medium',
            () {
              settings.quality = GlassQuality.medium;
            },
          ),
          (
            'C  glass quality Low',
            () {
              settings.quality = GlassQuality.low;
            },
          ),
          (
            'D  glass style One at a time',
            () {
              Diag.instance.glassMode.value = 1;
            },
          ),
          (
            'E  glass style Frosted',
            () {
              Diag.instance.glassMode.value = 2;
            },
          ),
          (
            'F  glass style Event',
            () {
              Diag.instance.glassMode.value = 3;
            },
          ),
          (
            'G  background lights off',
            () {
              Diag.instance.wallpaperOn.value = false;
            },
          ),
          (
            'H  background Pattern',
            () {
              Look.instance.choose(vibe: 1);
            },
          ),
          (
            'I  reduce transparency',
            () {
              settings.reduceTransparency = true;
            },
          ),
          (
            'J  all the cheapest: Event, Low, lights off, reduce transparency',
            () {
              Diag.instance.glassMode.value = 3;
              settings.quality = GlassQuality.low;
              Diag.instance.wallpaperOn.value = false;
              settings.reduceTransparency = true;
            },
          ),
          // The apps' own icons, in the app list and the blobs (switched below, as it is not instant).
          ('K  the apps\' own icons, not Prism\'s', () {}),
        ];
        final List<Rect> cards = <Rect>[
          for (final LensTargetState c in LensBus.instance.targets)
            if (c.widget.page == 'home' && c.rect != null) c.rect!,
        ];
        for (int r = 1; r <= 2; r++) {
          for (final (int k, (String label, void Function() change))
              in configs.indexed) {
            say(
              'glass settings, ${(r - 1) * configs.length + k + 1} of ${configs.length * 2}: ${label.substring(3)}',
            );
            base();
            change();
            await icons(!label.startsWith('K'));
            await Robot.wait(1500);
            final Map<String, Object?> s0 = await t.lens(<String, Object?>{
              'op': 'state',
            });
            final int at0 = t.clock.elapsedMilliseconds;
            await t.scene('$label: switching tabs', () async {
              for (final int i in <int>[1, 2, 3, 0]) {
                await Robot.tap(tab(i), after: 650);
              }
            });
            await t.scene('$label: scrolling', () async {
              final Offset mid = Offset(sc.width / 2, sc.height * 0.6);
              await Robot.drag(
                <Offset>[mid, mid - const Offset(0, 300)],
                legMs: 260,
                flick: true,
                after: 700,
              );
              await Robot.drag(
                <Offset>[
                  mid - const Offset(0, 200),
                  mid + const Offset(0, 200),
                ],
                legMs: 260,
                flick: true,
                after: 700,
              );
            });
            await t.scene('$label: blobs out and in', () async {
              for (int n = 0; n < 2; n++) {
                await Robot.tap(_home, after: 700);
                await Robot.tap(_home, after: 700);
              }
            });
            await t.scene('$label: app list', () async {
              await Robot.drag(
                <Offset>[_home, _home - const Offset(0, 90)],
                legMs: 90,
                flick: true,
                after: 900,
              );
              final Offset mid = Offset(sc.width / 2, sc.height * 0.55);
              await Robot.drag(
                <Offset>[mid, mid - const Offset(0, 250)],
                legMs: 300,
                after: 600,
              );
              if (_drawerOpen) {
                await Robot.tap(_home, after: 800);
              }
            });
            if (cards.isNotEmpty) {
              await t.scene('$label: carrying the magnifying glass', () async {
                await Robot.drag(
                  <Offset>[
                    _home,
                    for (final Rect c in cards.take(3))
                      c.center + const Offset(0, 62),
                    Offset(sc.width / 2, top + 60),
                  ],
                  legMs: 380,
                  dwell: 200,
                  after: 1000,
                );
              });
            }
            await calm();
            final Map<String, Object?> s1 = await t.lens(<String, Object?>{
              'op': 'state',
            });
            t.glassRows.add((
              label,
              (((s1['cpu'] as num?) ?? 0) - ((s0['cpu'] as num?) ?? 0))
                  .toDouble(),
              (t.clock.elapsedMilliseconds - at0).toDouble(),
            ));
            // What it holds in memory under this setting, the graphics chip's share above all.
            final Map<String, Object?> mem = await t.lens(<String, Object?>{
              'op': 'memory',
            });
            final (int cache, int iconBytes) = _pictureBytes();
            t.glassMemory.add((
              label,
              <String, double>{
                'total': ((mem['pss'] as num?) ?? 0) / 1024,
                'graphics': ((mem['mem_graphics'] as num?) ?? 0) / 1024,
                'native': ((mem['mem_native'] as num?) ?? 0) / 1024,
                'pictures': (cache + iconBytes) / 1048576,
              },
            ));
          }
        }
        base();
        await Apps.instance.setPrismIcons(listIconsWere);
        await Apps.instance.setPrismIcons(blobIconsWere, blobs: true);
      } else
      // ---------------------------------------------------------------- chat heads and the battery
      if (drain) {
        if (!floats) {
          t.note(
            'Prism is not allowed over other apps, so nothing could float and nothing was measured',
          );
        } else {
          final void Function(int)? rest = lensOf.testRest;
          const List<String> states = <String>[
            'nothing floating',
            'a blob',
            'the timer',
            'a blob and the timer',
          ];
          // Three times each, in a turning order, so that the battery's own drift falls on all alike.
          for (int r = 1; r <= 3; r++) {
            for (int k = 0; k < 4; k++) {
              // (Each round begins with something on the screen: the first thing seen is that it works.)
              final int i = (k + r) % 4;
              final bool blob = i == 1 || i == 3, timer = i >= 2;
              say(
                'measuring the battery, ${(r - 1) * 4 + k + 1} of 12: ${i == 0 ? 'nothing floating, on purpose' : states[i]}, about ${((12 - (r - 1) * 4 - k) * (still + 12) / 60).ceil()} min left',
              );
              await t.lens(<String, Object?>{'op': 'side', 'on': blob});
              if (timer && rest != null) {
                // A visit to the workout page brings back a timer that was closed.
                _go(1);
                await Robot.wait(700);
                _go(0);
                await Robot.wait(700);
                rest(still + 90);
              } else {
                lensOf.onStop?.call();
              }
              await Robot.wait(1500);
              await t.phase('round $r: ${states[i]}', still, away: true);
            }
          }
          lensOf.onStop?.call();
          await t.lens(<String, Object?>{'op': 'side', 'on': true});
          t.drainStates = states;
        }
      } else {
        // ---------------------------------------------------------------- power
        final int brief = (still * 0.75).round();
        say(
          'sitting still to measure power, about ${((floats ? 7 * still + 3 * brief : still + 2 * brief) / 60).ceil()} minutes',
        );
        await calm();
        if (_tab != 0) {
          _go(0);
          await Robot.wait(900);
        }
        await t.phase('Home, nothing open', still);
        await Robot.tap(_home, after: 1500);
        await t.phase('blobs out', brief);
        await calm();
        await Robot.drag(
          <Offset>[_home, _home - const Offset(0, 90)],
          legMs: 90,
          flick: true,
          after: 1500,
        );
        await t.phase('app list open', brief);
        await calm();
        if (floats) {
          await t.phase(
            'another app in front, nothing floating',
            still,
            away: true,
          );
          await Robot.tap(_home, after: 800);
          await Robot.drag(
            <Offset>[seat(1), Offset(sc.width + 30, sc.height * 0.3)],
            legMs: 500,
            dwell: 250,
            after: 1700,
          );
          await t.phase('a blob floating, in Prism', still);
          await t.phase(
            'another app in front, a blob floating',
            still,
            away: true,
          );
          final void Function(int)? rest = lensOf.testRest;
          if (rest != null) {
            // The timer was dropped on the cross earlier: a visit to the workout page brings it back.
            _go(1);
            await Robot.wait(800);
            _go(0);
            await Robot.wait(800);
            t.timer = true;
            rest(still + 120);
            await Robot.wait(1500);
            await t.phase(
              'rest running in the floating timer, in Prism',
              still,
            );
            rest(still + 120);
            await t.phase(
              'another app in front, rest running in the floating timer',
              still,
              away: true,
            );
            rest(2);
            await Robot.wait(6500);
            await t.phase(
              'another app in front, timer between sets',
              still,
              away: true,
            );
            final Map<String, Object?> m = await press(
              'timer tapped for the power reading',
              <Offset>[],
              holdMs: 40,
              settleMs: 1300,
            );
            if (m['sheet'] == true) {
              await t.phase('the timer\'s sheet open, in Prism', brief);
              await t.lens(<String, Object?>{'op': 'sheet', 'what': 'back'});
            }
            lensOf.onStop?.call();
            t.timer = false;
          }
        }
      }
      final Map<String, Object?> last = await t.lens(<String, Object?>{
        'op': 'end',
      });
      if (!drain) {
        t.note(
          'the rest in the timer readings was ${still + 120} s long; each still stretch was $still s (${(still * 0.75).round()} s for the shorter ones)',
        );
      }
      build =
          '${Diag.build}  ·  $title${drain ? '' : ', $rounds round${rounds == 1 ? '' : 's'}'}  ·  ${DateTime.now().toString().substring(0, 16)}${begun['model'] == null ? '' : '\n${begun['model']}  ·  chip ${begun['soc']}  ·  Android ${begun['android']}  ·  ${(begun['hz'] as num?)?.round() ?? '?'} Hz  ·  ${begun['ramGb']} GB memory  ·  battery about ${begun['battMah']} mAh when full'}\nscreen ${w.round()}x${h.round()} at ${dp}x  ·  allowed over other apps: ${floats ? 'yes' : 'NO'}  ·  ${last['blobs']} blobs known to Android';
    } catch (e, where) {
      if (e is TestStopped) {
        stoppedAt = Robot.stoppedWhile
            .replaceAll(' Hands off, please.', '')
            .replaceFirst(RegExp(r'^Test[^:]*: '), '');
      } else {
        t.check('the test ran to the end', false, '$e\n$where');
      }
    } finally {
      // From here nothing is stopped: everything is put back as it was.
      Robot.end();
      // Everything as it was.
      await calm();
      lensOf.onStop?.call();
      for (int i = 0; i < keysWere.length; i++) {
        BlobSlots.instance.keys[i] = keysWere[i];
      }
      BlobSlots.instance.put(0, keysWere[0]);
      if (BlobSlots.instance.names != namesWere) {
        _setNames(namesWere);
      }
      lensOf.setFloating(inPrism: inWas, overApps: outWas);
      settings.showFps = fpsWas;
      settings.quality = qualityWas;
      Diag.instance.glassMode.value = glassWas;
      Diag.instance.wallpaperOn.value = lightsWas;
      if (Look.instance.vibe != vibeWas) {
        Look.instance.choose(vibe: vibeWas);
      }
      settings.reduceTransparency = solidWas;
      lensOf.setPin(pinWas);
      _sendPin();
      if (_tab != 0) {
        _go(0);
      }
      await t.lens(<String, Object?>{'op': 'end'});
      Haptics.enabled = hapticsWere;
      t.close();
      Diag.instance.banner.value = null;
      _testing = false;
      final String text = t.report(<String>[
        ...build.split('\n'),
        ...settingsWere,
        if (adjusted.isNotEmpty)
          'SET FOR THE TEST, and put back afterwards: ${adjusted.join('  ·  ')}',
        if (stoppedAt != null)
          'STOPPED BY YOU while it was at: $stoppedAt (what follows is as far as it got)',
      ]);
      if (Platform.environment['PRISM_LONG_TEST'] != null) {
        // ignore: avoid_print
        print(text);
      }
      TestRun.keep(text);
      Diag.instance.finished.value = text;
    }
  }

  void _showReport() {
    final String? text = Diag.instance.finished.value;
    if (text == null || !mounted) {
      return;
    }
    Diag.instance.finished.value = null;
    Haptics.thud();
    final bool stopped = text.contains('STOPPED BY YOU');
    final TextEditingController note = TextEditingController();
    // The report with what the person wrote, if anything, at its end.
    String withNote() => note.text.trim().isEmpty
        ? text
        : '$text\n\nNOTE FROM YOU: ${note.text.trim()}';
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      pageBuilder: (BuildContext context, _, _) {
        final LumenColors c = LumenColors.of(context);
        return SafeArea(
          child: Padding(
            // (Lifted above the keyboard while a note is being written.)
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              12 + MediaQuery.viewInsetsOf(context).bottom,
            ),
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
                      stopped ? 'Test stopped' : 'Test finished',
                      style: LumenType.display(26, weight: 700, color: c.ink),
                    ),
                    Text(
                      stopped
                          ? 'Your settings are back as they were. Say what you saw, if you like, then copy this and paste it to Claude.'
                          : 'Your settings are back as they were. Copy this and paste it to Claude.',
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
                    // Anything the person wants to add: it goes at the end of the report.
                    TextField(
                      controller: note,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: LumenType.text(15, color: c.ink, height: 1.3),
                      decoration: InputDecoration(
                        hintText: 'What did you see? (optional)',
                        hintStyle: LumenType.text(15, color: c.inkMuted),
                        filled: true,
                        fillColor: c.ink.withValues(alpha: 0.06),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Pressable(
                      onTap: () async {
                        final String text = withNote();
                        // Kept with the note, so "Copy the last report" has it too.
                        TestRun.keep(text);
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
        _darkSync();
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

  // How many fingers are on the screen now.
  int _fingers = 0;

  /// The last finger has left the screen. Whatever happened, the magnifying glass is now either
  /// put down on something with things to do, or at home: it is never left out with no finger
  /// holding it, and the cards are never left lit up.
  void _fingerOff() {
    _fingers = math.max(0, _fingers - 1);
    if (_fingers > 0) {
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (!mounted || _fingers > 0 || _testing) {
        return;
      }
      final bool held = _carrying && _downAt == null && !_regrab;
      final bool lit =
          !_carrying &&
          !_parked &&
          !_returning &&
          LensBus.instance.pos.value != null;
      if (held || lit) {
        Diag.instance.event(
          'the magnifying glass was left out with no finger on it: sent home',
        );
        _lensHome();
      }
    });
  }

  void _lensHome() {
    final bool away = _glass.value > 0.05, wasParked = _parked;
    _retFrom = Offset(_lx.value, _ly.value);
    // It flies home as the dark glass it is about to be again; let go as a pill, it starts
    // from the pill's own colour.
    _retColor =
        (_parked ? _pill?.widget.color : null) ??
        lensTone(LumenColors.of(context).accent);
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

  // How fast the finger on the button is going just now, in pixels a millisecond, smoothed
  // over its last few movements; and where and when it was last measured.
  double _pace = 0;
  Offset? _paceFrom;
  int _paceMs = 0;

  /// Whether the finger is in the middle of a flick up for the app list: going upward, fast,
  /// this very moment, and not down long. Such a finger is not given the magnifying glass, so
  /// that the glass and the cards it wakes are never seen for a moment under a flick. A carry
  /// upward is slower than this, and gets the glass as before; a fast one gets it the moment
  /// it slows.
  bool _flicking() {
    final Offset? down = _downAt, last = _lastAt;
    if (down == null || last == null) {
      return false;
    }
    final Offset travel = last - down;
    final int ms = _held.elapsedMilliseconds;
    // Fast, it is a flick for a quarter of a second. Slower but still on its way up, it may
    // yet be a slow flick, for a little less long. Resting, or barely moving, it is a carry.
    return travel.dy < 0 &&
        travel.dx.abs() < -travel.dy * 0.8 &&
        ms - _paceMs < 80 &&
        (_pace > 0.7 ? ms < 260 : (_pace > 0.25 && ms < 220));
  }

  /// A finger that moved and then stopped sends no more movement, so the lift is also timed.
  void _liftCheck() {
    // (A hold that has started the changing of the blobs is not a carry.)
    if (_downAt == null ||
        !_moved ||
        _lifted ||
        _drawerOpen ||
        _heldEdit ||
        !mounted) {
      return;
    }
    if (_flicking()) {
      // Still on its way up: looked at again in a moment.
      _liftTimer = Timer(const Duration(milliseconds: 40), _liftCheck);
      return;
    }
    _liftOff();
    final Offset at = _lastAt ?? _home;
    _lx.animateTo(at.dx);
    _ly.animateTo(at.dy - 62);
  }

  void _buttonMove(PointerMoveEvent e) {
    if (_downAt == null) {
      return;
    }
    _lastAt = e.position;
    final int nowMs = _held.elapsedMilliseconds;
    if (_paceFrom != null && nowMs > _paceMs) {
      final double v = (e.position - _paceFrom!).distance / (nowMs - _paceMs);
      _pace = _pace == 0 ? v : _pace * 0.4 + v * 0.6;
    }
    if (_paceFrom == null || nowMs > _paceMs) {
      _paceFrom = e.position;
      _paceMs = nowMs;
    }
    final Size screen = MediaQuery.sizeOf(context);
    final Offset travel = e.position - _downAt!;
    if (!_moved) {
      if (travel.distance < 10) {
        return;
      }
      _moved = true;
      _movedAt = _held.elapsedMilliseconds;
      _holdTimer?.cancel();
      _setOpen(false);
    }
    if (_heldEdit) {
      // The hold has started the changing of the blobs: moving on does not bring the glass out.
      return;
    }
    if (!_lifted) {
      // Not a lens yet. A quick upward movement is probably a flick for the app drawer, and a
      // flick should not light up the glass or wake the cards. The button only lifts off once
      // the movement is clearly a carry: slow, sideways or downward, or simply held long enough.
      final int ms = _held.elapsedMilliseconds;
      final bool upward = travel.dy < 0 && travel.dx.abs() < -travel.dy * 0.8;
      // A carry needs real evidence: a finger that has been down a while, or one that has gone
      // a fair way sideways or down. A short quick nudge is none of these and lifts nothing.
      // Going upward, it is a carry as soon as it is plainly not a flick: it has gone a little
      // way and is taking its time over it. A flick covers the same ground several times faster.
      // (How fast it is going is counted from when it began to move, not from when the
      // finger came down: a finger that rests a moment and then flicks is still flicking.)
      final int moving = ms - _movedAt;
      final double pace = travel.distance / math.max(moving, 1);
      final bool carry =
          !_flicking() &&
          (ms >= 140 ||
              (!upward && travel.distance > 22) ||
              (upward && travel.distance > 24 && moving >= 24 && pace < 0.6));
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
    _liftedAt = _held.elapsedMilliseconds;
    setState(() {
      _carrying = true;
      _returning = false;
      // (The black under the glass follows: see _darkSync.)
      WidgetsBinding.instance.addPostFrameCallback((_) => _darkSync());
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
    _holdTimer?.cancel();
    _kick.animateTo(1);
    if (_downAt == null) {
      return;
    }
    final Offset travel = (_lastAt ?? _downAt!) - _downAt!;
    _downAt = null;
    if (_heldEdit) {
      // The hold has done its work: letting go does nothing more. (Should the glass have come
      // out after all, it goes home: the flight recorder found it left out from here.)
      _heldEdit = false;
      if (_lifted || _carrying) {
        _lensHome();
      }
      return;
    }
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
    } else if (_lifted &&
        _held.elapsedMilliseconds - _liftedAt < 180 &&
        _held.elapsedMilliseconds < 380 &&
        travel.dy < -60 &&
        travel.dx.abs() < -travel.dy * 0.8) {
      // The same flick, a slower one: the lens had only just come out when the finger left.
      // It was a flick all the same, so the lens is put away and the app drawer comes up.
      _lensQuiet();
      _setDrawer(true);
    } else if (!_lifted && _open && _editing) {
      // While the blobs are being changed the button shows a cog, and a tap on it is for
      // the floating elements. (A tap beside the blobs, or back, ends the changing.)
      _showFloating();
    } else if (!_lifted && _parked) {
      // The magnifying glass is out and put down somewhere. A tap on the place it lives
      // calls it home; the next tap is for the blobs.
      _lensHome();
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
      // (The black under the glass follows: see _darkSync.)
      WidgetsBinding.instance.addPostFrameCallback((_) => _darkSync());
      _target = null;
    });
    _lx.jumpTo(_home.dx);
    _ly.jumpTo(_home.dy);
    _glass.jumpTo(0);
    _morph.jumpTo(0);
    _say.jumpTo(0);
    LensBus.instance.pos.value = null;
  }

  // The bar gives up its glass only while a sheet is all the way up and hides it completely:
  // then nobody can see the change, in either direction. It is glass again from the moment the
  // sheet starts down. (Before, it stayed without its glass until half a second after the sheet
  // had gone, and what was behind the bar showed through sharp for that long.)
  bool _sheetHides = false;
  void _sheetMoved() {
    final bool hides = _sheetOpen && _rise.value > 0.985;
    if (hides != _sheetHides && mounted) {
      setState(() => _sheetHides = hides);
    }
  }

  void _setDrawer(bool v) {
    if (v == _drawerOpen) {
      return;
    }
    // The app list does not come up over a magnifying glass that was left out.
    if (v && _parked) {
      _lensHome();
    }
    // The drawer may have been up to choose what takes a blob's place.
    final bool choosing = !v && _editSlot != null;
    _setOpen(false);
    setState(() {
      _drawerOpen = v;
      if (choosing) {
        _editSlot = null;
      }
    });
    _t.animateTo(v ? 1 : 0);
    _signSync();
    Diag.instance
      ..overlay = v ? '+drawer' : ''
      ..event(v ? 'drawer open' : 'drawer close');
    Haptics.settle();
    if (choosing) {
      // Chosen or not, the blobs come back out, still being changed.
      _setOpen(true);
    }
  }

  // The magnifying glass, put down on something, has been picked up again by dragging it.
  bool _regrab = false;

  void _pillGrab() {
    if (!_parked) {
      return;
    }
    _regrab = true;
    setState(() {
      _parked = false;
      _carrying = true;
      _returning = false;
      // (The black under the glass follows: see _darkSync.)
      WidgetsBinding.instance.addPostFrameCallback((_) => _darkSync());
    });
    // The same as when it leaves the button.
    Haptics.settle();
    Diag.instance
      ..overlay = '+lens'
      ..event('lens picked up again');
  }

  /// It rides above the finger, as it does when carried from the button.
  void _pillCarry(Offset at) {
    if (!_regrab || !_carrying) {
      return;
    }
    final Size screen = MediaQuery.sizeOf(context);
    _lx.animateTo(at.dx.clamp(_lensSize / 2, screen.width - _lensSize / 2));
    _ly.animateTo(
      (at.dy - 62).clamp(_lensSize / 2 + 30, screen.height - _lensSize / 2),
    );
  }

  /// Let go: over something with things to do it stays; anywhere else it goes home.
  void _pillDrop() {
    if (!_regrab) {
      return;
    }
    _regrab = false;
    if (!_carrying) {
      return;
    }
    if (_target != null && _target!.widget.actions.isNotEmpty) {
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
    _cogHint.dispose();
    _signTurn.dispose();
    _signShot.dispose();
    _dark.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _freeLater?.cancel();
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
    // The magnifying glass is over something on the page being left: it goes home.
    if (_parked || _carrying) {
      _lensHome();
    }
    setState(() => _tab = tab);
    RestBubble.instance.page(tab == 1);
    RestBubble.instance.tellTab(tab);
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
    setState(() {
      _open = v;
      // No blob is left picked up, or on its way back, from the last time.
      _dragI = null;
      _backI = null;
      // Closing them ends the changing, unless they are only out of the drawer's way.
      if (!v && _editSlot == null) {
        _editing = false;
      }
    });
    _signSync();
    Diag.instance
      ..overlay = v ? '+blobs' : ''
      ..event(v ? 'blobs open' : 'blobs close');
    _gapAt = null;
    _stuck = false;
    _backScale = 1;
    _t.animateTo(v ? 1 : 0);
    _tellFan();
    for (final Timer t in _fuses) {
      t.cancel();
    }
    _fuses.clear();
    if (v) {
      // The blobs in the menu take their seats and shoot out, one a moment after another.
      // What is floating as the lens is not among them.
      _awayI = null;
      _reseat(jump: true);
      int order = 0;
      final int? join = _joinI;
      _joinI = null;
      for (int i = 0; i < _n; i++) {
        _gone[i].jumpTo(_isEmpty(i) || i == join ? 1 : 0);
        if (_floating(i) || _isEmpty(i)) {
          continue;
        }
        if (i == join) {
          // Just given something: it is out in the middle, as itself, and then comes down to
          // its seat among the others.
          _out[i].jumpTo(1);
          _fuses.add(
            Timer(
              const Duration(milliseconds: 240),
              () => _gone[i].animateTo(0, spring: Motions.spatial),
            ),
          );
          continue;
        }
        _fuses.add(
          Timer(
            Duration(milliseconds: order * 18),
            () => _out[i].animateTo(1, spring: _shoot),
          ),
        );
        order++;
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
    if (_isScreen(i)) {
      // One of Prism's own pages: straight to it.
      _setOpen(false);
      Haptics.settle();
      _go(_screenAt(i));
      return;
    }
    if (_isApp(i)) {
      final BlobApp? a = _blobApp(i);
      final AppTile? t = _tile(i);
      _setOpen(false);
      Diag.instance.event('open ${_blobName(i)}');
      // The app opens out of the blob that was tapped.
      final double dpr = MediaQuery.devicePixelRatioOf(context);
      final double angle = _seatAngle(_seat[i].value);
      final Offset at =
          _home + Offset(-math.cos(angle), -math.sin(angle)) * _far.value;
      final Rect from = Rect.fromCenter(
        center: at * dpr,
        width: _blob * dpr,
        height: _blob * dpr,
      );
      if (a != null) {
        BlobApps.instance.launch(a, from: from).then((bool ok) {
          if (!ok) {
            Haptics.thud();
          }
        });
      } else if (t != null) {
        Apps.instance.launch(t, from: from);
      } else {
        Haptics.thud();
      }
      return;
    }
    _run(_actionAt(i));
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
      final double a = _seatAngle(_seat[i].value);
      return bc + Offset(-math.cos(a), -math.sin(a)) * _far.value;
    }

    // A blob is picked up by a finger at [at]: it comes along from where it sits, and its
    // seat is kept open for it.
    void grab(int i, Offset at) {
      if (_isEmpty(i)) {
        return;
      }
      _dragGrab = at - rest(i);
      _dragAt.value = rest(i);
      _armed = false;
      _stuck = false;
      if (!_editing) {
        // How large the lens is now, for where a side stops it.
        final double dpr = MediaQuery.devicePixelRatioOf(context);
        RestBubble.instance.lensSize().then((double? px) {
          if (px != null && px > 0) {
            _floatSize = px / dpr;
          }
        });
      }
      final List<int> others = _others(i);
      setState(() {
        _dragI = i;
        _backI = null;
        _awayI = i;
        _gapAt = others.where((int k) => k < i).length;
      });
      _reseat();
      Haptics.tick();
    }

    // Where an empty place is shown while the blobs are being changed: in a row across the
    // middle of the screen, the row always centred.
    Offset mid(int i) =>
        Offset(screen.width / 2 + _midX[i].value, screen.height * 0.42);

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
        } else if (_open && _editing) {
          Diag.instance.event('back: done changing blobs');
          _setEditing(false);
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
        // (Two fingers moved together are the person's own shortcuts, anywhere in Prism.)
        // (Every finger on the screen is counted, so that the magnifying glass can never be left
        // out with no finger holding it.)
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _fingers++,
          onPointerUp: (_) => _fingerOff(),
          onPointerCancel: (_) => _fingerOff(),
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: _twoFingers,
            child: Stack(
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
                // And under the bar at the foot: the same shade, deep enough to reach under
                // Android's own buttons where the phone has them, so nothing shows through there.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: safe.bottom + 14 + _barH * 0.6,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            c.bg.withValues(alpha: 0),
                            c.bg.withValues(alpha: 0.85),
                            c.bg.withValues(alpha: 0.96),
                          ],
                          stops: const <double>[0, 0.55, 1],
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
                // The bar.
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: safe.bottom + 14,
                  height: _barH,
                  // While the blobs are out, the bar is not for changing pages: a tap anywhere on it
                  // falls through to the dim behind it, which closes the blobs.
                  child: IgnorePointer(
                    ignoring: _open,
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints box) {
                        if (_barW != box.maxWidth) {
                          _barW = box.maxWidth;
                          scheduleMicrotask(() => _lensX.jumpTo(_centre(_tab)));
                        }
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (TapUpDetails d) {
                            final int s = (d.localPosition.dx / _slot)
                                .floor()
                                .clamp(0, 4);
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
                              final double stretch =
                                  (_lensX.velocity.abs() / 70).clamp(0.0, 26.0);
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
                              // While a sheet is up the bar sits dimmed underneath it, and glass there is
                              // blurred again on every frame for something nobody is looking at. So it
                              // goes solid meanwhile. Under the app drawer it does not: there the bar is
                              // in plain sight, and must be the same bar it is under the blobs.
                              final bool covered = _sheetOpen && _sheetHides;
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
                              // Whenever the bar is not real glass, it is clear glass: a tint over
                              // whatever is behind it, with the rim and the light of glass. What scrolls
                              // under it shows through, and it costs nothing to draw.
                              final bool still = barSolid && !off;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: <Widget>[
                                  if (still)
                                    Positioned.fill(
                                      child: StillGlass(
                                        radius: _barH / 2,
                                        // Dark enough that the labels read over anything, clear
                                        // enough that what passes underneath is seen passing.
                                        tint: c.glassTint.withValues(
                                          alpha: 0.6,
                                        ),
                                        rim: Colors.white.withValues(
                                          alpha: c.dark ? 0.34 : 0.9,
                                        ),
                                        clear: true,
                                        stamp: Look.instance.frostReady.value,
                                      ),
                                    ),
                                  Positioned.fill(
                                    child: Glass(
                                      radius: _barH / 2,
                                      // Clear glass: softened just enough that words scrolling under it do
                                      // not fight the labels, and no more, so that the lights behind the
                                      // bar keep their shape as they pass under it.
                                      style: GlassStyle(
                                        blur: 4,
                                        tint: 0.27,
                                        refraction: 16,
                                        bevel: 12,
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
                                      quality: mode == 2
                                          ? GlassQuality.low
                                          : null,
                                    ),
                                  ),
                                  if (still)
                                    // The lens around the selected tab: clear glass that enlarges what is behind it.
                                    Positioned.fromRect(
                                      rect: lens,
                                      child: StillGlass(
                                        radius: h / 2,
                                        clear: true,
                                        tint: c.accent.withValues(alpha: 0.26),
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
                                                  ? c.accent.withValues(
                                                      alpha: 0.3,
                                                    )
                                                  : c.ink.withValues(
                                                      alpha: 0.10,
                                                    )),
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
                                                    final int i = s < 2
                                                        ? s
                                                        : s - 1;
                                                    // Brightness follows the lens, not the tap, so it reads as the lens lighting the tab.
                                                    final double on =
                                                        (1 -
                                                                ((_centre(i) -
                                                                            _lensX.value)
                                                                        .abs() /
                                                                    _slot))
                                                            .clamp(0.0, 1.0);
                                                    return Semantics(
                                                      button: true,
                                                      selected: i == _tab,
                                                      label: _tabs[i].$2,
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: <Widget>[
                                                          Transform.scale(
                                                            scale:
                                                                1 + 0.12 * on,
                                                            child: Icon(
                                                              _tabs[i].$1,
                                                              size: 23,
                                                              color: Color.lerp(
                                                                c.glassInk
                                                                    .withValues(
                                                                      alpha:
                                                                          0.6,
                                                                    ),
                                                                c.glassInk,
                                                                on,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 3,
                                                          ),
                                                          Text(
                                                            _tabs[i].$2,
                                                            textScaler:
                                                                TextScaler
                                                                    .noScaling,
                                                            style: LumenType.text(
                                                              10.5,
                                                              weight:
                                                                  560 +
                                                                  140 * on,
                                                              color: Color.lerp(
                                                                c.glassInk
                                                                    .withValues(
                                                                      alpha:
                                                                          0.6,
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
                ),
                // One dim for the blobs and for the drawer, over the page and over the bar alike. The
                // bar looks the same under both, so going from one to the other changes nothing on it.
                ListenableBuilder(
                  listenable: _t,
                  builder: (BuildContext context, Widget? _) => IgnorePointer(
                    ignoring: !_open,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // A tap beside the blobs closes them. While they are being changed it ends
                      // the changing first, and they stay out.
                      onTap: () =>
                          _editing ? _setEditing(false) : _setOpen(false),
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: 0.5 * _t.value.clamp(0.0, 1.0),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                // The app drawer, which grows out of the button.
                Positioned.fill(
                  child: AppDrawer(
                    open: _drawerOpen,
                    origin: bc,
                    button: _button,
                    tone: lensTone(c.accent),
                    onClose: () => _setDrawer(false),
                    // Up to choose what takes a blob's place: it says so, offers Prism's own
                    // actions as well as the apps, and a tap chooses.
                    pick: _editSlot == null ? null : _blobName(_editSlot!),
                    pickTitle: _editSlot != null && _editSlot! >= 100
                        ? (
                            'Swipe ${GestureSlots.names[_editSlot! - 100]}',
                            'with two fingers',
                          )
                        : null,
                    choices: <(String, String, IconData, Color)>[
                      // A swipe can also pull the phone's notifications down.
                      if (_editSlot != null && _editSlot! >= 100)
                        (
                          'phone:shade',
                          'Notifications',
                          Icons.notifications_rounded,
                          const Color(0xFF5A6373),
                        ),
                      for (int k = 0; k < _actions.length; k++)
                        (
                          'action:$k',
                          _actions[k].$1,
                          _actions[k].$2,
                          _actions[k].$3,
                        ),
                      for (int k = 0; k < _tabs.length; k++)
                        ('screen:$k', _tabs[k].$2, _tabs[k].$1, c.accent),
                    ],
                    onPick: _picked,
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
                        colors: <Color>[
                          for (int i = 0; i < _n; i++) _blobColor(i),
                        ],
                      ),
                    ),
                  ),
                ),
                // The blobs.
                for (int i = 0; i < _n; i++)
                  ListenableBuilder(
                    listenable: Listenable.merge(<Listenable>[
                      _out[i],
                      _seat[i],
                      _dragAt,
                      _dragBack,
                      _far,
                      _gone[i],
                      _midX[i],
                    ]),
                    builder: (BuildContext context, Widget? _) {
                      final double p = _out[i].value;
                      final bool empty = _isEmpty(i);
                      final double gone = _gone[i].value.clamp(0.0, 1.0);
                      if (_shotI == i) {
                        return const SizedBox.shrink();
                      }
                      if (empty && gone > 0.995) {
                        // An empty place, out in the middle. It is there only while the blobs are
                        // being changed: an outline with the edit mark, and a tap gives it something.
                        if (!_editing || !_open) {
                          return const SizedBox.shrink();
                        }
                        final Offset m = mid(i);
                        return Positioned(
                          left: m.dx - _blob / 2 - 6,
                          top: m.dy - _blob / 2 - 6,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _pickFor(i),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: _blobDisc(i),
                            ),
                          ),
                        );
                      }
                      if (p <= 0.001) {
                        return const SizedBox.shrink();
                      }
                      // Picked up, it is where the finger has it. Let go away from the button, it
                      // goes back to its place.
                      final bool held = _dragI == i;
                      final Offset among = held
                          ? _dragAt.value
                          : (_backI == i
                                ? rest(i) +
                                      (_dropAt - rest(i)) * _dragBack.value
                                : bc + (rest(i) - bc) * p);
                      // On its way out to the middle as an empty place, or back from there with
                      // something in it.
                      final Offset b = gone > 0.001
                          ? Offset.lerp(among, mid(i), gone)!
                          : among;
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
                      // Handed back by the lens, it starts the size it was in there.
                      final double back = _backI == i
                          ? 1 +
                                (_backScale - 1) *
                                    _dragBack.value.clamp(0.0, 1.0)
                          : 1.0;
                      return Positioned(
                        left: b.dx - _blob / 2 - 20,
                        // (Eight above the blob as well, so the marks on its corners can be tapped.)
                        top: b.dy - _blob / 2 - 8,
                        width: _blob + 40,
                        child: IgnorePointer(
                          ignoring: !_open,
                          child: Opacity(
                            opacity: (p * 12).clamp(0.0, 1.0),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              // A tap uses it. Picked up and put down somewhere, it floats
                              // there; on the button, or flicked at it, the button shoots it out
                              // to the side. Held, all the blobs can be changed: each wears an
                              // edit mark, and a tap on one then changes that one.
                              // While the blobs are being changed, a tap on the red minus
                              // takes this one away and a tap anywhere else on it changes it.
                              // (The minus hangs over the blob's corner; where the tap landed
                              // is worked out here so that every part of it answers.)
                              onTapUp: (TapUpDetails d) {
                                if (!_editing) {
                                  _blobTap(i);
                                  return;
                                }
                                final Offset from =
                                    d.localPosition -
                                    const Offset(
                                      (_blob + 40) / 2,
                                      8 + _blob / 2,
                                    );
                                if (!empty &&
                                    (from - const Offset(-21, -21)).distance <
                                        21) {
                                  _removeBlob(i);
                                } else {
                                  _pickFor(i);
                                }
                              },
                              // Held: the blobs can be changed. Held and then moved without
                              // letting go, it comes along, as on any drag.
                              onLongPressStart: (LongPressStartDetails d) {
                                _holdFrom = d.globalPosition;
                                _setEditing(true);
                              },
                              onLongPressMoveUpdate:
                                  (LongPressMoveUpdateDetails d) {
                                    if (_dragI != i) {
                                      if ((d.globalPosition - _holdFrom)
                                              .distance <
                                          10) {
                                        return;
                                      }
                                      grab(i, d.globalPosition);
                                    }
                                    _blobDrag(
                                      i,
                                      d.globalPosition - _dragGrab,
                                      bc,
                                    );
                                  },
                              onLongPressEnd: (LongPressEndDetails d) =>
                                  _blobDrop(i, bc, d.velocity.pixelsPerSecond),
                              // Dragged. While the blobs are being changed that only puts them
                              // in another order.
                              onPanStart: (DragStartDetails d) =>
                                  grab(i, d.globalPosition),
                              onPanUpdate: (DragUpdateDetails d) => _blobDrag(
                                i,
                                d.globalPosition - _dragGrab,
                                bc,
                              ),
                              onPanEnd: (DragEndDetails d) =>
                                  _blobDrop(i, bc, d.velocity.pixelsPerSecond),
                              onPanCancel: () => _blobDrop(i, bc, Offset.zero),
                              child: Column(
                                children: <Widget>[
                                  const SizedBox(height: 8),
                                  Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.rotationZ(ang)
                                      ..scaleByDouble(
                                        s * back * (1 + st) * (held ? 1.08 : 1),
                                        s *
                                            back *
                                            (1 - st * 0.5) *
                                            (held ? 1.08 : 1),
                                        1,
                                        1,
                                      )
                                      ..rotateZ(-ang),
                                    // While the blobs are being changed each one wears its marks:
                                    // the pencil on the right, to change it, and the red minus
                                    // on the left, to take it away.
                                    child: _editing
                                        ? Stack(
                                            clipBehavior: Clip.none,
                                            children: <Widget>[
                                              _blobDisc(i),
                                              const Positioned(
                                                right: -4,
                                                top: -4,
                                                child: _EditMark(
                                                  icon: Icons.edit_rounded,
                                                ),
                                              ),
                                              if (!empty)
                                                const Positioned(
                                                  left: -4,
                                                  top: -4,
                                                  child: _EditMark(
                                                    icon: Icons.remove_rounded,
                                                    color: Color(0xFFE5484D),
                                                    ink: Colors.white,
                                                  ),
                                                ),
                                            ],
                                          )
                                        : (_blobNotes(i) > 0 && p > 0.9
                                              // An app with notifications wears their number.
                                              ? Stack(
                                                  clipBehavior: Clip.none,
                                                  children: <Widget>[
                                                    _blobDisc(i),
                                                    Positioned(
                                                      right: -4,
                                                      top: -4,
                                                      child: _noteBadge(i),
                                                    ),
                                                  ],
                                                )
                                              : _blobDisc(i)),
                                  ),
                                  const SizedBox(height: 7),
                                  // The name appears once the blob is nearly there, not while it is a speck.
                                  Opacity(
                                    opacity: held
                                        ? 0
                                        : ((p - 0.6) / 0.4).clamp(0.0, 1.0) *
                                              (1 - gone) *
                                              ((_far.value - _reachBare) /
                                                      (_reach - _reachBare))
                                                  .clamp(0.0, 1.0),
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
                // While the blobs are being changed: the switch for their names, above them. (The
                // marks on the blobs say the rest.)
                if (_editing && _open)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: screen.height - (bc.dy - _reach - _blob / 2 - 22),
                    child: ListenableBuilder(
                      listenable: _t,
                      builder: (BuildContext context, Widget? _) => Opacity(
                        opacity: _t.value.clamp(0.0, 1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // Names under the blobs, on or off. White, like the marks on the
                            // blobs: the things that can be tapped while changing.
                            GestureDetector(
                              key: Robot.key('names'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _setNames(!BlobSlots.instance.names),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: const ShapeDecoration(
                                    color: Colors.white,
                                    shape: StadiumBorder(),
                                    shadows: <BoxShadow>[
                                      BoxShadow(
                                        color: Color(0x55000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        BlobSlots.instance.names
                                            ? Icons.label_off_rounded
                                            : Icons.label_rounded,
                                        size: 16,
                                        color: const Color(0xFF15171C),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        BlobSlots.instance.names
                                            ? 'Hide labels'
                                            : 'Show labels',
                                        textScaler: TextScaler.noScaling,
                                        style: LumenType.text(
                                          14,
                                          weight: 650,
                                          color: const Color(0xFF15171C),
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // A blob dropped on the button: taken in under it, then shot out to the side on a
                // thread, to become the floating lens.
                if (_shotI != null)
                  ListenableBuilder(
                    listenable: Listenable.merge(<Listenable>[_gulp, _shot]),
                    builder: (BuildContext context, Widget? _) {
                      final int i = _shotI!;
                      final double g = _gulp.value.clamp(0.0, 1.0),
                          out = _shot.value;
                      final bool away = _shot.target > 0.5;
                      final Offset at = away
                          ? bc + (_shotTo - bc) * out
                          : _shotFrom + (bc - _shotFrom) * g;
                      final double size = away
                          ? ui.lerpDouble(
                              0.5,
                              _shotScale,
                              math.pow(out.clamp(0.0, 1.0), 0.7).toDouble(),
                            )!
                          : ui.lerpDouble(1.08, 0.5, g)!;
                      // Stretched along its flight while it is fast.
                      final double st = away
                          ? (_shot.velocity.abs() * 0.06).clamp(0.0, 0.5)
                          : 0;
                      final Offset dir = _shotTo - bc;
                      final double ang = math.atan2(dir.dy, dir.dx);
                      return Stack(
                        children: <Widget>[
                          if (away)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _ThreadPainter(
                                    from: bc,
                                    to: <Offset>[_shotTo],
                                    out: <SpringValue>[_shot],
                                    colors: <Color>[_blobColor(i)],
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: at.dx - _blob / 2,
                            top: at.dy - _blob / 2,
                            child: IgnorePointer(
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.rotationZ(ang)
                                  ..scaleByDouble(
                                    size * (1 + st),
                                    size * (1 - st * 0.5),
                                    1,
                                    1,
                                  )
                                  ..rotateZ(-ang),
                                child: _blobDisc(i),
                              ),
                            ),
                          ),
                        ],
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
                        // Held still while the blobs are out: the same as holding a blob.
                        _heldEdit = false;
                        _holdTimer?.cancel();
                        if (_open && !_editing && !_drawerOpen) {
                          _holdTimer = Timer(
                            const Duration(milliseconds: 450),
                            () {
                              if (_downAt != null &&
                                  !_moved &&
                                  _open &&
                                  !_editing &&
                                  mounted) {
                                _heldEdit = true;
                                _setEditing(true);
                              }
                            },
                          );
                        }
                        // A finger that moved and then stopped sends no more movement, so the wait is also timed.
                        _pace = 0;
                        _paceFrom = null;
                        _paceMs = 0;
                        _liftTimer?.cancel();
                        _liftTimer = Timer(
                          const Duration(milliseconds: 140),
                          _liftCheck,
                        );
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
                          _cog,
                          _cogHint,
                          _signTurn,
                          _signShot,
                          _dark,
                        ]),
                        builder: (BuildContext context, Widget? _) =>
                            Transform.scale(
                              // (The glass is drawn a little larger than its place in the bar, so it
                              // rises just past the bar's edge: the piece the rest is set around.
                              // The blob under it keeps its size: see _ButtonSign._blob.)
                              scaleX:
                                  _kick.value *
                                  (1 + _wob.value) *
                                  _ButtonSign.grow,
                              scaleY:
                                  _kick.value *
                                  (1 - _wob.value) *
                                  _ButtonSign.grow,
                              child: _glass.value > 0.5 || _returning
                                  // While the glass is lifted away, the prism stays: only the glass
                                  // went, as a magnifying glass picked up off what it lay on. No ring:
                                  // the sign alone, where it always is.
                                  ? Container(
                                      width: _button,
                                      height: _button,
                                      alignment: Alignment.center,
                                      child: CustomPaint(
                                        size: const Size(38, 38),
                                        painter: _ButtonSign(
                                          blobs: _fanBlobs,
                                          turn: _signTurn.value,
                                          vivid: Apps.instance.blobVivid,
                                          glass: false,
                                          dark: _dark.value,
                                          cog: _cog.value,
                                          look: Apps.instance.blobLook,
                                          rim: _button / 2 - 2,
                                        ),
                                      ),
                                    )
                                  // The button is the home of the floating lens, and looks like it:
                                  // dark glass with a breath of Prism's colour, a lit rim, and a
                                  // glow at its foot. The buttons that simply do something are the
                                  // bright ones; this one opens things out, and is not one of them.
                                  : Container(
                                      width: _button,
                                      height: _button,
                                      decoration: const ShapeDecoration(
                                        shape: CircleBorder(),
                                        shadows: <BoxShadow>[
                                          BoxShadow(
                                            color: Color(0x66000000),
                                            blurRadius: 14,
                                            offset: Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: CustomPaint(
                                        painter: _LensDisc(c.accent),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.center,
                                          children: <Widget>[
                                            // The button's sign: always the Blob's sign, turned to say what is open,
                                            // and drawn in to the cog while the blobs are being changed.
                                            CustomPaint(
                                              size: const Size(38, 38),
                                              painter: _ButtonSign(
                                                blobs: _fanBlobs,
                                                turn: _signTurn.value,
                                                shot: _signShot.value,
                                                vivid: Apps.instance.blobVivid,
                                                dark: _dark.value,
                                                cog: _cog.value,
                                                look: Apps.instance.blobLook,
                                                hint: _cogHint.value,
                                                rim: _button / 2 - 2,
                                                glint: c.accent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                            ),
                      ),
                    ),
                  ),
                ),
                // While the blobs are being changed: the two-finger swipes, across the top. Each has
                // its place, drawn as a blob is: what it does, or an empty ring. Making the swipe,
                // or a tap on its place, asks what it should do; the red minus takes that away.
                if (_editing && _open)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: safe.top + 44,
                    child: ListenableBuilder(
                      listenable: GestureSlots.instance,
                      // (On a dark patch of its own: the page shows through the dimming, and these
                      // must be readable over whatever is there.)
                      builder: (BuildContext context, Widget? _) => Center(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'Swipe with two fingers to set what it does',
                                textScaler: TextScaler.noScaling,
                                style: LumenType.text(
                                  14,
                                  weight: 600,
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  for (int g = 0; g < 4; g++)
                                    SizedBox(
                                      width: 82,
                                      child: Column(
                                        children: <Widget>[
                                          GestureDetector(
                                            key: Robot.key('gesture$g'),
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => _pickGesture(g),
                                            child: SizedBox(
                                              width: 76,
                                              height: 64,
                                              child: Stack(
                                                children: <Widget>[
                                                  Positioned(
                                                    left: 12,
                                                    top: 10,
                                                    width: 52,
                                                    height: 52,
                                                    child: FittedBox(
                                                      child: _blobDisc(100 + g),
                                                    ),
                                                  ),
                                                  if (!_isEmpty(100 + g))
                                                    const Positioned(
                                                      right: 2,
                                                      top: 0,
                                                      child: _EditMark(
                                                        icon:
                                                            Icons.edit_rounded,
                                                        size: 24,
                                                      ),
                                                    ),
                                                  if (!_isEmpty(100 + g))
                                                    Positioned(
                                                      left: 2,
                                                      top: 0,
                                                      child: GestureDetector(
                                                        key: Robot.key(
                                                          'gestureOff$g',
                                                        ),
                                                        behavior:
                                                            HitTestBehavior
                                                                .opaque,
                                                        onTap: () {
                                                          Haptics.thud();
                                                          Diag.instance.event(
                                                            'gesture ${GestureSlots.names[g]} cleared',
                                                          );
                                                          GestureSlots.instance
                                                              .put(g, 'empty:');
                                                        },
                                                        child: const _EditMark(
                                                          icon: Icons
                                                              .remove_rounded,
                                                          color: Color(
                                                            0xFFE5484D,
                                                          ),
                                                          ink: Colors.white,
                                                          size: 24,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          // Two arrows: two fingers, and which way.
                                          Icon(
                                            const <IconData>[
                                              Icons
                                                  .keyboard_double_arrow_down_rounded,
                                              Icons
                                                  .keyboard_double_arrow_up_rounded,
                                              Icons
                                                  .keyboard_double_arrow_left_rounded,
                                              Icons
                                                  .keyboard_double_arrow_right_rounded,
                                            ][g],
                                            size: 22,
                                            color: Colors.white.withValues(
                                              alpha: 0.82,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
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
                            end: lensTone(c.accent),
                            ink: Colors.white,
                            button: _button,
                            sign: _fanBlobs,
                          ),
                        ),
                      );
                    }
                    final LensTarget? pill = _pill?.widget,
                        said = _target?.widget;
                    final bool above = lens.top > safe.top + 150;
                    return Stack(
                      children: <Widget>[
                        if (_parked)
                          Positioned.fill(
                            key: const ValueKey<String>('lens away'),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _lensHome,
                            ),
                          ),
                        Positioned.fromRect(
                          // Keyed: the layer under it comes and goes, and a drag that began on
                          // the pill must not be dropped when it does.
                          key: const ValueKey<String>('lens body'),
                          rect: lens,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: _parked
                                ? (TapUpDetails d) => _pillTap(d.globalPosition)
                                : null,
                            // Put down, it can be dragged off again: it is picked up and
                            // carried from there, as it is from the button.
                            onPanStart: (_) => _pillGrab(),
                            onPanUpdate: (DragUpdateDetails d) =>
                                _pillCarry(d.globalPosition),
                            onPanEnd: (_) => _pillDrop(),
                            onPanCancel: _pillDrop,
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
                                      opacity: ((mm - 0.35) / 0.65).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          for (final (
                                                int i,
                                                (String, VoidCallback) a,
                                              )
                                              in pill
                                                  .actions
                                                  .indexed) ...<Widget>[
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
                                                  textScaler:
                                                      TextScaler.noScaling,
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
                            bottom: above
                                ? screen.height - lens.top + 12
                                : null,
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
                                          color: said.color.withValues(
                                            alpha: 0.7,
                                          ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  20,
                                ),
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
          // Starts it: the floating timer counts it, wherever you go next.
          cta('Start ${_sheetSeconds.round()} s', () {
            RestBubble.instance.testRest?.call(_sheetSeconds.round());
            _closeSheet();
          }),
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
    transitionDuration: panelTime,
    transitionBuilder: panelNoFade,
    pageBuilder: (BuildContext context, _, _) {
      final LumenColors c = LumenColors.of(context);
      return PanelRise(
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
                      const SizedBox(height: 10),
                      // How strong the colours are, for every colour above: a matter of taste.
                      Segmented<int>(
                        values: const <int>[0, 1, 2],
                        labels: Look.strengths,
                        value: Look.instance.strength,
                        onChanged: (int v) => Look.instance.choose(strength: v),
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
                          values: const <int>[0, 1, 2, 3, 4],
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
                        'Glass style',
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
                        listenable: RestBubble.instance.container,
                        builder: (BuildContext context, Widget? _) =>
                            SwitchLine(
                              label: 'The lens is a container (new)',
                              value: RestBubble.instance.container.value,
                              onChanged: RestBubble.instance.setContainer,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ListenableBuilder(
                        listenable: Notes.instance.allowed,
                        builder: (BuildContext context, Widget? _) =>
                            SwitchLine(
                              label: 'Notification counts on icons',
                              value: Notes.instance.allowed.value,
                              // Android decides this too, on its own screen.
                              onChanged: (bool _) => Notes.instance.ask(),
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
                      // The flight recorder: what just happened, to send with a video or without.
                      Pressable(
                        key: Robot.key('recorder'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Haptics.settle();
                          showRecorderExport(context);
                        },
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: c.accent,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Send what just happened',
                            style: LumenType.text(
                              15,
                              weight: 700,
                              color: c.onAccent,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // (With which build this is, so there is never a doubt which one is installed.)
                      Text(
                        'Testing  ·  ${Diag.build}',
                        key: Robot.key('buildName'),
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
                      const SizedBox(height: 10),
                      Pressable(
                        onTap: () {
                          Navigator.of(context).pop();
                          Haptics.settle();
                          Diag.instance.longTest?.call();
                        },
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: c.ink.withValues(alpha: 0.08),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Run the long test (about 20 min, hands off)',
                            style: LumenType.text(
                              15,
                              weight: 700,
                              color: c.ink,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Pressable(
                        onTap: () {
                          Navigator.of(context).pop();
                          Haptics.settle();
                          Diag.instance.glassTest?.call();
                        },
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: c.ink.withValues(alpha: 0.08),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Run the glass settings test (about 20 min)',
                            style: LumenType.text(
                              15,
                              weight: 700,
                              color: c.ink,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Pressable(
                        onTap: () {
                          Navigator.of(context).pop();
                          Haptics.settle();
                          Diag.instance.drainTest?.call();
                        },
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: c.ink.withValues(alpha: 0.08),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Run the chat-head battery test (about 35 min)',
                            style: LumenType.text(
                              15,
                              weight: 700,
                              color: c.ink,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Pressable(
                        onTap: () {
                          Navigator.of(context).pop();
                          Haptics.settle();
                          Diag.instance.hourTest?.call();
                        },
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: c.ink.withValues(alpha: 0.08),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Run the hour-long test (overnight, silent)',
                            style: LumenType.text(
                              15,
                              weight: 700,
                              color: c.ink,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Pressable(
                        onTap: () {
                          Navigator.of(context).pop();
                          Haptics.settle();
                          Diag.instance.soakTest?.call();
                        },
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: c.ink.withValues(alpha: 0.08),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Run the 2½-hour stability test (silent)',
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
                        'Both drive everything by themselves, the floating lens included, check each step, and then sit still to measure power. The hour-long one does it all four times, sits still for longer, and makes no buzz. Unplug the phone, start one, and leave the phone alone. The report is kept below, whenever you come back.',
                        style: LumenType.text(
                          12.5,
                          color: c.inkMuted,
                          height: 1.35,
                        ),
                      ),
                      if (TestRun.last() case final String report?) ...<Widget>[
                        const SizedBox(height: 14),
                        Text(
                          'Last test report',
                          style: LumenType.label(color: c.inkMuted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          report.split('\n').take(4).join('\n'),
                          style: LumenType.text(
                            12.5,
                            color: c.ink.withValues(alpha: 0.84),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Pressable(
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: report),
                            );
                            Haptics.settle();
                          },
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: ShapeDecoration(
                              color: c.accent,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              'Copy the last report',
                              style: LumenType.text(
                                15,
                                weight: 700,
                                color: c.onAccent,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
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

    if (pattern && look.pattern == 4) {
      _vivid(canvas, size);
      return;
    }
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

  /// Vivid: black (white by day), and the light's own colours at full strength, in blocks,
  /// circles and dots. Where things go is as in the other patterns: low down, where the glass
  /// bar sits over them, and off the top corner, clear of titles and of numbers people read.
  void _vivid(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;
    final Color ground = dark
        ? const Color(0xFF0A0A0B)
        : const Color(0xFFF6F4EF);
    final Color ink = dark ? Colors.white : Colors.black;
    const List<Color> hues = <Color>[
      Color(0xFFF2334B),
      Color(0xFFFF7A2B),
      Color(0xFFFFD21F),
      Color(0xFF34C94A),
      Color(0xFF1F7BF2),
      Color(0xFF8A3FF0),
    ];
    Paint fill(Color c, [double a = 1]) =>
        Paint()..color = c.withValues(alpha: a);
    canvas.drawRect(Offset.zero & size, fill(ground));

    // Blocks: six upright bands rising from the foot on the left, each stopping a step lower
    // than the last, like a staircase of light.
    final double band = w * 0.62 / 6;
    for (int i = 0; i < 6; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * band, h * (0.70 + 0.03 * i), band + 0.5, h),
        fill(hues[i]),
      );
    }
    // A thin line of the ink colour across them, where the staircase begins.
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.70 - w * 0.03, w * 0.62, w * 0.008),
      fill(ink, 0.8),
    );

    // Circles: a target of the six colours off the top right corner, ring inside ring.
    final Offset corner = Offset(w * 1.06, -h * 0.02);
    final double step = w * 0.046;
    for (int i = 0; i < 6; i++) {
      canvas.drawCircle(
        corner,
        w * 0.36 - i * step - step / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = step * 0.74
          ..color = hues[i],
      );
    }
    // And a half disc rising from the foot on the right, with its own small dot.
    canvas
      ..drawCircle(Offset(w * 0.84, h * 1.0), w * 0.17, fill(hues[4]))
      ..drawCircle(Offset(w * 0.84, h * 0.95), w * 0.035, fill(ground));

    // Dots: a halftone field on the right, the dots growing toward its middle and shrinking
    // away from it, in the ink colour, faint enough to read over.
    final Offset middle = Offset(w * 0.86, h * 0.50);
    final double gap = w / 26;
    for (double y = h * 0.36; y < h * 0.66; y += gap) {
      for (double x = w * 0.58; x < w + gap; x += gap) {
        final double d = (Offset(x, y) - middle).distance / (w * 0.36);
        if (d < 1) {
          canvas.drawCircle(
            Offset(x, y),
            gap * 0.42 * (1 - d),
            fill(ink, dark ? 0.22 : 0.18),
          );
        }
      }
    }
    // A few solid dots of colour, as if fallen from the bands, to their right, behind the cards.
    canvas
      ..drawCircle(Offset(w * 0.70, h * 0.80), w * 0.022, fill(hues[2]))
      ..drawCircle(Offset(w * 0.66, h * 0.845), w * 0.013, fill(hues[0]))
      ..drawCircle(Offset(w * 0.75, h * 0.855), w * 0.009, fill(hues[5]));

    // Text sits straight on this picture on some pages, so it is held back a little.
    canvas.drawRect(Offset.zero & size, fill(ground, 0.10));
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
    // Soft enough to lose every edge (18 on the screen), scaled to this smaller picture. This is
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
    required this.sign,
  });

  /// What the button shows: the blobs, for its sign.
  final List<(double, Color)> sign;
  final Rect body;
  final Offset velocity, home, from;
  final Color start, end, ink;
  final double button;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset at = body.center;
    final double whole = math.max((from - home).distance, 1);
    final double p = (1 - (at - home).distance / whole).clamp(0.0, 1.0);
    final Color tone = Color.lerp(start, end, Curves.easeOut.transform(p))!;
    final double r = body.shortestSide / 2;
    final double speed = velocity.distance;
    // Drawn to pass for the glass it came from and is going back to, with nothing that costs:
    // the dark tone, lit from above, with a bright line round its upper edge that fades
    // toward the foot. Two fills and one stroke.
    void glassy(Rect box, RRect shape) {
      canvas
        ..drawRRect(shape, Paint()..color = tone)
        ..drawRRect(
          shape,
          Paint()
            ..shader = ui.Gradient.linear(
              box.topCenter,
              box.bottomCenter,
              <Color>[
                Colors.white.withValues(alpha: 0.2),
                Colors.white.withValues(alpha: 0.0),
                end.withValues(alpha: 0.0),
              ],
              <double>[0, 0.55, 1],
            ),
        )
        ..drawRRect(
          shape.deflate(0.75),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..shader = ui.Gradient.linear(
              box.topCenter,
              box.bottomCenter,
              <Color>[
                Colors.white.withValues(alpha: 0.6),
                Colors.white.withValues(alpha: 0.14),
              ],
            ),
        );
    }

    if (body.width > body.height * 1.25) {
      // Still a pill, just let go of: it rounds up as it leaves.
      glassy(body, RRect.fromRectAndRadius(body, Radius.circular(r)));
    } else {
      // One drop, no tail. It appears small and swells in the first stretch of the way,
      // and is pulled long by its own speed, thinner as it gets longer, as liquid is.
      final double grow =
          0.55 + 0.45 * Curves.easeOut.transform((p / 0.14).clamp(0.0, 1.0));
      final double st = (speed / 3600).clamp(0.0, 0.42);
      final Rect box = Rect.fromCenter(
        center: Offset.zero,
        width: 2 * r * grow * (1 + st),
        height: 2 * r * grow * (1 - st * 0.45),
      );
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(speed < 1 ? 0 : velocity.direction);
      glassy(
        box,
        RRect.fromRectAndRadius(box, Radius.circular(box.shortestSide / 2)),
      );
      canvas.restore();
    }
    // The button's sign draws itself in as the drop arrives.
    final double a = ((p - 0.7) / 0.3).clamp(0.0, 1.0);
    if (a > 0) {
      canvas
        ..saveLayer(
          Rect.fromCenter(center: at, width: 44, height: 44),
          Paint()..color = ink.withValues(alpha: a),
        )
        ..translate(at.dx - 19, at.dy - 19);
      if (sign.isEmpty) {
        const _PlusMark().paint(canvas, const Size(38, 38));
      } else {
        BlobSign.paint(
          canvas,
          const Size(38, 38),
          Apps.instance.blobLook,
          <Color>[for (final (double, Color) b in sign) b.$2],
          radius: 21,
        );
      }
      canvas.restore();
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

/// The button's sign when there is nothing to come out: a plain plus, to add something.
/// [fold] is how far it has folded away as the button opens: gone by half way.
class _PlusMark {
  const _PlusMark({this.fold = 0});
  final double fold;

  void paint(Canvas canvas, Size size) {
    if (fold > 0.5) {
      return;
    }
    final double u = size.width / 38;
    final Paint line = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.3 * u
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(19 * u, 9 * u), Offset(19 * u, 29 * u), line)
      ..drawLine(Offset(9 * u, 19 * u), Offset(29 * u, 19 * u), line);
  }
}

/// Whether two lists of blobs (where each sits, and its colour) are the same.
bool _sameBlobs(List<(double, Color)> a, List<(double, Color)> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// The button's sign in all its states, as one drawing. It is always the Blob's sign, in the
/// look that was chosen (see blob_sign.dart): the prism is always there. It says what is open
/// by how far it has turned ([turn], in radians): not at all with nothing open, a sixth of a
/// turn to the right with the blobs out, half a turn with the app list up. [cog] is how far it
/// has become the cog, while the blobs are being changed: the sign draws in and the cog turns in.
class _ButtonSign extends CustomPainter {
  const _ButtonSign({
    required this.blobs,
    required this.turn,
    required this.cog,
    this.shot = 0,
    this.vivid = false,
    this.glass = true,
    this.dark = 0,
    this.look = '',
    this.hint = 1,
    this.rim = 0,
    this.glint = Colors.white,
  });
  final List<(double, Color)> blobs;
  final double turn, cog;

  /// The bouncy shot (see the shell's _signShot): how far the sign is out of its place.
  final double shot;

  /// Vivid or mellow (see [BlobSign.paint]).
  final bool vivid;

  /// The magnifying glass lies over the blob. Off while it is lifted away.
  final bool glass;

  /// How much of the black the glass lays behind a triangle (1 resting on it, 0 lifted).
  final double dark;

  /// How much larger the glass is drawn than its place in the bar.
  static const double grow = 1.25;

  /// How large the blob is against its glass: it keeps the size it always had, and the glass,
  /// drawn larger (see [grow]), lies over it with a little room all round.
  static const double _blob = 1 / grow;

  /// Which look the sign has: one of [BlobSign]'s.
  final String look;

  /// The cog showing itself off: 0 just begun, 1 over (and nothing more is drawn for it).
  /// [rim] is the radius of the button's edge, where the glint runs; [glint] its colour.
  final double hint, rim;
  final Color glint;

  static final TextPainter _gear = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(Icons.settings_rounded.codePoint),
      style: TextStyle(
        fontFamily: Icons.settings_rounded.fontFamily,
        package: Icons.settings_rounded.fontPackage,
        fontSize: 30,
        color: Colors.white,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final double u = size.width / 38;
    final Offset mid = Offset(19 * u, 19 * u);
    final double c = cog.clamp(0.0, 1.0);
    if (c < 0.999) {
      if (blobs.isEmpty) {
        // Nothing to come out: the plus, which turned an eighth of the way is a cross.
        canvas
          ..save()
          ..translate(mid.dx, mid.dy)
          ..rotate(turn.clamp(0.0, math.pi / 3) * 0.75)
          ..translate(-mid.dx, -mid.dy);
        _PlusMark(fold: c * 0.6).paint(canvas, size);
        canvas.restore();
      } else {
        if (dark > 0.001 && BlobSign.of(look).triangle) {
          // Under the glass, the triangle is set in black: the glass's own darkness. It goes
          // with the glass, in the first moment it is lifted, and the triangle is left alone.
          canvas.drawCircle(
            mid,
            (rim > 0 ? rim : size.width / 2) * _blob,
            Paint()..color = Colors.black.withValues(alpha: 0.92 * dark),
          );
        }
        // The shot: up out of its place, a little larger, and back.
        canvas
          ..save()
          ..translate(mid.dx, mid.dy - 6 * u * shot)
          ..scale(1 + 0.12 * shot)
          ..translate(-mid.dx, -mid.dy);
        BlobSign.paint(
          canvas,
          size,
          look,
          <Color>[for (final (double, Color) b in blobs) b.$2],
          radius: (rim > 0 ? rim : size.width / 2) * _blob,
          angle: -math.pi / 2 + turn,
          // (Gone early: the cog takes its place, reshaping out of it.)
          fold: (c * 3).clamp(0.0, 1.0),
          // (A triangle only fades: the cog reshapes out of that very outline.)
          shrink: !BlobSign.of(look).triangle,
          vivid: vivid,
          ground: BlobSign.ground,
        );
        canvas.restore();
      }
    }
    if (glass && rim > 0 && c < 0.999) {
      // The magnifying glass lying over it: its light across the top, over the blob too.
      final Rect lens = Rect.fromCircle(center: mid, radius: rim);
      canvas.drawOval(
        Rect.fromLTRB(
          lens.left + rim * 0.18,
          lens.top + rim * 0.08,
          lens.right - rim * 0.18,
          mid.dy - rim * 0.05,
        ),
        Paint()
          ..shader = ui.Gradient.linear(
            lens.topCenter,
            Offset(mid.dx, mid.dy),
            <Color>[
              Colors.white.withValues(alpha: 0.2 * (1 - c)),
              Colors.white.withValues(alpha: 0),
            ],
          ),
      );
    }
    if (c > 0.001) {
      // Showing itself off, the cog comes round a further quarter turn and settles a little past.
      final double spin =
          (1 - c) * -math.pi / 2 -
          (1 - Curves.easeOutBack.transform(hint.clamp(0.0, 1.0))) *
              math.pi /
              2;
      if (blobs.isNotEmpty) {
        // The sign becomes the cog, in its own colours.
        BlobSign.paintCog(
          canvas,
          size,
          look,
          <Color>[for (final (double, Color) b in blobs) b.$2],
          radius: rim > 0 ? rim : size.width / 2,
          t: c,
          angle: -math.pi / 2 + turn,
          spin: spin,
          vivid: vivid,
        );
      } else {
        // With no blobs there are no colours: the plain white cog.
        canvas
          ..saveLayer(
            Rect.fromCenter(center: mid, width: 40 * u, height: 40 * u),
            Paint()..color = Colors.white.withValues(alpha: c),
          )
          ..translate(mid.dx, mid.dy)
          ..rotate(spin)
          ..scale((0.55 + 0.45 * c) * u);
        _gear.paint(canvas, Offset(-_gear.width / 2, -_gear.height / 2));
        canvas.restore();
      }
    }
    if (hint < 0.999 && rim > 0 && c > 0.001) {
      // One glint goes once round the button's edge, from the top: bright in the middle of
      // its run, gone at both ends.
      final double h = Curves.easeInOut.transform(hint.clamp(0.0, 1.0));
      final double seen = math.sin(math.pi * hint.clamp(0.0, 1.0)) * c;
      final Rect ring = Rect.fromCircle(center: mid, radius: rim);
      final double head = -math.pi / 2 + 2 * math.pi * h;
      const double tail = 1.25;
      canvas.drawArc(
        ring,
        head - tail,
        tail,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.6
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: tail,
            colors: <Color>[
              glint.withValues(alpha: 0),
              Color.lerp(glint, Colors.white, 0.6)!.withValues(alpha: seen),
            ],
            transform: GradientRotation(head - tail),
          ).createShader(ring),
      );
    }
  }

  @override
  bool shouldRepaint(_ButtonSign old) =>
      old.turn != turn ||
      old.shot != shot ||
      old.vivid != vivid ||
      old.glass != glass ||
      old.dark != dark ||
      old.cog != cog ||
      old.look != look ||
      old.hint != hint ||
      !_sameBlobs(old.blobs, blobs);
}

/// The small round mark things wear while the blobs are being changed: white with a dark sign
/// for "change this", red with a white sign for "take this away".
class _EditMark extends StatelessWidget {
  const _EditMark({
    required this.icon,
    this.color = Colors.white,
    this.ink = const Color(0xFF15171C),
    this.size = 28,
  });
  final IconData icon;
  final Color color, ink;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: ShapeDecoration(
      color: color,
      shape: const CircleBorder(),
      shadows: const <BoxShadow>[
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 7,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Icon(
      icon,
      size: size * (icon == Icons.remove_rounded ? 0.72 : 0.6),
      color: ink,
    ),
  );
}

/// The tone of the floating lens, and of the button it lives in: nearly black, with a breath
/// of [accent] in it.
Color lensTone(Color accent) {
  final HSVColor h = HSVColor.fromColor(accent);
  return Color.alphaBlend(
    h
        .withValue((h.value * 0.2).clamp(0.0, 1.0))
        .toColor()
        .withValues(alpha: 0.72),
    const Color(0xFF0B0C10),
  );
}

/// The button, painted as the floating lens is: dark glass lit from the upper left, a glow of
/// Prism's colour at its foot, light across the top, and a rim that is bright above and faint
/// below. It is painted once and again only if the colour changes.
class _LensDisc extends CustomPainter {
  const _LensDisc(this.accent);
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset mid = size.center(Offset.zero);
    final double r = size.shortestSide / 2;
    final Rect box = Rect.fromCircle(center: mid, radius: r);
    final HSVColor h = HSVColor.fromColor(accent);
    Color tone(double value, double alpha) => Color.alphaBlend(
      h
          .withValue((h.value * value).clamp(0.0, 1.0))
          .toColor()
          .withValues(alpha: alpha),
      const Color(0xFF0B0C10),
    );
    canvas
      ..save()
      ..clipPath(Path()..addOval(box))
      ..drawRect(
        box,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.45),
            radius: 0.85,
            colors: <Color>[
              tone(0.42, 0.6),
              tone(0.2, 0.72),
              const Color(0xFF0A0B0E),
            ],
            stops: const <double>[0, 0.55, 1],
          ).createShader(box),
      )
      // The glow at its foot.
      ..drawRect(
        box,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, 0.95),
            radius: 0.48,
            colors: <Color>[
              h
                  .withValue((h.value * 1.2).clamp(0.0, 1.0))
                  .toColor()
                  .withValues(alpha: 0.42),
              accent.withValues(alpha: 0),
            ],
          ).createShader(box),
      )
      // Light across the top.
      ..drawRect(
        Rect.fromLTRB(box.left, box.top, box.right, mid.dy),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0x30FFFFFF), Color(0x00FFFFFF)],
          ).createShader(Rect.fromLTRB(box.left, box.top, box.right, mid.dy)),
      )
      ..restore()
      // The rim.
      ..drawCircle(
        mid,
        r - 0.7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xB8FFFFFF), Color(0x1AFFFFFF)],
          ).createShader(box),
      );
  }

  @override
  bool shouldRepaint(_LensDisc old) => old.accent != accent;
}
