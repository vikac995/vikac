import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show LongPressGestureRecognizer;
import 'package:flutter/rendering.dart'
    show ContainerLayer, OffsetLayer, RenderView, RendererBinding;
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
import 'past_reports.dart';
import 'look.dart';
import 'main.dart' show PanelWatch;
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
      '  floats over other apps ${onOff(b.allowed.value)}  ·  notification counts ${onOff(Notes.instance.allowed.value)}  ·  blobs open real apps ${onOff(BlobApps.instance.on.value)}',
      '  Sidekick (kept by Android${b.sideKnown ? '' : ', not told yet'}): in Prism ${onOff(b.floatIn.value)}  ·  over other apps ${onOff(b.floatOut.value)}  ·  distance ${b.sideGap.toStringAsFixed(1)}, tucked ${b.sideTuck.toStringAsFixed(1)}  ·  labels ${onOff(b.sideNames)}  ·  icons ${b.sidePrismIcons ? 'Prism' : 'regular'}  ·  floating ${b.pinned.value ?? 'nothing'}',
      '  Prism\'s blobs: labels ${onOff(BlobSlots.instance.names)}',
      '  blobs: ${<String>[for (int i = 0; i < _n; i++) _pinKey(i)].join(', ')}',
      '  side menu: ${_sideKeys.isEmpty ? 'not told by Android yet' : _sideKeys.join(', ')}  ·  side design: ${b.sideLook.isEmpty ? 'window' : b.sideLook}${b.sideVivid ? ', vivid' : ''}  ·  main design: ${Apps.instance.blobLook.isEmpty ? 'window' : Apps.instance.blobLook}${Apps.instance.blobVivid ? ', vivid' : ''}',
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

  /// What the button's sign is drawn from: the blobs, or with none in the menu the light's own
  /// colours, so that the button keeps its look and never goes bare.
  List<(double, Color)> get _signBlobs {
    final List<(double, Color)> own = _fanBlobs;
    return own.isNotEmpty
        ? own
        : const <(double, Color)>[
            (0, Color(0xFFF2334B)),
            (0, Color(0xFFFFD21F)),
            (0, Color(0xFF34C94A)),
            (0, Color(0xFF1F7BF2)),
            (0, Color(0xFF8A3FF0)),
          ];
  }

  /// The blobs that would come out of the button, for its sign: where each sits and its colour.
  List<(double, Color)> get _fanBlobs => <(double, Color)>[
    for (int i = 0; i < _n; i++)
      if (!_floating(i) && !_isEmpty(i))
        (_seatAngle(_seat[i].target), _blobColor(i)),
  ];

  // How far the button's X has turned into the cog: 0 the X, 1 the cog.
  // (Unhurried, both ways: the reshaping is the point, and at speed it read as a swap.)
  late final SpringValue _cog = SpringValue(
    this,
    value: 0,
    spring: Motions.spatial,
  );

  // The cog showing itself off, once: a turn that settles and one glint round the button's rim.
  // It runs for well under a second and then nothing moves. Only the first few times.
  late final AnimationController _cogHint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: 1,
  );

  // How far the button's sign has turned, in radians: see [_ButtonSign]. For a look that turns
  // (Window) it only ever increases: see [_signSync]. One stiff spring that never goes past.
  late final SpringValue _signTurn = SpringValue(this, spring: Motions.effects);

  // The bouncy shot of a sign that does not turn: how far it has jumped up out of its place
  // (it starts with a kick and springs back, a little past). At rest 0, and nothing runs.
  late final SpringValue _signShot = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );

  // What was open when the sign was last told: 0 nothing, 1 the blobs, 2 the app list.
  int _signWas = 0;

  // The triangle (the owner's rule, build 184): it points down when the next tap on the button
  // leaves nothing open, and up otherwise. Window is drawn pointing down at angle 0, so up at
  // rest is a sixth of a turn on. On every change of what a tap would do it turns clockwise,
  // and only ever clockwise: a sixth to change the way it points, [sameMeaningTurn] when the
  // tap would do something else but it points the same way.
  double _signAt = math.pi / 3;
  TapOutcome? _signOutcome;
  bool? _signLookTurned;

  // A finger on the button that has started to move: what it will be (a flick for the app list,
  // a carry, a tap) is not known until it lifts. The sign waits for that, so a flick from the
  // blobs never turns it towards "closed" on the way (the blobs go in at the first movement).
  bool _signHeld = false;

  // Each tap on the button: whether the triangle pointed down before it, and whether the tap
  // left nothing open. (For the button test: they must always agree.)
  final List<(String, bool, bool)> _signTaps = <(String, bool, bool)>[];

  /// What a tap on Prism's button would do now (a hold, a flick or a carry is not a tap). The
  /// one place this is decided: the button's tap ([_buttonUp]) does what this says, and the
  /// sign shows it.
  TapOutcome _tapOutcome() {
    // (Prism's settings close on a tap anywhere beside them, the button included.)
    if (_panelOpen) {
      return _open ? TapOutcome.closePanelToBlobs : TapOutcome.closePanel;
    }
    if (_drawerOpen) {
      final int? slot = _editSlot;
      if (slot != null) {
        // Up to choose something: what closing it leads to (see [_setDrawer]).
        if (_pickBack) {
          return TapOutcome.closeDrawerToBack;
        }
        if (_isSwipe(slot)) {
          return TapOutcome.closeDrawerToSettings;
        }
        if (slot != _sideSlot) {
          return TapOutcome.closeDrawerToBlobs;
        }
      }
      return TapOutcome.closeDrawer;
    }
    if (_open && _editing) {
      return TapOutcome.openSettings;
    }
    if (_parked) {
      return TapOutcome.callGlassHome;
    }
    return _open ? TapOutcome.closeBlobs : TapOutcome.openBlobs;
  }

  /// How light (0 to 1, the average of its pixels) a strip across the whole screen is, from [y0]
  /// to [y1] in points, as it is drawn now: everything in Prism's window, its panels included.
  /// (For the button test: read from the screen's own layer, so nothing has to be added to the
  /// app to read it.) Null if it cannot be read.
  Future<double?> _screenLight(double y0, double y1) async {
    try {
      final RenderView view = RendererBinding.instance.renderViews.first;
      // ignore: invalid_use_of_protected_member
      final ContainerLayer? layer = view.layer;
      if (layer is! OffsetLayer) {
        return null;
      }
      final ui.Image img = await layer.toImage(
        Rect.fromLTWH(0, y0, view.size.width, y1 - y0),
        pixelRatio: 0.5,
      );
      final ByteData? data = await img.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      img.dispose();
      if (data == null || data.lengthInBytes < 4) {
        return null;
      }
      double sum = 0;
      int n = 0;
      for (int i = 0; i + 3 < data.lengthInBytes; i += 4) {
        sum +=
            0.2126 * data.getUint8(i) +
            0.7152 * data.getUint8(i + 1) +
            0.0722 * data.getUint8(i + 2);
        n++;
      }
      return n == 0 ? null : sum / n / 255;
    } catch (_) {
      return null;
    }
  }

  /// Whether the triangle, turned [a], points down (Window is the same every 120°: a sixth of a
  /// turn on from pointing down, it points up).
  static bool _pointsDown(double a) => (a / (math.pi / 3)).round().isEven;

  /// Nothing of Prism's is open: no blobs, no app list, no settings, no magnifying glass out.
  bool _nothingOpen() =>
      !_open && !_drawerOpen && !_panelOpen && !_parked && !_carrying;

  /// Does what a tap on the button does now ([_tapOutcome]).
  void _doTap(TapOutcome o) {
    switch (o) {
      case TapOutcome.openBlobs:
      case TapOutcome.closeBlobs:
        _setOpen(o == TapOutcome.openBlobs);
      case TapOutcome.openSettings:
        _showFloating();
      case TapOutcome.callGlassHome:
        _lensHome();
      case TapOutcome.closeDrawer:
      case TapOutcome.closeDrawerToBlobs:
      case TapOutcome.closeDrawerToSettings:
      case TapOutcome.closeDrawerToBack:
        _setDrawer(false);
      case TapOutcome.closePanel:
      case TapOutcome.closePanelToBlobs:
        _closePanel?.call();
    }
  }

  // A sign update asked for and not yet made: made once, when what is being done now has
  // finished, so that the states it passes through on the way do not count (closing the app
  // list after choosing for a blob passes through "nothing open" before the blobs come back:
  // counted, that was two turns at once, 180°).
  bool _signDue = false;

  /// The sign is told that something may have changed: it shows what a tap would do once the
  /// change is complete.
  void _signSync() {
    if (_signDue) {
      return;
    }
    _signDue = true;
    scheduleMicrotask(() {
      _signDue = false;
      if (mounted) {
        _signApply();
      }
    });
  }

  /// The sign: the cog no more, the triangle turned to say what a tap would do, or the shot.
  void _signApply() {
    // (Should the settings' flag ever outlive the panel, the panel's absence wins.)
    if (_panelOpen && !PanelWatch.instance.anyOpen) {
      _panelOpen = false;
    }
    final int now = (_drawerOpen && _editSlot != _sideSlot) || _panelOpen
        ? 2
        : (_open ? 1 : 0);
    final bool turns = BlobSign.of(Apps.instance.blobLook).turns;
    if (turns) {
      if (!_signHeld) {
        final TapOutcome o = _tapOutcome();
        final TapOutcome? was = _signOutcome;
        if (was != null && was != o) {
          _signAt += was.closesAll != o.closesAll
              ? math.pi / 3
              : sameMeaningTurn * math.pi / 180;
        } else if (was == null && o.closesAll) {
          // (The first time, already where a tap closes everything: down, a sixth on.)
          _signAt += math.pi / 3;
        }
        _signOutcome = o;
        if (_signLookTurned != true) {
          // Just become a look that turns (or the first time): it is simply there, no spin.
          _signTurn.jumpTo(_signAt);
        } else {
          _signTurn.animateTo(_signAt);
        }
      }
    } else {
      // The others stay pointing up, and shoot out a little as something opens.
      if (_signLookTurned != false) {
        _signTurn.jumpTo(0);
      } else {
        _signTurn.animateTo(0);
      }
      if (now != 0 && now != _signWas) {
        _signShot.animateTo(0, velocity: 14);
      }
    }
    _signLookTurned = turns;
    _signWas = now;
    // (No cog any more: the settings turn the sign as the app list does.)
    _cog.animateTo(0);
  }

  /// The places put in a new [order] (old place numbers, in their new order), with [empty]
  /// made empty. Each blob goes on being drawn where it was, and moves from there to its
  /// new seat: the blobs that are there always stand together in the middle.
  void _rearrange(List<int> order, {int? empty}) {
    final List<String> keys = <String>[
      for (final int k in order) k == empty ? 'empty:' : _pinKey(k),
    ];
    final List<double> seats = <double>[
      for (final int k in order) _seat[k].value,
    ];
    final List<double> outs = <double>[
      for (final int k in order) k == empty ? 0 : _out[k].value,
    ];
    final Set<int> was = <int>{..._seated};
    BlobSlots.instance.putAll(keys);
    _seated.clear();
    for (int k = 0; k < _n; k++) {
      _seat[k].jumpTo(seats[k]);
      _gone[k].jumpTo(0);
      _out[k].jumpTo(outs[k]);
      if (was.contains(order[k]) && order[k] != empty) {
        _seated.add(k);
      }
    }
    _reseat();
  }

  /// The order with the empty places last, the others as they are.
  List<int> _packed({int? without}) => <int>[
    for (int k = 0; k < _n; k++)
      if (!_isEmpty(k) && k != without) k,
    for (int k = 0; k < _n; k++)
      if (_isEmpty(k) || k == without) k,
  ];

  void _removeBlob(int i) {
    Haptics.thud();
    Diag.instance.event('blob removed');
    // The others close up round the middle at once.
    _rearrange(_packed(without: i), empty: i);
    if (_allEmpty && _open) {
      // The last one gone: the plus comes out in its place at once (it was left in the button).
      _out[0].animateTo(1, spring: _shoot);
    }
  }

  /// Whether place [i] holds something that is neither an app nor one of Prism's sheets or
  /// pages: the phone's notifications, or bringing out the side Blob.
  bool _isPhone(int i) => _pinKey(i).startsWith('phone:');

  /// Whether place [i] brings out the side Blob.
  bool _isSide(int i) => _pinKey(i) == 'phone:side';

  /// Brings the side Blob out, where it was last left. (It may have been sent away, or not
  /// be allowed anywhere: then there is a thud, and Android's own screen for allowing it.)
  void _bringSide() {
    Diag.instance.event('side blob: brought out');
    RestBubble.instance.bringSide().then((bool ok) {
      ok ? Haptics.settle() : Haptics.thud();
    });
  }

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
      ? (_isSide(i) ? 'Sidekick' : 'Notifications')
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

  /// Prism's app list is up only to choose for one of the Sidekick's places, as Android asked
  /// ("sidekickChoose"): which place, whether the new blob is to go right after it (Add), and
  /// what is there now. The list is then only a chooser: what is chosen is sent back to
  /// Android, which keeps the Sidekick's menu. Prism's own menu is not touched. While it is up,
  /// [_editSlot] is [_sideSlot].
  ({int slot, bool add, String key})? _sideAsk;

  /// The place number that stands for the Sidekick's blob being chosen for, so that everything
  /// that names or draws a blob (the list's title, the button wearing the blob) works for it as
  /// it is. (As places 100 to 103 are the two-finger swipes.)
  static const int _sideSlot = 200;

  /// Whether place [i] is one of the two-finger swipes.
  static bool _isSwipe(int i) => i >= 100 && i < _sideSlot;

  /// Prism came forward only to choose (for the Sidekick): once chosen, it steps back to the
  /// app that was in front.
  bool _pickBack = false;

  /// The Sidekick's keys, as Android last told them: only to draw their pictures and for the
  /// flight recorder's report. Prism never changes them. (Empty until Android has said.)
  List<String> _sideKeys = const <String>[];

  /// How many times Android has asked Prism to choose for the Sidekick: for the button test.
  int _sideAsks = 0;

  /// Which of Prism's engines this is, as Android numbers them (0 until it has said).
  int _engineNo = 0;

  /// Done once the five apps Prism starts with have been looked up on the phone.
  Future<void> _blobAppsLoaded = Future<void>.value();

  /// How long a finger held still on a blob counts as a hold: Android's own, as on the Sidekick.
  int _holdMs = 385;

  /// The blob whose small menu (Change, Remove) is showing, if any.
  int? _menuFor;

  /// Held on the empty space round the blobs: where, for its small menu (Edit Prism, Add
  /// Blob). Null when that menu is not up.
  Offset? _spaceAt;

  void _heldSpace(Offset at) {
    if (!_open || _drawerOpen || _menuFor != null || _dragI != null) {
      return;
    }
    // A finger on a blob's place is holding that blob, not the empty space. (It can be found
    // on the empty space there only when it came down while that blob was still flying out to
    // its place: then the hold is neither, and nothing comes up.)
    if (_onABlob(at)) {
      Diag.instance.event('space held on a blob\'s place: nothing');
      return;
    }
    Haptics.settle();
    Diag.instance.event('space held: its menu');
    setState(() => _spaceAt = at);
  }

  void _spaceAway() {
    if (_spaceAt != null && mounted) {
      setState(() => _spaceAt = null);
    }
  }

  /// "Edit Prism": the button's settings.
  void _spaceEdit() {
    setState(() => _spaceAt = null);
    _setOpen(false);
    _showFloating();
  }

  /// "Add Blob": a new blob in the first free place, at the right of the others.
  void _spaceAdd() {
    setState(() => _spaceAt = null);
    final int at = <int>[for (int k = 0; k < _n; k++) k]
        .firstWhere(_isEmpty, orElse: () => -1);
    if (at >= 0) {
      Diag.instance.event('blob: add at the end');
      _pickFor(at);
    }
  }

  /// While a blob is being changed, the button is that blob: the sign draws in and the blob
  /// grows out of it, and back again once it is chosen. 0 the sign, 1 the blob.
  late final SpringValue _face = SpringValue(
    this,
    value: 0,
    spring: Motions.spatial,
  );
  Widget? _faceOf;

  /// Prism's settings panel is open. (The Sidekick's own settings are Android's, from build 178:
  /// SidekickPanel.kt.)
  bool _panelOpen = false;

  /// Closes the open settings on the app list's spring; null when none are open.
  VoidCallback? _closePanel;

  /// In the settings: which slider is being dragged, if one is. The rest of the panel goes
  /// clear meanwhile, so that what the slider moves can be watched.
  final ValueNotifier<String?> _panelClear = ValueNotifier<String?>(null);

  // For the leak test only: parts of Prism it leaves out for a while, to see which one keeps
  // memory. All off outside the test, which puts them back in its `finally`.
  // [_leakNoSends]: Prism's messages to Android when its blobs change (the pin, the Sidekick's
  // pictures, where the blobs sit). [_leakNoLooks]: the six look previews drawn as empty boxes.
  // [_leakBump]: rebuilds the settings' content with nothing changed.
  bool _leakNoSends = false, _leakNoLooks = false;
  final ValueNotifier<int> _leakBump = ValueNotifier<int>(0);

  /// Where the finger was when a hold on a blob was recognised.
  Offset _holdFrom = Offset.zero;

  /// Held still on blob [i]: its small menu comes up beside it, with Change and Remove. The
  /// others dim. Moved on from here without letting go, the blob comes along instead.
  void _heldBlob(int i) {
    if (!_open || _drawerOpen || _dragI != null || !mounted || _isEmpty(i)) {
      return;
    }
    Haptics.settle();
    Diag.instance.event('blob: held, its menu');
    setState(() => _menuFor = i);
  }

  void _menuAway() {
    if (_menuFor != null && mounted) {
      setState(() => _menuFor = null);
    }
  }

  /// "Change" in a blob's small menu: the list to choose what takes its place.
  void _menuChange() {
    final int? i = _menuFor;
    if (i == null) {
      return;
    }
    _menuFor = null;
    _pickFor(i);
  }

  /// "Add" in a blob's small menu: a new place right after this blob, and the list to fill it.
  void _menuAdd() {
    final int? i = _menuFor;
    if (i == null) {
      return;
    }
    setState(() => _menuFor = null);
    final List<int> order = _packed();
    final int at = order.indexOf(i) + 1;
    final int spare = order.firstWhere(_isEmpty);
    order
      ..remove(spare)
      ..insert(at, spare);
    _rearrange(order);
    Diag.instance.event('blob: add after');
    _pickFor(at);
  }

  /// Whether there is room for one more blob.
  bool get _room => <int>[for (int k = 0; k < _n; k++) k].any(_isEmpty);

  /// "Remove" in a blob's small menu: the others close up round the middle.
  void _menuRemove() {
    final int? i = _menuFor;
    if (i == null) {
      return;
    }
    setState(() => _menuFor = null);
    _removeBlob(i);
  }

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
    if (_isSide(i)) {
      _bringSide();
    } else if (_isPhone(i)) {
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
    if (key == 'test:buttons') {
      // Not a blob: the button test, which needs the list closed and the menu as it was.
      // (Chosen while choosing for the Sidekick, Prism's own menu is left as it is.)
      final bool side = _editSlot == _sideSlot;
      _setDrawer(false);
      if (!side) {
        _rearrange(_packed());
      }
      Future<void>.delayed(
        const Duration(milliseconds: 900),
        () => Diag.instance.buttonTest?.call(),
      );
      return;
    }
    final int? i = _editSlot;
    if (i == _sideSlot) {
      // Chosen for the Sidekick: sent to Android, which puts it in the Sidekick's own menu.
      _sideChosen(key);
      _setDrawer(false);
      return;
    }
    if (i != null && _isSwipe(i)) {
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
    } else if (_sideKeys.any((String k) => k.startsWith('app:'))) {
      // Only the Sidekick's menu holds one: its pictures are sent again.
      _sendSidekick();
    }
  }

  void _blobsChanged() {
    if (mounted) {
      setState(() {});
      // The apps' pictures have arrived or the menu changed: the pinned lens may need its picture,
      // and the Sidekick's pictures may have changed with the apps' (its menu is Android's own).
      if (!_leakNoSends) {
        _sendPin();
        _sendSidekick();
      }
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
    if (!_leakNoSends) {
      _tellFan();
    }
    setState(() {});
  }

  // (Until 190 the Sidekick could be dropped on the button to send it away, and the button took
  // it in with a small gulp. Its way out is now the cross at the top, in Prism too.)

  /// Only one menu open at a time (188, the owner's choice): the Sidekick's own menu or panel has
  /// just opened, so Prism's blobs close (the triangle follows its rule).
  void _sidekickOpened(String what) {
    if (!mounted) {
      return;
    }
    _sidekickOpenings++;
    if (_open) {
      Diag.instance.event('the Sidekick\'s $what opened: Prism\'s blobs close');
      _setOpen(false);
    }
  }

  /// A tap on the button, caught by the Sidekick's open menu, which has closed: the tap is Prism's,
  /// as if the Sidekick's menu had not been there (188).
  void _buttonTapFromSidekick() {
    if (!mounted) {
      return;
    }
    _buttonTapsFromSidekick++;
    Diag.instance.event(
      'a tap on the button closed the Sidekick\'s menu: Prism takes it',
    );
    _doTap(_tapOutcome());
  }

  // (For the test: how often each happened.)
  int _sidekickOpenings = 0;
  int _buttonTapsFromSidekick = 0;

  /// While the blobs are out Android knows where they sit, so a lens let go among them is put back.
  void _tellFan() {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    // (And where the button itself is, always: a tap there on the Sidekick's open menu is Prism's, 188.)
    // (And where its bar and button begin, as Prism's own panels end: the Sidekick's panel ends
    // above them too, from build 186.)
    RestBubble.instance.tellButton(
      _home * dpr,
      barTop: (_home.dy - _button * 0.62) * dpr,
    );
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
    Diag.instance.event('settings: Prism');
    _panelOpen = true;
    // (Once the panel is up: the cog then knows a panel is open.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _signSync();
      }
    });
    showGeneralDialog<void>(
      context: context,
      // (Closed by the panel itself, on the app list's spring: see _SpringPanel.)
      barrierDismissible: false,
      barrierLabel: 'Close',
      // (Its own shade, below, so that it can clear with the panel.)
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      transitionBuilder: panelNoFade,
      pageBuilder: (BuildContext context, Animation<double> rise, _) {
        final LumenColors c = LumenColors.of(context);
        // Below the button's top: the button stays in sight, and a tap on it closes these.
        final double above =
            MediaQuery.sizeOf(context).height - (_home.dy - _button * 0.62);
        // Grows out of the button and goes back into it exactly as the app list does: the same
        // springs, the same shape, the same speed both ways.
        return _SpringPanel(
          from: _home,
          button: _button,
          above: above,
          clear: _panelClear,
          onReady: (VoidCallback close) => _closePanel = close,
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, above + 8),
            child: Material(
              type: MaterialType.transparency,
              child: ValueListenableBuilder<String?>(
                valueListenable: _panelClear,
                builder: (BuildContext context, String? held, Widget? child) =>
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(20),
                      decoration: ShapeDecoration(
                        color: held == null
                            ? c.surface
                            : c.surface.withValues(alpha: 0),
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(36),
                          side: BorderSide(
                            color: held == null
                                ? c.hairline
                                : c.hairline.withValues(alpha: 0),
                          ),
                        ),
                      ),
                      child: child,
                    ),
                child: ListenableBuilder(
                  listenable: Listenable.merge(<Listenable>[
                    Apps.instance,
                    BlobSlots.instance,
                    _panelClear,
                    _leakBump,
                  ]),
                  builder: (BuildContext context, Widget? _) => ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.sizeOf(context).height -
                          MediaQuery.paddingOf(context).vertical -
                          70,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _clearBut(<Widget>[
                          // Its name, and a plain way out: the round X in the corner.
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'Prism',
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
                                    _closePanel != null
                                        ? _closePanel!()
                                        : Navigator.of(context).pop();
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
                          const SizedBox(height: 14),
                          // Names under its blobs: each has its own choice.
                          Text(
                            'Labels',
                            style: LumenType.text(
                              15,
                              weight: 560,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // The glass two-way picker, as every two-way choice here.
                          Segmented<bool>(
                            key: Robot.key('names'),
                            values: const <bool>[true, false],
                            labels: const <String>['Show', 'Hide'],
                            value: BlobSlots.instance.names,
                            onChanged: _setNames,
                          ),
                          const SizedBox(height: 14),
                          // The blobs' own choice; the app list has its own, behind its cog.
                          Text(
                            'Icons',
                            style: LumenType.text(
                              15,
                              weight: 560,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // (Prism's blobs' own: the Sidekick has its own, in its own panel.)
                          Segmented<bool>(
                            key: Robot.key('blobIcons'),
                            values: const <bool>[true, false],
                            labels: const <String>['Prism', 'Regular'],
                            value: Apps.instance.blobPrismIcons,
                            onChanged: (bool v) =>
                                Apps.instance.setPrismIcons(v, blobs: true),
                          ),
                          const SizedBox(height: 16),
                          // Prism's two-finger swipes: what each of the four does. A tap on one
                          // asks what it should do.
                          ...<Widget>[
                            Text(
                              'Two-finger swipes',
                              style: LumenType.text(
                                15,
                                weight: 560,
                                color: c.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ListenableBuilder(
                              listenable: GestureSlots.instance,
                              builder: (BuildContext context, Widget? _) => Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  for (int g = 0; g < 4; g++)
                                    GestureDetector(
                                      key: Robot.key('gesture$g'),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        _pickGesture(g);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            SizedBox(
                                              width: 46,
                                              height: 46,
                                              // (Given nothing: a plus in a ring, in the panel's own ink.)
                                              child: _isEmpty(100 + g)
                                                  ? DecoratedBox(
                                                      decoration:
                                                          ShapeDecoration(
                                                            shape: CircleBorder(
                                                              side: BorderSide(
                                                                color:
                                                                    c.inkFaint,
                                                                width: 1.5,
                                                              ),
                                                            ),
                                                          ),
                                                      child: Icon(
                                                        Icons.add_rounded,
                                                        size: 22,
                                                        color: c.inkMuted,
                                                      ),
                                                    )
                                                  : FittedBox(
                                                      child: _blobDisc(100 + g),
                                                    ),
                                            ),
                                            const SizedBox(height: 2),
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
                                              size: 20,
                                              color: c.inkMuted,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          // Vivid: black glass and colours at full strength. Mellow: as before.
                          Text(
                            'Colours',
                            style: LumenType.text(
                              15,
                              weight: 560,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Segmented<bool>(
                            key: Robot.key('blobVivid'),
                            values: const <bool>[false, true],
                            labels: const <String>['Mellow', 'Vivid'],
                            value: Apps.instance.blobVivid,
                            onChanged: (bool v) {
                              Apps.instance.setBlobVivid(v);
                              Diag.instance.event(
                                'main button ${v ? 'vivid' : 'mellow'}',
                              );
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 16),
                          // The Blob's sign, on the button here and on the floating blob over other
                          // apps: each look drawn as it will be, with these blobs' own colours.
                          Text(
                            'Look',
                            style: LumenType.text(
                              15,
                              weight: 560,
                              color: c.ink,
                            ),
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
                                    Diag.instance.event(
                                      'main button look: ${look.name}',
                                    );
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
                                                            Apps
                                                                .instance
                                                                .blobLook,
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
                                              painter: _leakNoLooks
                                                  ? null
                                                  : _LensDisc(c.accent),
                                              foregroundPainter: _leakNoLooks
                                                  ? null
                                                  : BlobSignPreview(
                                                      look.id,
                                                      <Color>[
                                                        for (final (
                                                              double,
                                                              Color,
                                                            )
                                                            b
                                                            in _signBlobs)
                                                          b.$2,
                                                      ],
                                                      vivid: Apps
                                                          .instance
                                                          .blobVivid,
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
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      _panelOpen = false;
      _closePanel = null;
      // (Closed: the Sidekick is hidden only if another panel is still open. Whatever was said
      // while this one was open, a closed panel never leaves it hidden.)
      RestBubble.instance.tellCovered(PanelWatch.instance.anyOpen);
      if (mounted) {
        _signSync();
      }
    });
  }

  /// The panel's parts, each fading away while a slider is held, all but that slider.
  /// (Every part keeps its place in the panel, the held slider too: taken out of its
  /// wrapping, it was made anew under the finger and the drag was lost at once.)
  List<Widget> _clearBut(List<Widget> parts) => <Widget>[
    for (final Widget w in parts)
      AnimatedOpacity(
        opacity:
            _panelClear.value == null ||
                (w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value == _panelClear.value)
            ? 1
            : 0,
        duration: const Duration(milliseconds: 160),
        child: w,
      ),
  ];

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
  /// (Empty places are not shown: the blobs that are there stand together in the middle. With
  /// none at all, the first place shows as a plus, to give it something.)
  bool _leftOut(int i) =>
      _floating(i) ||
      i == _awayI ||
      i == _shotI ||
      (_isEmpty(i) && !(i == 0 && _allEmpty));

  bool get _allEmpty => <int>[for (int k = 0; k < _n; k++) k].every(_isEmpty);

  /// Where blob [i] sits once it is out: its seat round the button.
  Offset _restAt(int i) {
    final double a = _seatAngle(_seat[i].value);
    return _home + Offset(-math.cos(a), -math.sin(a)) * _far.value;
  }

  /// Whether [at] is on the place of one of the blobs that are out (or of the plus), as far as
  /// a finger on it reaches.
  bool _onABlob(Offset at) {
    for (int i = 0; i < _n; i++) {
      if (!_leftOut(i) && (at - _restAt(i)).distance < _blob / 2 + 14) {
        return true;
      }
    }
    return false;
  }

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
        if (!_floating(k) && _open && outs[k] < 1) {
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
  // way, so that everything that draws, names or changes a blob works for them as it is.
  // Place 200 is the Sidekick's blob being chosen for, as Android said: only read, for the
  // list's title and for the button to wear it meanwhile.)
  String _pinKey(int i) => i == _sideSlot
      ? (_sideAsk == null || _sideAsk!.add ? 'empty:' : _sideAsk!.key)
      : i >= 100
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
    // Prism's panel colours, light and dark, kept by Android for the Sidekick's own panel in a
    // later step (sent only when they change), and which of the two is in force now.
    RestBubble.instance.tellPalette(<String, int>{
      'dark': dark ? 1 : 0,
      for (final (String side, LumenColors c) in <(String, LumenColors)>[
        ('light', Look.instance.day),
        ('dark', Look.instance.night),
      ]) ...<String, int>{
        '$side.surface': c.surface.toARGB32(),
        '$side.surfaceHigh': c.surfaceHigh.toARGB32(),
        '$side.hairline': c.hairline.toARGB32(),
        '$side.ink': c.ink.toARGB32(),
        '$side.inkMuted': c.inkMuted.toARGB32(),
        '$side.inkFaint': c.inkFaint.toARGB32(),
        '$side.accent': c.accent.toARGB32(),
        '$side.onAccent': c.onAccent.toARGB32(),
      },
    });
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
    // (The recording and the text's layout hold memory outside Dart: let go by hand.)
    final ui.Picture picture = rec.endRecording();
    tp.dispose();
    final ui.Image image;
    try {
      image = await picture.toImage(120, 120);
    } finally {
      picture.dispose();
    }
    final Uint8List? made;
    try {
      made = (await image.toByteData(format: ui.ImageByteFormat.png))?.buffer
          .asUint8List();
    } finally {
      // The picture was only needed to make the file (let go even if that failed).
      image.dispose();
    }
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

  /// Sends Android the pictures for the Sidekick's keys, exactly those it last told: the name,
  /// colour and picture of each. One way: which blob goes where is the Sidekick's own, kept by
  /// Android. Sent when Android tells its keys, and when the pictures may have changed.
  Future<void> _sendSidekick() async {
    // (Its labels, look and colours are Android's own from build 176: only the pictures are sent.)
    final List<Map<String, Object>> all = <Map<String, Object>>[];
    for (final String key in <String>{..._sideKeys}) {
      final Map<String, Object>? blob = await _blobMap(
        key,
        prismIcons: RestBubble.instance.sidePrismIcons,
      );
      if (blob != null) {
        all.add(blob);
      }
    }
    RestBubble.instance.tellSidekickPictures(all);
  }

  /// Android told the Sidekick's keys (its menu changed, or Prism asked): its pictures are sent.
  void _sidekickTold(List<String> keys) {
    _sideKeys = List<String>.unmodifiable(keys);
    if (_sideKeys.any(
          (String k) =>
              k.startsWith('app:') &&
              !BlobApps.instance.apps.any(
                (BlobApp a) => 'app:${a.package}' == k,
              ),
        ) &&
        Apps.instance.all.isEmpty) {
      // An app from the app list: its look comes from there, which is read once for it.
      Apps.instance.refresh();
    }
    _sendSidekick();
  }

  /// Where Prism kept the Sidekick's own menu before build 170 gave it to Android. Read once,
  /// for the one-time move, and then deleted.
  File _oldSideFile() {
    final Directory files = Directory(
      '${Directory.systemTemp.parent.path}/files',
    );
    return File(
      '${files.existsSync() ? files.path : Directory.systemTemp.path}/prism_blobs_side',
    );
  }

  /// At the start: Android is asked what the Sidekick's menu holds, to send its pictures.
  ///
  /// The one time it has no menu of its own yet (the first start of build 170, which gave the
  /// Sidekick its own menu, kept by Android), the menu it showed until then is moved over: its
  /// own saved set if it had one (the file "prism_blobs_side"), otherwise Prism's. After that,
  /// Android keeps it, and the old file is gone.
  Future<void> _sidekickStart() async {
    List<String>? keys = await RestBubble.instance.sidekickKeys();
    if (keys == null) {
      // (Not on Android, or Android has none of its own yet.)
      if (!Platform.isAndroid || !mounted) {
        return;
      }
      // Prism's default blobs are the five apps, by the packages the phone really has them
      // under: those are known once they have been looked up.
      await _blobAppsLoaded;
      if (!mounted) {
        return;
      }
      String fallback(int i) =>
          _appBlobs ? 'app:${BlobApps.instance.apps[i].package}' : 'action:$i';
      final File old = _oldSideFile();
      List<String> was;
      String from;
      try {
        final List<String> lines = old.readAsLinesSync();
        was = <String>[
          for (int i = 0; i < _n; i++)
            i < lines.length && lines[i].trim().isNotEmpty
                ? lines[i].trim()
                : fallback(i),
        ];
        from = 'its own saved set';
      } catch (_) {
        // It had none of its own: it showed Prism's.
        was = <String>[for (int i = 0; i < _n; i++) _pinKey(i)];
        from = 'Prism\'s menu, which it showed';
      }
      keys = await RestBubble.instance.sidekickAdopt(was);
      if (keys == null) {
        return; // Not moved: asked again at the next start.
      }
      try {
        old.deleteSync();
      } catch (_) {
        // There was none.
      }
      Diag.instance.event(
        'Sidekick: its menu moved to Android (from $from): ${keys.join(', ')}',
      );
    } else {
      // Android has its own: a copy Prism might still have from before is not needed.
      try {
        _oldSideFile().deleteSync();
      } catch (_) {
        // There is none: the usual case.
      }
    }
    if (mounted) {
      _sidekickTold(keys);
    }
  }

  /// Something was chosen in the app list for the Sidekick's place ('empty:' for Remove):
  /// Android is told, and puts it in the Sidekick's own menu.
  void _sideChosen(String key) {
    final ({int slot, bool add, String key})? ask = _sideAsk;
    if (ask == null) {
      return;
    }
    Diag.instance.event(
      'Sidekick: $key chosen ${ask.add ? 'to add after its place ${ask.slot + 1}' : 'for its place ${ask.slot + 1}'}',
    );
    RestBubble.instance.sidekickChosen(slot: ask.slot, add: ask.add, key: key);
  }

  /// One blob as Android needs it: its name, colour and picture. Null if its app is not known yet.
  /// [prismIcons]: Prism's icons or the apps' own, as chosen for the blobs this is for (the
  /// Sidekick's own choice for its pictures; Prism's otherwise).
  Future<Map<String, Object>?> _blobMap(String key, {bool? prismIcons}) async {
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
      final ui.Image? own = _ownIcon(
        what,
        prismIcons: prismIcons ?? Apps.instance.blobPrismIcons,
      );
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
  ui.Image? _ownIcon(String package, {bool? prismIcons}) {
    if (prismIcons ?? Apps.instance.blobPrismIcons) {
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
      return Icon(
        _isSide(i) ? Icons.bubble_chart_rounded : Icons.notifications_rounded,
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

  // The lens: the button, carried. See Lumen R51. (2.5 times as wide from build 197, the owner's
  // choice: 107.5 until 196.)
  static const double _lensSize = 268.75;

  // How far above the finger it rides, so that the thumb does not cover it: scaled with it from
  // build 197 (62 until 196), so the finger stays just under its edge, never over its middle.
  static const double _lensRide = 155;

  /// Where a finger goes for the glass to come over [lensAt] (for the tests): [_lensRide] under
  /// it, kept on the screen.
  static Offset _fingerFor(Offset lensAt) {
    final ui.FlutterView v =
        WidgetsBinding.instance.platformDispatcher.views.first;
    final double h = v.physicalSize.height / v.devicePixelRatio;
    return Offset(lensAt.dx, math.min(lensAt.dy + _lensRide, h - 4));
  }

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
    // The sign as it is at rest from the first frame (the triangle up: a tap opens the blobs).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _signSync();
      }
    });
    // How long a hold is on this phone, the same as the Sidekick's. (Not on a phone: 450 ms.)
    const MethodChannel('lumen/device')
        .invokeMethod<int>('holdMs')
        .then((int? ms) {
          if (ms != null && mounted) {
            setState(() => _holdMs = ms);
          }
        })
        .catchError((Object _) {});
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
    Diag.instance.buttonTest = () => _longTest(
      rounds: 4,
      buttons: true,
      title: 'button test (Prism and the Sidekick)',
    );
    Diag.instance.hourTest = () =>
        _longTest(rounds: 4, still: 180, quiet: true, title: 'hour-long test');
    // The leak test: each of a few everyday steps done twenty times over, memory read as it goes.
    Diag.instance.leakTest = () =>
        _longTest(rounds: 0, leak: true, title: 'leak test');
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
      ..onPinned = (String? key) {
        // Put in the floating lens from its own menu: Prism keeps it, and it leaves the menu.
        RestBubble.instance.setPin(key);
        _sendPin();
      }
      ..onLensAt = _lensOver
      ..onSidekickOpened = _sidekickOpened
      ..onButtonTap = _buttonTapFromSidekick
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
    } else if (Platform.environment['PRISM_BUTTON_TEST'] != null) {
      Future<void>.delayed(
        const Duration(seconds: 9),
        () => _longTest(
          rounds: int.tryParse(Platform.environment['PRISM_BUTTON_TEST']!) ?? 1,
          buttons: true,
          title: 'button test, dry run',
        ),
      );
    } else if (Platform.environment['PRISM_LEAK_TEST'] != null) {
      Future<void>.delayed(
        const Duration(seconds: 9),
        () => _longTest(rounds: 0, leak: true, title: 'leak test, dry run'),
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
    // The Sidekick's settings are Android's: Prism asks for a copy, and writes down what it has.
    RestBubble.instance.onSidekick = (Map<Object?, Object?> m, String how) {
      Diag.instance.event(
        'Prism #$_engineNo: Sidekick settings $how: in this app ${m['inApp'] == true ? 'on' : 'off'}, over other apps ${m['overApps'] == true ? 'on' : 'off'}, distance ${m['gap']}, tucked ${m['tuck']}, labels ${m['names'] == true ? 'show' : 'hide'}, icons ${m['prismIcons'] == true ? 'Prism' : 'regular'}, colours ${m['vivid'] == true ? 'vivid' : 'mellow'}, look ${m['look'] == '' ? '(the first)' : m['look']}',
      );
      if (how.contains('icons changed') && mounted) {
        _sendSidekick();
      }
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // (Where the Sidekick and the timer may float is Android's own from build 176.)
      RestBubble.instance.askSidekick();
      RestBubble.instance.tellTab(_tab);
      // (Where the button is, for the side Blob to fuse with.)
      _tellFan();
      _sendPinData();
      _sendPin();
      // (The Sidekick's menu is Android's: it is asked for its keys, to send their pictures.)
      unawaited(_sidekickStart());
    });
    // Pressing the home button while Prism is the home screen: everything closes and Home shows.
    // Which of Prism's engines this is (Android numbers them): for the flight recorder lines.
    const MethodChannel('lumen/device')
        .invokeMethod<int>('engineNo')
        .then((int? n) {
          _engineNo = n ?? 0;
          Diag.instance.event(
            'this Prism is engine #$_engineNo (shell ${identityHashCode(this).toRadixString(16)})',
          );
        })
        .catchError((Object _) {});
    const MethodChannel('lumen/device').setMethodCallHandler((
      MethodCall call,
    ) async {
      if (call.method.startsWith('sidekick')) {
        // (Written down: which Prism got what Android sent. See Floater.toPrism.)
        Diag.instance.event(
          'Prism #$_engineNo got ${call.method}${mounted ? '' : ' (but it is not on the screen)'}',
        );
      }
      if (call.method == 'sidekickSettings') {
        // The Sidekick's settings changed on Android, which keeps them: Prism's copy follows.
        RestBubble.instance.took(call.arguments, 'told');
        return;
      }
      if (call.method == 'sidekickChoose' && mounted) {
        // Change or Add on one of the Sidekick's blobs: Prism has come to the front with its
        // app list, only to choose from. What is chosen is sent back to Android, which keeps
        // the Sidekick's menu; Prism's own menu is not touched.
        if (_sheetOpen) {
          _closeSheet();
        }
        final Map<Object?, Object?> a = call.arguments as Map<Object?, Object?>;
        if (_editing) {
          _setEditing(false);
        }
        _sideAsks++;
        _sideAsk = (
          slot: ((a['slot'] as num?)?.toInt() ?? 0).clamp(0, _n - 1),
          add: a['add'] == true,
          key: (a['key'] as String?) ?? 'empty:',
        );
        _pickBack = a['back'] == true;
        Diag.instance.event(
          _sideAsk!.add
              ? 'Sidekick: Add, Prism\'s list to choose from'
              : 'Sidekick: Change, Prism\'s list to choose from',
        );
        setState(() => _editSlot = _sideSlot);
        _setDrawer(true);
        return;
      }
      if (call.method == 'sidekickKeys' && mounted) {
        // The Sidekick's menu changed on Android: these are its keys now. Their pictures are sent.
        _sidekickTold(<String>[
          for (final Object? k
              in (call.arguments as List<Object?>?) ?? const <Object?>[])
            '$k',
        ]);
        return;
      }
      if (call.method == 'notes') {
        // Android says how many notifications each app has.
        Notes.instance.take(call.arguments);
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
    _blobAppsLoaded = BlobApps.instance.load();
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
      // The glass rides above the finger, so the finger aims that much lower.
      await Robot.drag(
        <Offset>[b, for (final Rect r in cards) _fingerFor(r.center)],
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
    bool buttons = false,
    bool leak = false,
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
    // Which round is running (0 while getting ready; past [rounds] afterwards), and how long
    // the rounds have taken so far: for the progress line under the banner.
    int roundNow = 0;
    // The triangle's turn, every frame of the button test (build 184): when, where it was, and
    // where it was going. (A jump, when the look changes, starts a new stretch.)
    final List<(int, double, double)> signPath = <(int, double, double)>[];
    void signFrame() => signPath.add((
      t.clock.elapsedMicroseconds,
      _signTurn.value,
      _signTurn.target,
    ));
    const double degree = math.pi / 180;
    // Stretches of the path between jumps (a jump: the target went down, which only a change of
    // look does).
    List<List<(int, double, double)>> stretches(
      List<(int, double, double)> path,
    ) {
      final List<List<(int, double, double)>> all =
          <List<(int, double, double)>>[];
      List<(int, double, double)> now = <(int, double, double)>[];
      for (final (int, double, double) p in path) {
        if (now.isNotEmpty && p.$3 < now.last.$3 - 1e-6) {
          all.add(now);
          now = <(int, double, double)>[];
        }
        now.add(p);
      }
      if (now.isNotEmpty) {
        all.add(now);
      }
      return all;
    }

    // Never back (more than half a degree below where it had got to), never past its target
    // (more than a degree): the first frame that is either, or null.
    String? signWrong(List<(int, double, double)> path) {
      for (final List<(int, double, double)> st in stretches(path)) {
        double most = -double.infinity;
        for (final (int us, double v, double to) in st) {
          if (v < most - 0.5 * degree) {
            return 'turned back at ${(us / 1000).round()} ms: ${(v / degree).toStringAsFixed(1)}° after ${(most / degree).toStringAsFixed(1)}°';
          }
          if (v > to + degree) {
            return 'went past at ${(us / 1000).round()} ms: ${(v / degree).toStringAsFixed(1)}° for ${(to / degree).toStringAsFixed(1)}°';
          }
          most = math.max(most, v);
        }
      }
      return null;
    }

    String signSaid(List<(int, double, double)> path) => path.isEmpty
        ? 'no frames'
        : '${path.length} frames, ${path.map(((int, double, double) p) => (p.$2 / degree).toStringAsFixed(0)).join(' ')}° (to ${(path.last.$3 / degree).toStringAsFixed(0)}°)';
    final Stopwatch roundsTook = Stopwatch();
    void progress(String what) {
      final RegExpMatch? part = RegExp(r'^(\d+) of (\d+), ').firstMatch(what);
      final String name = what.replaceFirst(RegExp(r'^\d+ of \d+, '), '');
      final RegExpMatch? said = RegExp(r'about (\d+) min').firstMatch(what);
      final double was = Diag.instance.progress.value?.$2 ?? 0;
      if (roundNow == 0) {
        Diag.instance.progress.value = ('Getting ready', 0);
      } else if (roundNow <= rounds && part != null) {
        final int k = int.parse(part.group(1)!), of = int.parse(part.group(2)!);
        final double done = ((roundNow - 1) + (k - 1) / of) / rounds;
        final int took = roundsTook.elapsed.inSeconds;
        final String left = done < 0.04 || took < 20
            ? 'working out how long'
            : 'about ${math.max(1, (took * (1 - done) / done / 60).ceil())} min left';
        Diag.instance.progress.value = (
          'Round $roundNow of $rounds  ·  part $k of $of  ·  $left',
          done,
        );
      } else {
        Diag.instance.progress.value = (
          '${roundNow > rounds ? 'After the rounds' : 'Round $roundNow of $rounds'}  ·  ${said == null ? name : 'about ${said.group(1)} min left'}',
          roundNow > rounds ? 1 : was,
        );
      }
    }

    void say(String what) {
      Diag.instance.banner.value = 'Test$lap: $what. Hands off, please.';
      progress(what);
    }

    Offset tab(int i) => Offset(14 + _centre(i), _home.dy);
    Offset seat(int i) {
      final double a = _seatAngle(_seat[i].value);
      return _home + Offset(-math.cos(a), -math.sin(a)) * _far.value;
    }

    // A place on the page that is beside everything the test opens.
    // (Clear of the swipes' places at the top and of the empty places in the middle.)
    final Offset beside = Offset(sc.width / 2, sc.height * 0.56);
    List<double> px(Offset o) => <double>[o.dx * dpr, o.dy * dpr];
    int shown() => <int>[
      for (int i = 0; i < _n; i++)
        if (!_isEmpty(i)) i,
    ].length;
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
    // The Sidekick's own menu (Android's), once the button test has read it: put back at the end.
    List<String>? sideWere;
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
        bool cancel = false,
      }) async {
        final Map<String, Object?> m = await t.lens(<String, Object?>{
          'op': 'press',
          'cancel': cancel,
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
        // Held still, a blob's small menu comes up beside it: Change and Remove.
        await t.scene('holding a blob', () async {
          await Robot.hold(seat(2), after: 700);
        });
        t.check(
          'hold: holding a blob brings up its small menu, and nothing else',
          _menuFor == 2 && _open && !_drawerOpen,
          'menu for ${_menuFor ?? '-'}',
        );
        await Robot.tap(beside, after: 500);
        t.check(
          'hold: a tap beside it puts the menu away and leaves the blobs out',
          _menuFor == null && _open && shown() == 5,
        );
        // Change.
        await Robot.hold(seat(1), after: 700);
        final Offset? change = Robot.spot('menuChange');
        t.check('menu: "Change" is there', change != null);
        if (change != null) {
          await t.scene('Change, and the list comes up', () async {
            await Robot.tap(change, after: 1300);
          });
        }
        t.check(
          'menu: "Change" opens the list for that blob',
          _drawerOpen && _editSlot == 1,
        );
        t.check(
          'picker: the button is the blob being changed',
          _face.target == 1,
        );
        Offset? first = Robot.spot('choice0');
        t.check('picker: the first choice can be found', first != null);
        if (first != null) {
          await t.scene('choosing', () async {
            await Robot.tap(first!, after: 1700);
          });
        }
        t.check(
          'change: the second place is what was chosen',
          _pinKey(1) == 'action:0',
          _pinKey(1),
        );
        t.check(
          'change: back at the blobs, and the button is the sign again',
          _open && !_drawerOpen && _face.target == 0,
        );
        if (_drawerOpen) {
          _setDrawer(false);
          await Robot.wait(700);
        }
        // Remove: the others close up round the middle at once.
        final String gone = _pinKey(2);
        await Robot.hold(seat(2), after: 700);
        final Offset? remove = Robot.spot('menuRemove');
        if (remove != null) {
          await t.scene('Remove, and the others close up', () async {
            await Robot.tap(remove, after: 900);
          });
        }
        t.check(
          'remove: four blobs are left, and that one is gone',
          shown() == 4 &&
              !<String>[for (int k = 0; k < _n; k++) _pinKey(k)].contains(gone),
          '${shown()} left',
        );
        t.check(
          'remove: they stand together in the middle, the empty place last',
          _isEmpty(4) &&
              <double>[for (int k = 0; k < 4; k++) _seat[k].target].join(' ') ==
                  '-1.5 -0.5 0.5 1.5',
          <double>[for (int k = 0; k < _n; k++) _seat[k].target].join(' '),
        );
        // Add: a new blob right after the one held.
        final String held1 = _pinKey(1), next1 = _pinKey(2);
        await Robot.hold(seat(1), after: 700);
        final Offset? add = Robot.spot('menuAdd');
        t.check('menu: "Add" is there while there is room', add != null);
        if (add != null) {
          await t.scene('Add, and the list comes up', () async {
            await Robot.tap(add, after: 1300);
          });
        }
        t.check(
          'add: the list comes up, titled Add',
          _drawerOpen && _editSlot == 2,
        );
        first = Robot.spot('choice0');
        if (first != null) {
          await t.scene('choosing, and the new blob is beside it', () async {
            await Robot.tap(first!, after: 1700);
          });
        }
        t.check(
          'add: the new blob is right after the one held, and the rest move along',
          _pinKey(1) == held1 &&
              _pinKey(2) == 'action:0' &&
              _pinKey(3) == next1 &&
              shown() == 5,
          <String>[for (int k = 0; k < _n; k++) _pinKey(k)].join(' '),
        );
        if (_drawerOpen) {
          _setDrawer(false);
          await Robot.wait(700);
        }
        await Robot.hold(seat(1), after: 700);
        t.check(
          'menu: with five, there is no "Add"',
          Robot.spot('menuAdd') == null && _menuFor == 1,
        );
        await Robot.tap(beside, after: 500);
        BlobSlots.instance.putAll(five);
        await Robot.wait(400);
        // Removing from the list itself.
        await Robot.hold(seat(3), after: 700);
        final Offset? change3 = Robot.spot('menuChange');
        if (change3 != null) {
          await Robot.tap(change3, after: 1300);
        }
        final Offset? pickRemove = Robot.spot('pickRemove');
        t.check('picker: "Remove" is there', pickRemove != null);
        if (pickRemove != null) {
          await Robot.tap(pickRemove, after: 1300);
        }
        t.check(
          'picker: "Remove" takes it away and closes the list',
          shown() == 4 && _isEmpty(4) && !_drawerOpen && _open,
        );
        if (_drawerOpen) {
          _setDrawer(false);
          await Robot.wait(700);
        }
        BlobSlots.instance.putAll(five);
        await Robot.wait(400);
        // Holding the button itself: Prism's settings.
        if (_open) {
          await Robot.tap(_home, after: 800);
        }
        // (How light a strip across the top of the screen is, above where the panel comes: before
        // and after it opens, for "nothing dims the screen behind it".)
        final double? lightBefore = await _screenLight(70, 110);
        await t.scene('holding the closed button', () async {
          await Robot.hold(_home, ms: 650, after: 900);
        });
        t.check(
          'settings: holding the closed button opens them, for Prism',
          _panelOpen && Robot.spot('names') != null,
        );
        final double? lightAfter = await _screenLight(70, 110);
        if (lightBefore == null || lightAfter == null || lightBefore < 0.05) {
          t.skip(
            'settings: with Prism\'s panel open, nothing dims the screen behind it',
            lightBefore == null || lightAfter == null
                ? 'the screen could not be read'
                : 'the strip read is too dark to tell',
          );
        } else {
          t.check(
            'settings: with Prism\'s panel open, nothing dims the screen behind it',
            lightAfter >= lightBefore * 0.9,
            'a strip above the panel: ${(lightBefore * 100).toStringAsFixed(1)}% light before, ${(lightAfter * 100).toStringAsFixed(1)}% with the panel open (a 40% shade would be about ${(lightBefore * 60).toStringAsFixed(1)}%)',
          );
        }
        t.check(
          'settings: the hold brought out neither the glass nor the blobs',
          !_carrying && !_open && !_drawerOpen,
        );
        t.check(
          'sign: while its settings are open it points down (a tap closes them), as for the app list',
          _pointsDown(_signTurn.target) && _cog.target == 0,
          'turned ${(_signTurn.target * 180 / math.pi).toStringAsFixed(0)}°',
        );
        // (From build 178 the Sidekick's settings are its own, over the app it is in: Prism's
        // have no Sidekick part at all. The Sidekick's own panel is checked in the button test.)
        t.check(
          'settings: Prism\'s have no Sidekick part (no Prism | Sidekick, no "In Prism")',
          Robot.spot('blobDesignFor') == null && Robot.spot('floatIn') == null,
        );
        final Offset? names = Robot.spot('names');
        t.check('names: the switch is in the settings', names != null);
        if (names != null) {
          // (Hide is the right half of the picker, Show the left.)
          await Robot.tap(names + const Offset(88, 0), after: 900);
          t.check(
            'names: off, and the blobs are nearer the button',
            !BlobSlots.instance.names && (_far.value - _reachBare).abs() < 1,
            'at ${_far.value.round()}',
          );
          await Robot.tap(
            (Robot.spot('names') ?? names) - const Offset(88, 0),
            after: 900,
          );
          t.check(
            'names: on again, and the blobs are back out',
            BlobSlots.instance.names && (_far.value - _reach).abs() < 1,
            'at ${_far.value.round()}',
          );
        }
        final Offset? shut = Robot.spot('floatClose');
        if (shut != null) {
          await Robot.tap(shut, after: 900);
        }
        t.check(
          'settings: the X closes them, and the sign points up again',
          !_panelOpen &&
              Robot.spot('names') == null &&
              !_pointsDown(_signTurn.target),
        );
        // The button itself, still in sight below them, closes them too.
        await Robot.hold(_home, ms: 650, after: 900);
        t.check(
          'settings: they sit above the button, which stays in sight',
          _panelOpen &&
              (Robot.spot('floatClose')?.dy ?? sc.height) < _home.dy - _button,
        );
        await Robot.tap(_home, after: 900);
        t.check(
          'settings: a tap on the button closes them, and the sign points up again',
          !_panelOpen && !_pointsDown(_signTurn.target) && !_open,
        );
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
        // A finger held on a blob that trembles a pixel or two is still held: that blob's menu
        // comes up, and nothing is moved.
        if (!_open) {
          await Robot.tap(_home, after: 800);
        }
        String order() =>
            <String>[for (int i = 0; i < _n; i++) _pinKey(i)].join(' ');
        final String before = order();
        await t.scene('a blob held with a trembling finger', () async {
          await Robot.drag(
            <Offset>[
              seat(0),
              seat(0) + const Offset(0, 1),
              seat(0) + const Offset(0, 2),
              seat(0) + const Offset(0, 1),
            ],
            legMs: 220,
            dwell: 160,
            after: 700,
          );
        });
        t.check(
          'hold: a trembling finger still holds, and that blob is the one whose menu is up',
          _menuFor == 0 && !_drawerOpen && order() == before,
          'menu for ${_menuFor ?? '-'}; ${order()}',
        );
        if (_menuFor != null) {
          await Robot.tap(beside, after: 500);
        }
        // Moved at once, it is a drag: no menu, however long it then takes.
        await t.scene('a blob dragged away at once and let go', () async {
          await Robot.drag(
            <Offset>[seat(0), seat(0) - const Offset(0, 120), seat(0)],
            legMs: 260,
            after: 900,
          );
        });
        t.check(
          'hold: a blob moved at once is a drag, and no menu comes up',
          _menuFor == null && !_drawerOpen && order() == before,
          'menu for ${_menuFor ?? '-'}; ${order()}',
        );
        if (!_open) {
          await Robot.tap(_home, after: 800);
        }
        // Held, and then moved on without letting go: the menu goes and the blob comes along.
        await t.scene('holding a blob, then carrying it', () async {
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
        });
        t.check(
          'hold: held and then carried, the menu goes and the first blob is now the last',
          _menuFor == null && _pinKey(4) == 'action:0',
          'menu for ${_menuFor ?? '-'}; ${order()}',
        );
        await Robot.drag(
          <Offset>[seat(4), seat(3), seat(2), seat(1), seat(0)],
          legMs: 220,
          dwell: 160,
          after: 900,
        );
        t.check(
          'hold: and carried back, it is where it was',
          _pinKey(0) == 'action:0' && _pinKey(4) == 'action:4',
          order(),
        );
        // Dragged right away from the others and let go: it goes back among them.
        await Robot.drag(
          <Offset>[seat(2), seat(2) - const Offset(0, 230)],
          legMs: 400,
          dwell: 300,
          after: 1000,
        );
        t.check(
          'order: dragged away and let go, it goes back to its seat and nothing floats',
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
        // The two-finger swipes: set in Prism's settings.
        final List<String> swipes = <String>[...GestureSlots.instance.keys];
        final bool wasOut = _open;
        if (_open) {
          await Robot.tap(_home, after: 800);
        }
        await Robot.hold(_home, ms: 650, after: 900);
        final Offset? side = Robot.spot('gesture2');
        t.check('swipes: their places are in Prism\'s settings', side != null);
        if (side != null) {
          await Robot.tap(side, after: 1500);
          t.check(
            'swipes: a tap on a place asks what that swipe should do',
            _drawerOpen && _editSlot == 102 && !_panelOpen,
          );
          final Offset? pick = Robot.spot('choice0');
          if (pick != null) {
            await Robot.tap(pick, after: 1800);
          }
          t.check(
            'swipes: what was chosen is what it does',
            GestureSlots.instance.keys[2] == 'phone:shade',
            GestureSlots.instance.keys[2],
          );
          t.check(
            'swipes: once chosen, the settings are back',
            _panelOpen && !_drawerOpen && !_open,
          );
          final Offset? again = Robot.spot('gesture2');
          if (again != null) {
            await Robot.tap(again, after: 1500);
          }
          final Offset? off = Robot.spot('pickRemove');
          if (off != null) {
            await Robot.tap(off, after: 1500);
          }
          t.check(
            'swipes: "Remove" leaves that swipe doing nothing',
            GestureSlots.instance.keys[2] == 'empty:',
            GestureSlots.instance.keys[2],
          );
          if (_drawerOpen) {
            _setDrawer(false);
            await Robot.wait(900);
          }
        }
        final Offset? shut2 = Robot.spot('floatClose');
        if (shut2 != null) {
          await Robot.tap(shut2, after: 900);
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
          // Two fingers pinch the grid: together for more apps across, apart for fewer.
          final int had = Apps.instance.density;
          final bool room = had < Apps.columns.length - 1;
          await t.scene('app list pinched', () async {
            await Robot.pinch(mid, room ? 260 : 150, room ? 215 : 190);
          });
          t.check(
            'app list: a pinch changes how many apps are across, one step',
            Apps.instance.density == (room ? had + 1 : had - 1),
          );
          await t.scene('app list pinched back', () async {
            await Robot.pinch(mid, room ? 150 : 260, room ? 190 : 215);
          });
          t.check(
            'app list: the opposite pinch puts it back',
            Apps.instance.density == had,
          );
          t.check(
            'app list: a pinch opens nothing and closes nothing',
            _drawerOpen && !_sheetOpen,
          );
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
              <Offset>[_home, for (final Rect r in cards) _fingerFor(r.center)],
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
          // The glass rides [_lensRide] above the finger: see [_fingerFor].
          await Robot.drag(
            <Offset>[_home, _fingerFor(doing[0].rect!.center)],
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
              <Offset>[_lensRect.center, _fingerFor(doing[1].rect!.center)],
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
              <Offset>[_lensRect.center, _fingerFor(bare)],
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

      // Memory at the start of a part of the button test: Android's readings (where there are
      // any), the whole process as Prism sees it, and Prism's own pictures.
      Future<void> memoryAt(String part) async {
        final Map<String, Object?> m = await t.lens(<String, Object?>{
          'op': 'memory',
          'gc': true,
        });
        final (int cache, int icons) = _pictureBytes();
        // Every cache that could grow, with what it holds.
        int pngBytes = 0;
        for (final Uint8List b in <Uint8List>[
          ..._imagePngs.values,
          ..._markPngs.values,
        ]) {
          pngBytes += b.length;
        }
        int appImages = 0, appBytes = 0;
        void count(ui.Image? i) {
          if (i != null) {
            appImages++;
            appBytes += i.width * i.height * 4;
          }
        }

        for (final AppTile a in Apps.instance.all) {
          count(a.glyph);
          count(a.picture);
          count(a.own);
        }
        for (final BlobApp a in BlobApps.instance.apps) {
          count(a.glyph);
          count(a.icon);
          count(a.picture);
        }
        final ImageCache ic = PaintingBinding.instance.imageCache;
        final ({int names, int letters, int numbers}) texts = appListTexts();
        t.memoryAt.add((
          'round $roundNow, $part',
          <String, Object?>{
            if (m['ok'] != false) ...m,
            'rssKb': ProcessInfo.currentRss ~/ 1024,
            'picturesKb': (cache + icons) ~/ 1024,
            'pngs': _imagePngs.length + _markPngs.length,
            'pngsKb': pngBytes ~/ 1024,
            'cacheImages': ic.currentSize + ic.liveImageCount,
            'cacheKb': ic.currentSizeBytes ~/ 1024,
            'appImages': appImages,
            'appImagesKb': appBytes ~/ 1024,
            'texts': '${texts.names}+${texts.letters}+${texts.numbers}',
            'framesKept': t.framesKept,
          },
        ));
      }

      // ================================================================ the button test
      // Prism's button and the Sidekick, and every way of touching them that has gone wrong
      // before or could: holds that are not quite holds, holds that turn into drags, taps that
      // land while something is still moving, panels left behind, and menus emptied and refilled.
      final bool turns = BlobSign.of(Apps.instance.blobLook).turns;
      // Whether the triangle points the way it should (down when a tap would leave nothing
      // open, the owner's rule from build 184), agrees with what a tap would do, and is not the cog.
      void signIs(String when, {required bool down}) => t.check(
        'sign: $when',
        _cog.target == 0 &&
            (!turns ||
                (_pointsDown(_signTurn.target) == down &&
                    _tapOutcome().closesAll == down)),
        'points ${_pointsDown(_signTurn.target) ? 'down' : 'up'} (want ${turns ? (down ? 'down' : 'up') : 'any'}), turned ${(_signTurn.target * 180 / math.pi).toStringAsFixed(0)}°, a tap would: ${_tapOutcome().name}, cog ${_cog.target}',
      );
      // Nothing left behind: no panel, no small menu, no list, no blob being chosen for.
      void clean(String when) => t.check(
        'clean: $when',
        !_panelOpen &&
            !PanelWatch.instance.anyOpen &&
            _menuFor == null &&
            !_drawerOpen &&
            _editSlot == null &&
            _sideAsk == null &&
            !_carrying &&
            !_parked,
        'panel $_panelOpen/${PanelWatch.instance.anyOpen}, menu $_menuFor, list $_drawerOpen, place $_editSlot, for the Sidekick ${_sideAsk != null}, glass $_carrying/$_parked',
      );
      // The settings closed by their X. The X is brought into sight first (the panel scrolls, and
      // a tap where the X was scrolled away to lands on the panel itself). Should the panel still
      // be open, that is WRONG, and it is closed all the same, so that what follows starts with
      // nothing open (build 176's phone run: one panel left open spoiled every check after it).
      Future<void> closePanel() async {
        if (!_panelOpen) {
          return;
        }
        final BuildContext? at = Robot.key('floatClose').currentContext;
        if (at != null && at.mounted) {
          await Scrollable.ensureVisible(at);
          await Robot.wait(250);
        }
        final Offset? x = Robot.spot('floatClose');
        if (x != null) {
          await Robot.tap(x, after: 900);
        }
        if (_panelOpen) {
          t.check(
            'settings: their X closes them',
            false,
            x == null
                ? 'no X found'
                : 'tapped at ${x.dx.round()},${x.dy.round()}, still open',
          );
          _closePanel?.call();
          await Robot.wait(900);
        }
      }

      Future<void> holdButton({int extra = 260}) =>
          Robot.hold(_home, ms: _holdMs + extra, after: 900);
      List<String> keys() => <String>[for (int k = 0; k < _n; k++) _pinKey(k)];
      bool packed() {
        bool seenEmpty = false;
        for (int k = 0; k < _n; k++) {
          if (_isEmpty(k)) {
            seenEmpty = true;
          } else if (seenEmpty) {
            return false;
          }
        }
        return true;
      }

      Future<void> buttonRound() async {
        // ---------------------------------------------------------------- the triangle (184)
        if (buttons &&
            roundNow == 1 &&
            BlobSign.of(Apps.instance.blobLook).turns) {
          say('the triangle');
          if (_panelOpen) {
            _closePanel?.call();
            await Robot.wait(700);
          }
          if (_drawerOpen) {
            _setDrawer(false);
            await Robot.wait(700);
          }
          if (_open) {
            _setOpen(false);
            await Robot.wait(700);
          }
          // One real tap: which way the triangle pointed before it, and what was open after it.
          // Down must mean the tap left nothing open (the owner's rule).
          Future<void> tells(String state) async {
            await Robot.wait(300);
            final bool down = _pointsDown(_signTurn.target);
            final String would = _tapOutcome().name;
            await Robot.tap(_home, after: 900);
            final bool none = _nothingOpen();
            t.check(
              'triangle: $state, it points ${down ? 'down' : 'up'}, and a tap there ${down ? 'leaves nothing open' : 'leaves something open'}',
              down == none,
              'a tap would: $would; after it: blobs $_open, app list $_drawerOpen, settings $_panelOpen, glass out ${_parked || _carrying}',
            );
          }

          Future<void> flick() => Robot.drag(
            <Offset>[_home, _home - const Offset(0, 90)],
            legMs: 90,
            flick: true,
            after: 1000,
          );
          await tells('at rest');
          await tells('with the blobs out');
          await flick();
          await tells('with the app list up');
          // From the blobs: the blobs go in at the flick's first movement, but the triangle waits
          // for the flick, so it never turns back on the way to "the app list is up".
          await Robot.tap(_home, after: 900);
          final int from = signPath.length;
          await flick();
          final List<(int, double, double)> seg = signPath.sublist(from);
          t.check(
            'triangle: a real flick from the blobs opens the app list, and the triangle never turns back or past on the way',
            _drawerOpen &&
                signWrong(seg) == null &&
                _pointsDown(_signTurn.target),
            '${signWrong(seg) ?? 'steady'}; ${signSaid(seg)}; app list $_drawerOpen',
          );
          await tells('with the app list up from the blobs');
          // Prism's settings from a hold: nothing under them, so a tap leaves nothing open.
          await Robot.hold(_home, ms: _holdMs + 250, after: 900);
          await tells('with Prism\'s settings open from a hold');
          // The blobs being changed: a tap opens Prism's settings over them, and a tap then
          // closes the settings with the blobs still out.
          await Robot.tap(_home, after: 900);
          _setEditing(true);
          await Robot.wait(600);
          await tells('with the blobs being changed');
          await tells('with Prism\'s settings over the blobs being changed');
          _setEditing(false);
          _setOpen(false);
          await Robot.wait(700);
        }
        // Only one menu open at a time (188), Prism's side, as Android tells it: the Sidekick's
        // menu opened with Prism's blobs out, they close; a tap on the button caught by the
        // Sidekick's menu, Prism's blobs open. (On a phone, part 4 does it for real.)
        {
          _setOpen(true);
          await Robot.wait(700);
          RestBubble.instance.handle(
            const MethodCall('sidekickOpened', 'menu'),
          );
          await Robot.wait(700);
          final bool closed = !_open;
          final bool upAfterClose = !_pointsDown(_signTurn.target);
          RestBubble.instance.handle(const MethodCall('buttonTap'));
          await Robot.wait(700);
          final bool reopened = _open;
          final bool downAfterOpen = _pointsDown(_signTurn.target);
          t.check(
            'one menu at a time, Prism\'s side: told the Sidekick\'s menu opened, its blobs close; given the tap, they open',
            closed && upAfterClose && reopened && downAfterOpen,
            'closed $closed (the triangle ${upAfterClose ? 'up' : 'down'}), opened again $reopened (the triangle ${downAfterOpen ? 'down' : 'up'})',
          );
          _setOpen(false);
          await Robot.wait(700);
        }
        // ------------------------------------------------ the button: taps
        say('1 of 6, the button: taps');
        await memoryAt('part 1 of 6');
        await calm();
        BlobSlots.instance.putAll(five);
        await Robot.wait(500);
        await t.scene('six quick taps on the button', () async {
          for (int n = 0; n < 6; n++) {
            await Robot.tap(_home, after: 120);
          }
          await Robot.wait(900);
        });
        t.check(
          'button: six quick taps leave the blobs closed',
          !_open && !_panelOpen,
        );
        signIs(
          'closed after quick taps, it points up, as at rest',
          down: false,
        );
        await Robot.tap(_home, after: 900);
        t.check('button: a tap opens the blobs', _open && shown() == 5);
        signIs(
          'with the blobs out it points down (a tap closes them)',
          down: true,
        );
        await Robot.tap(_home, after: 900);
        t.check('button: a tap closes them', !_open);
        // A press a little shorter than a hold is a tap, not the settings.
        await Robot.hold(_home, ms: (_holdMs * 0.55).round(), after: 900);
        t.check(
          'button: a press shorter than a hold is a tap: the blobs, not the settings',
          _open && !_panelOpen,
          'blobs ${_open ? 'out' : 'in'}, settings ${_panelOpen ? 'open' : 'closed'}',
        );
        await Robot.tap(_home, after: 900);
        clean('after the taps');

        // ------------------------------------------------ the button: holds
        say('2 of 6, the button: holds and drags');
        await memoryAt('part 2 of 6');
        await t.scene('holding the closed button', () async {
          await holdButton();
        });
        t.check(
          'hold: the closed button held opens its settings, for Prism',
          _panelOpen && Robot.spot('names') != null,
        );
        t.check(
          'hold: and neither the glass nor the blobs came out',
          !_carrying && !_parked && !_open && !_drawerOpen,
        );
        signIs(
          'with the settings open it points down (a tap closes them)',
          down: true,
        );
        final Offset? closeAt = Robot.spot('floatClose');
        t.check(
          'settings: they sit above the button',
          closeAt != null && closeAt.dy < _home.dy - _button,
        );
        await Robot.tap(_home, after: 900);
        t.check('settings: a tap on the button closes them', !_panelOpen);
        signIs('settings closed, it points up again', down: false);
        clean('after the settings, closed by the button');
        // The same, five times quickly, closed each way in turn: nothing may be left behind.
        await t.scene('settings opened and closed five times', () async {
          for (int n = 0; n < 5; n++) {
            await holdButton(extra: 200);
            if (n.isEven) {
              await closePanel();
            } else {
              await Robot.tap(_home, after: 900);
            }
          }
        });
        clean('after the settings five times');
        signIs('after the settings five times, at rest, up', down: false);
        // Closed as the phone's back gesture would.
        await holdButton();
        await Navigator.of(context).maybePop();
        await Robot.wait(900);
        t.check(
          'settings: back closes them',
          !_panelOpen && !PanelWatch.instance.anyOpen,
        );
        signIs('closed by back, it points up again', down: false);
        // Held with the blobs out: the blobs go in and the settings come up.
        await Robot.tap(_home, after: 900);
        await holdButton();
        t.check(
          'hold: with the blobs out, the settings come up and the blobs go in',
          _panelOpen && !_open,
        );
        await closePanel();
        t.check(
          'hold: and closing the settings leaves the blobs closed',
          !_open && !_panelOpen,
        );
        // A finger that trembles a few points is still a hold.
        await Robot.drag(
          <Offset>[
            _home,
            _home + const Offset(0, 3),
            _home + const Offset(3, 5),
            _home + const Offset(2, 3),
          ],
          legMs: 120,
          dwell: (_holdMs / 3).round() + 40,
          after: 900,
        );
        t.check(
          'hold: a finger that trembles a few points is still a hold',
          _panelOpen && !_carrying,
          'settings ${_panelOpen ? 'open' : 'closed'}, glass ${_carrying ? 'lifted' : 'in place'}',
        );
        await closePanel();
        // A finger that moves first is the glass, however long it then stays.
        await t.scene('moving off the button, then staying', () async {
          await Robot.drag(
            <Offset>[_home, _home + const Offset(-60, -40)],
            legMs: 200,
            dwell: _holdMs + 400,
            after: 900,
          );
        });
        t.check(
          'hold: a finger that moves first lifts the glass, and never opens the settings',
          !_panelOpen,
        );
        await calm();
        clean('after moving off the button');
        // A flick up is the app list, and nothing else.
        await Robot.drag(
          <Offset>[_home, _home - const Offset(0, 320)],
          legMs: 120,
          flick: true,
          after: 1000,
        );
        t.check(
          'flick: a flick up opens the app list, and not the settings',
          _drawerOpen && !_panelOpen,
        );
        if (!_drawerOpen) {
          // (A flick missed from timing must not knock over every check after it.)
          await calm();
          _setDrawer(true);
          await Robot.wait(900);
        }
        signIs(
          'with the app list up it points down (a tap closes it)',
          down: true,
        );
        // Held with the app list up: the button only closes it.
        await holdButton();
        t.check(
          'hold: with the app list up, holding the button closes it and opens nothing',
          !_drawerOpen && !_panelOpen,
          'list ${_drawerOpen ? 'up' : 'down'}, settings ${_panelOpen ? 'open' : 'closed'}',
        );
        await calm();
        signIs('after the app list, at rest, up', down: false);
        clean('after the app list');

        // ------------------------------------------------ the blobs: the small menu
        say('3 of 6, a blob\'s small menu');
        await memoryAt('part 3 of 6');
        await Robot.tap(_home, after: 900);
        await Robot.hold(seat(2), ms: _holdMs + 260, after: 600);
        t.check('menu: holding a blob brings its small menu', _menuFor == 2);
        await Robot.tap(_home, after: 900);
        t.check(
          'menu: a tap on the button with the menu up closes the blobs, and the menu with them',
          !_open && _menuFor == null,
          'blobs ${_open ? 'out' : 'in'}, menu $_menuFor',
        );
        // Held where a blob is still on its way to. (On a phone that is a moment after the tap.
        // Where frames come slowly, as in the preview, a moment is not enough: the test waits
        // until blob 1 has been drawn part of the way out, so that it is the same on any screen.)
        // (Tried again, up to five times, until the finger comes down while blob 1 is drawn
        // between a tenth and three quarters of the way out.)
        double outAt = 1;
        for (int tries = 0; tries < 5; tries++) {
          if (_open) {
            _setOpen(false);
            await Robot.wait(900);
          }
          await Robot.tap(_home, after: 0);
          for (int k = 0; k < 90 && _out[1].value < 0.1; k++) {
            await WidgetsBinding.instance.endOfFrame;
          }
          outAt = _out[1].value;
          if (outAt < 0.75 || tries == 4) {
            break;
          }
        }
        await Robot.hold(seat(1), ms: _holdMs + 260, after: 700);
        t.check(
          'menu: held as the blobs come out, it is that blob\'s menu or none',
          (_menuFor == null || _menuFor == 1) && _spaceAt == null,
          'blob 1 was ${(outAt * 100).round()}% of the way out; menu $_menuFor, the empty space\'s menu ${_spaceAt == null ? 'not up' : 'UP'}',
        );
        if (_menuFor != null || _spaceAt != null) {
          await Robot.tap(beside, after: 500);
        }
        t.check(
          'menu: put away, the blobs stay out',
          _open && _menuFor == null && _spaceAt == null,
        );
        // From here each step starts from a known state: should the step before have gone wrong,
        // Prism is put back as this step needs it first, so that one miss is not counted again
        // in every step after it. Where a step's first move does not happen (no small menu, no
        // list), that is reported once, as wrong, and the checks that depend on it are skipped.
        Future<void> ready({List<String> want = five}) async {
          if (_drawerOpen) {
            _setDrawer(false);
            await Robot.wait(900);
          }
          if (_menuFor != null || _spaceAt != null) {
            _menuAway();
            _spaceAway();
            await Robot.wait(400);
          }
          if (keys().join(' ') != want.join(' ')) {
            BlobSlots.instance.putAll(want);
            await Robot.wait(700);
          }
          if (!_open) {
            _setOpen(true);
            await Robot.wait(900);
          }
        }

        // Held still on blob [i]: its small menu, which the step [before] needs.
        Future<bool> menuOf(int i, String before) async {
          await Robot.hold(seat(i), ms: _holdMs + 260, after: 600);
          t.check(
            'menu: holding a blob brings its small menu',
            _menuFor == i,
            'before $before: menu $_menuFor',
          );
          return _menuFor == i;
        }

        void skip(List<String> names, String why) {
          for (final String n in names) {
            t.skip(n, why);
          }
        }

        // A second hold while a menu is up puts the first away, and opens nothing else.
        await ready();
        if (await menuOf(1, 'a hold elsewhere')) {
          await Robot.hold(seat(3), ms: _holdMs + 260, after: 600);
          t.check(
            'menu: a hold elsewhere while one is up only puts it away',
            _menuFor == null && _spaceAt == null && !_drawerOpen && _open,
            'menu $_menuFor, the empty space\'s menu ${_spaceAt == null ? 'not up' : 'UP'}',
          );
        } else {
          skip(<String>[
            'menu: a hold elsewhere while one is up only puts it away',
          ], 'the first small menu did not come up');
        }
        // Change, and closing the list without choosing.
        await ready();
        final List<String> before = keys();
        const List<String> changing = <String>[
          'change: the list comes up for that blob, and the button becomes it',
          'change: closed without choosing, nothing changed and the button is the sign again',
          'sign: back at the blobs, turned a sixth',
        ];
        final Offset? change = await menuOf(2, 'Change')
            ? Robot.spot('menuChange')
            : null;
        if (change == null) {
          skip(changing, 'the small menu with Change did not come up');
        } else {
          await Robot.tap(change, after: 1300);
          final bool up = _drawerOpen && _editSlot == 2 && _face.target == 1;
          t.check(changing[0], up);
          if (!up) {
            skip(changing.sublist(1), 'the list did not come up for it');
          } else {
            await Robot.tap(_home, after: 1200);
            t.check(
              changing[1],
              !_drawerOpen &&
                  _open &&
                  _face.target == 0 &&
                  keys().join(' ') == before.join(' '),
              keys().join(' '),
            );
            signIs('back at the blobs, it points down', down: true);
          }
        }
        // Remove: with five there is no Add, and Remove leaves four, together in the middle.
        await ready();
        const List<String> removing = <String>[
          'menu: with five blobs there is no Add',
          'remove: four left, together in the middle',
        ];
        if (!await menuOf(1, 'Remove')) {
          skip(removing, 'the small menu did not come up');
        } else {
          t.check(removing[0], Robot.spot('menuAdd') == null);
          final Offset? remove = Robot.spot('menuRemove');
          if (remove != null) {
            await Robot.tap(remove, after: 900);
          }
          t.check(removing[1], shown() == 4 && packed(), keys().join(' '));
        }
        // Add, and closing the list without choosing. (Four, as Remove left them.)
        const List<String> four = <String>[
          'action:0',
          'action:2',
          'action:3',
          'action:4',
          'empty:',
        ];
        await ready(want: four);
        const List<String> adding = <String>[
          'add: the list comes up for the place right after it',
          'add: closed without choosing, still four, together, and nothing chosen',
        ];
        if (!await menuOf(0, 'Add')) {
          skip(<String>[
            'menu: with room, Add is there',
            ...adding,
          ], 'the small menu did not come up');
        } else {
          final Offset? add = Robot.spot('menuAdd');
          t.check('menu: with room, Add is there', add != null);
          if (add == null) {
            skip(adding, 'there was no Add');
          } else {
            await Robot.tap(add, after: 1300);
            final bool up = _drawerOpen && _editSlot == 1;
            t.check(adding[0], up, 'list $_drawerOpen, place $_editSlot');
            if (!up) {
              skip(<String>[adding[1]], 'the list did not come up');
            } else {
              await Robot.tap(_home, after: 1200);
              t.check(
                adding[1],
                !_drawerOpen && shown() == 4 && packed() && _editSlot == null,
                keys().join(' '),
              );
            }
          }
        }
        // Removed one after another, quickly, down to none: a plus is left.
        await ready(want: four);
        await t.scene('removing every blob', () async {
          for (int n = 0; n < 4; n++) {
            await Robot.hold(seat(0), ms: _holdMs + 220, after: 450);
            final Offset? r = Robot.spot('menuRemove');
            if (r != null) {
              await Robot.tap(r, after: 500);
            }
          }
        });
        t.check(
          'remove: with every blob taken away, a plus is left',
          _allEmpty && Robot.spot('plus0') != null,
          keys().join(' '),
        );
        signIs(
          'with only the plus, it still points down with the blobs out',
          down: true,
        );
        // The plus, alone.
        await ready(want: List<String>.filled(_n, 'empty:'));
        await Robot.hold(seat(0), ms: _holdMs + 260, after: 600);
        t.check(
          'plus: holding it brings no menu',
          _menuFor == null && _spaceAt == null,
          'menu $_menuFor, the empty space\'s menu ${_spaceAt == null ? 'not up' : 'UP'}',
        );
        if (_menuFor != null || _spaceAt != null) {
          await Robot.tap(beside, after: 500);
        }
        final Offset? plus = Robot.spot('plus0');
        if (plus != null) {
          await Robot.tap(plus, after: 1300);
        }
        final bool listUp = _drawerOpen && _editSlot == 0;
        t.check('plus: a tap opens the list', listUp);
        final Offset? pick = listUp ? Robot.spot('choice0') : null;
        if (pick == null) {
          skip(<String>[
            'plus: choosing gives the menu one blob',
          ], 'the list did not come up for the plus');
        } else {
          await Robot.tap(pick, after: 1700);
          t.check(
            'plus: choosing gives the menu one blob',
            shown() == 1 && _pinKey(0) == 'action:0',
            keys().join(' '),
          );
        }
        // (Held where a blob's place is, the empty space's menu does not come up: the case
        // above, where the finger came down while the blob was still flying there, asked of
        // what the empty space does with such a hold.)
        await ready();
        _heldSpace(seat(1));
        t.check(
          'space: a hold on a blob\'s place is not a hold on the empty space',
          _spaceAt == null,
        );
        _spaceAway();
        if (_drawerOpen) {
          _setDrawer(false);
          await Robot.wait(800);
        }
        BlobSlots.instance.putAll(five);
        await Robot.wait(600);
        // A blob dragged at once is never held, however long the drag.
        if (!_open) {
          await Robot.tap(_home, after: 900);
        }
        await Robot.drag(
          <Offset>[seat(4), seat(4) - const Offset(0, 140), seat(4)],
          legMs: 420,
          after: 900,
        );
        t.check(
          'drag: a blob moved at once never brings its menu',
          _menuFor == null && keys().join(' ') == five.join(' '),
        );
        await calm();
        if (_open) {
          await Robot.tap(_home, after: 900);
        }
        clean('after the blobs');

        // ------------------------------------------------ the empty space round the blobs
        await Robot.tap(_home, after: 900);
        await Robot.hold(beside, ms: _holdMs + 260, after: 700);
        t.check(
          'space: held, its menu comes up with Edit Prism, and no Add Blob while there are five',
          _spaceAt != null &&
              Robot.spot('spaceEdit') != null &&
              Robot.spot('spaceAdd') == null,
        );
        await Robot.tap(beside + const Offset(0, 120), after: 600);
        t.check(
          'space: a tap beside its menu puts it away, the blobs stay',
          _spaceAt == null && _open,
        );
        BlobSlots.instance.putAll(<String>[
          ...five.take(3),
          'empty:',
          'empty:',
        ]);
        await Robot.wait(700);
        await Robot.hold(beside, ms: _holdMs + 260, after: 700);
        final Offset? spaceAdd = Robot.spot('spaceAdd');
        t.check('space: with room, Add Blob is there', spaceAdd != null);
        if (spaceAdd != null) {
          await Robot.tap(spaceAdd, after: 1300);
        }
        t.check(
          'space: Add Blob opens the list for the first free place, at the right of the others',
          _drawerOpen && _editSlot == 3,
          'list $_drawerOpen, place $_editSlot',
        );
        final Offset? pickAdd = Robot.spot('choice0');
        if (pickAdd != null) {
          await Robot.tap(pickAdd, after: 1700);
        }
        t.check(
          'space: what was chosen stands at the right of the others',
          shown() == 4 && _pinKey(3) == 'action:0' && packed(),
          keys().join(' '),
        );
        if (_drawerOpen) {
          _setDrawer(false);
          await Robot.wait(800);
        }
        BlobSlots.instance.putAll(five);
        await Robot.wait(600);
        if (!_open) {
          await Robot.tap(_home, after: 900);
        }
        await Robot.hold(beside, ms: _holdMs + 260, after: 700);
        final Offset? spaceEdit = Robot.spot('spaceEdit');
        if (spaceEdit != null) {
          await Robot.tap(spaceEdit, after: 1100);
        }
        t.check(
          'space: Edit Prism opens Prism\'s settings, and the blobs go in',
          _panelOpen && Robot.spot('names') != null && !_open,
        );
        await closePanel();
        clean('after the empty space\'s menu');

        // ------------------------------------------------ the settings' own parts
        say('4 of 6, the settings');
        await memoryAt('part 4 of 6');
        await holdButton();
        // (Part 4 is where native memory grew on the phone, about 40 MB a round: it is read
        // after each of its steps, to see which.)
        await memoryAt('part 4: settings open');
        final Offset? names = Robot.spot('names');
        if (names != null) {
          await Robot.tap(names + const Offset(88, 0), after: 900);
          t.check('labels: Hide hides them', !BlobSlots.instance.names);
          await Robot.tap(
            (Robot.spot('names') ?? names) - const Offset(88, 0),
            after: 900,
          );
          t.check('labels: Show shows them', BlobSlots.instance.names);
        }
        await memoryAt('part 4: labels hidden and shown');
        // A swipe set from the settings, the list closed without choosing: the settings come back.
        final Offset? swipe = Robot.spot('gesture3');
        if (swipe != null) {
          await Robot.tap(swipe, after: 1500);
          t.check(
            'swipes: a tap on one opens the list for it',
            _drawerOpen && _editSlot == 103,
          );
          await Robot.tap(_home, after: 1500);
          t.check(
            'swipes: the list closed without choosing, the settings are back',
            _panelOpen && !_drawerOpen,
          );
        }
        await memoryAt('part 4: a swipe\'s list, and back');
        // (From build 178 the Sidekick's settings are its own, over the app it is in: checked in
        // part 5, on the phone.)
        t.check(
          'settings: Prism\'s have no Prism | Sidekick, and no Sidekick switches',
          Robot.spot('blobDesignFor') == null && Robot.spot('floatIn') == null,
        );
        await closePanel();
        await memoryAt('part 4: settings closed');
        clean('after the settings\' own parts');

        // ------------------------------------------------ the Sidekick
        if (!floats) {
          t.note(
            'the Sidekick was not tested: Prism is not allowed over other apps',
          );
          return;
        }
        say('5 of 6, the Sidekick');
        // A tap only where it can land: on the screen. Off it, that is WRONG, with where.
        Future<bool> seenTap(String what, Offset at, {int after = 900}) async {
          final ui.FlutterView v =
              WidgetsBinding.instance.platformDispatcher.views.first;
          final Size screen = v.physicalSize / v.devicePixelRatio;
          if (at.dx < 0 ||
              at.dy < 0 ||
              at.dx > screen.width ||
              at.dy > screen.height) {
            t.check(
              '$what: on the screen to be tapped',
              false,
              'off screen at ${at.dx.round()},${at.dy.round()} (the screen is ${screen.width.round()} × ${screen.height.round()})',
            );
            return false;
          }
          await Robot.tap(at, after: after);
          return true;
        }

        await memoryAt('part 5 of 6');
        await t.lens(<String, Object?>{'op': 'side', 'on': true});
        await Robot.wait(1200);
        Map<String, Object?> s = await where();
        t.check(
          'sidekick: it is there',
          s['lens'] == true && s['guest'] == true,
          'shown ${s['lens']}, ${s['pin']}',
        );
        // Android's line to Prism must lead to this Prism, the one running the test: everything the
        // Sidekick tells Prism or asks of it goes along it. (On the phone, in build 171, it did not.)
        final Object? lineTo = s['engineLine'], testIn = s['engineHere'];
        final bool lineOk = lineTo == null || lineTo == testIn;
        t.check(
          'sidekick: Android\'s line to Prism leads to this Prism, the one running the test',
          lineOk,
          'line to Prism #$lineTo, the test in Prism #$testIn, ${s['enginesMade']} made so far',
        );
        // What needs Android to reach this Prism is checked only where its line leads here:
        // otherwise that one miss, just above, would be counted again in every check after it.
        void heard(String name, bool ok, [String note = '']) => lineOk
            ? t.check(name, ok, note)
            : t.skip(
                name,
                'Android\'s line to Prism leads to Prism #$lineTo, not to this one (#$testIn)',
              );
        // Its menu is Android's own (SidekickMenu.kt): kept, saved and changed there. Prism only
        // draws its pictures, and lends its app list to choose from.
        List<String> stored(Map<String, Object?> m) => <String>[
          for (final Object? k
              in (m['sidekickKeys'] as List<Object?>?) ?? const <Object?>[])
            '$k',
        ];
        List<String> filled(List<String> k) => <String>[
          for (final String x in k)
            if (!x.startsWith('empty:')) x,
        ];
        // The places with the blobs together and the empty ones last, as the menu keeps them.
        List<String> together(List<String> k) => <String>[
          ...filled(k),
          for (int j = filled(k).length; j < _n; j++) 'empty:',
        ];
        // First the person's own menu, as it is: since the one-time move, Android's.
        final List<String> own = stored(s);
        t.check(
          'sidekick: its menu is Android\'s own, five places, the empty ones last',
          s['sidekickOwn'] == true &&
              own.length == _n &&
              own.join(' ') == together(own).join(' '),
          own.isEmpty ? 'Android has none' : own.join(' '),
        );
        t.note(
          'the Sidekick\'s menu as Android took it over from Prism, the one time (build 170\'s first start): ${'${s['sidekickMoved'] ?? ''}'.isEmpty ? 'not recorded' : s['sidekickMoved']}',
        );
        t.check(
          'sidekick: Prism has been told its keys, and keeps no saved copy of them',
          _sideKeys.join(' ') == own.join(' ') && !_oldSideFile().existsSync(),
          'Prism was told ${_sideKeys.join(' ')}; old file ${_oldSideFile().existsSync() ? 'still there' : 'gone'}',
        );
        t.check(
          'sidekick: it shows every blob of its own menu, in order',
          '${s['sideKeys']}' ==
              (filled(own).isEmpty ? 'empty:0' : filled(own).join(',')),
          'shown ${s['sideKeys']}',
        );
        // The person's own menu is put aside for the test, and put back afterwards. (Only a menu
        // Android has as its own: without one, the one-time move has not happened, and the test
        // leaves the Sidekick's menu alone so that it still can.)
        if (sideWere == null && s['sidekickOwn'] == true && own.length == _n) {
          sideWere = own;
        }
        final bool mine = sideWere != null;
        final List<String> mainBefore = keys();
        final bool openBefore = _open;
        Future<Map<String, Object?>> menu(
          String what, {
          int i = 0,
          int which = 0,
          int to = 0,
          int settleMs = 900,
        }) async {
          final Map<String, Object?> m = await t.lens(<String, Object?>{
            'op': 'menu',
            'what': what,
            'i': i,
            'which': which,
            'to': to,
            'settleMs': settleMs,
          }, extraMs: 2000);
          t.lensRun('menu $what', m);
          return m;
        }

        // What the last tap left the Sidekick as, for a tap that did not open its blobs.
        Map<String, Object?> tapped = const <String, Object?>{};
        Future<bool> openMenu() async {
          final Map<String, Object?> m = await press(
            'sidekick tapped',
            <Offset>[],
            holdMs: 60,
            settleMs: 1100,
          );
          tapped = m;
          return m['menu'] == true;
        }

        // Why a tap did not open the blobs, as far as Android can say: whether its window is on
        // the screen, what the finger left it as, whether it has blobs to open (a menu just
        // changed shows only the blobs whose pictures Prism has sent), and its own last touch.
        String whyNot() {
          final Map<String, Object?> m = tapped;
          String yn(String k) =>
              m[k] == null ? '?' : (m[k] == true ? 'yes' : 'no');
          String ago(String k) {
            final num? v = m[k] as num?;
            return v == null || v < 0 ? 'never' : '${v.round()} ms ago';
          }

          if (m['ok'] != true) {
            return 'Android could not tap it: ${m['note'] ?? 'no answer'}';
          }
          return 'menu open ${yn('menu')} (${m['menuCount'] ?? '?'} blobs in it); '
              'window on the screen ${yn('attached')}, shown ${m['seen'] ?? '?'}; '
              'guest ${yn('guest')}, pressed ${yn('pressed')}, menu touch ${yn('menuTouch')}, '
              'two-finger size ${yn('sized')}, held for settings ${yn('settingsHeld')}, '
              'ignoring ${yn('ignoring')}, panel touch ${yn('panelTouch')}, panel open ${yn('panelOpen')}; '
              'tucked ${yn('tucked')}, roaming ${yn('roaming')}, moving ${yn('moving')}, docked ${yn('docked')}, '
              'closing ${yn('closing')}; '
              'blobs to open ${m['blobs'] ?? '?'} (${m['sideKeys'] ?? '?'}), '
              'pictures for ${m['sidekickPicturesFor'] ?? '?'} of its blobs, '
              'keys last sent to Prism ${ago('sidekickToldAgo')}, pictures last came ${ago('sidekickCameAgo')}; '
              'Prism in front ${yn('fg')}; its last touch: ${m['touch'] ?? '?'}';
        }

        // The Sidekick shows a new blob only once Prism has sent its picture. After its menu has
        // been changed, the test waits for all of them before it taps (182's one miss on the S26
        // was a tap that came first). Null once they have all come; otherwise, why not.
        Future<String?> picturesIn(String after) async {
          final Stopwatch w = Stopwatch()..start();
          String said = '?';
          while (w.elapsedMilliseconds < 6000) {
            final Map<String, Object?> m = await where();
            said = '${m['sidekickPicturesFor'] ?? '?'}';
            final List<String> of = said.split(' of ');
            if (of.length == 2 && of[0] == of[1]) {
              t.note(
                'the Sidekick\'s pictures for its menu had all come ${w.elapsedMilliseconds} ms after $after',
              );
              return null;
            }
            await Robot.wait(150);
          }
          return 'Prism\'s pictures had not all come 6 s after $after: pictures for $said of its blobs';
        }

        if (!mine) {
          t.note(
            'the Sidekick\'s Remove, Change and Add were not tried: its menu is not yet Android\'s own, and the test must not change it before the one-time move',
          );
        } else {
          // For the test, a menu that is not Prism's (Prism's is five actions now), so that it can
          // be told which one changed.
          const List<String> sideTest = <String>[
            'action:4',
            'action:3',
            'action:2',
            'action:1',
            'screen:0',
          ];
          // The fan and its names (191), with the person's own menu: laid out for the Sidekick
          // high, in the middle and low on each side, on this phone, and how clear of each other
          // everything is.
          final Map<String, Object?> fc = await t.lens(<String, Object?>{
            'op': 'fan',
          });
          final List<Object?> places =
              (fc['fanCheck'] as List<Object?>?) ?? const <Object?>[];
          double least = double.infinity;
          final List<String> said = <String>[];
          final List<String> wrongs = <String>[];
          for (final Object? o in places) {
            final Map<Object?, Object?> g = o is Map
                ? o
                : const <Object?, Object?>{};
            final double l = (g['least'] as num?)?.toDouble() ?? double.nan;
            if (!l.isNaN) {
              least = math.min(least, l);
            }
            final List<Object?> w =
                (g['wrong'] as List<Object?>?) ?? const <Object?>[];
            if (w.isNotEmpty) {
              wrongs.add('${g['where']}: ${w.join(', ')}');
            }
            // (198) Its blobs at least as far apart as usual, wherever it rests: never squeezed.
            final double bb = (g['blobBlob'] as num?)?.toDouble() ?? double.nan,
                usual = (g['usualGap'] as num?)?.toDouble() ?? double.nan;
            if (!bb.isNaN && !usual.isNaN && bb < usual - 0.5) {
              wrongs.add(
                '${g['where']}: blobs ${bb.toStringAsFixed(1)} apart, less than the usual ${usual.toStringAsFixed(1)}',
              );
            }
            said.add(
              '${g['where']} at ${g['cy']} ${l.isNaN ? '?' : l.toStringAsFixed(1)} (blobs ${bb.isNaN ? '?' : bb.toStringAsFixed(1)} apart, turned ${g['turned']}°, ${g['grown']}×${g['fits'] == false ? ', moved in as one' : ''})',
            );
          }
          t.check(
            'sidekick: its fan at ten places, from the very top to the very bottom it may rest on each side: blobs as far apart as usual, no blob, name, badge or the Sidekick on another, nothing off the screen or on Prism\'s bar',
            places.length == 10 && wrongs.isEmpty && least >= 0,
            '${wrongs.isEmpty ? 'clear everywhere' : wrongs.join(' | ')}; the smallest gap ${least.isFinite ? least.toStringAsFixed(1) : '?'} points; ${said.join('; ')}; names ${fc['blobNames'] == true ? 'on' : 'off'}',
          );
          await t.lens(<String, Object?>{'op': 'sidekick', 'keys': sideTest});
          final String? late = await picturesIn('the test\'s menu was set');
          // (Test only.) The test starts from a known state: if the Sidekick is tucked away, it
          // is brought out to rest at its side first, and settles. Tucked, the test's tap only
          // brought it out (185 on the S25: "ignoring yes", its last touch "…, tucked").
          final Map<String, Object?> out = await t.lens(<String, Object?>{
            'op': 'untuck',
            'settleMs': 700,
          });
          t.lensRun('untuck', out);
          t.note(
            'the Sidekick before the test\'s first tap: ${out['did'] ?? (out['wasTucked'] == true ? 'was tucked: yes, brought out' : 'was tucked: no')}',
          );
          final bool opened = await openMenu();
          t.check(
            'sidekick: a tap opens its blobs',
            opened,
            opened ? '' : (late ?? whyNot()),
          );
          s = await where();
          t.check(
            'sidekick: as many blobs as its menu has',
            s['menuCount'] == filled(stored(s)).length,
            '${s['menuCount']} shown, ${filled(stored(s)).length} in its menu',
          );
          // The open menu itself, as laid out on the screen (191).
          if (opened) {
            final Map<String, Object?> geo = await menu('geometry');
            final List<Object?> w =
                (geo['wrong'] as List<Object?>?) ?? const <Object?>[];
            final bool spaced =
                geo['blobBlob'] is! num ||
                geo['usualGap'] is! num ||
                (geo['blobBlob']! as num) >= (geo['usualGap']! as num) - 0.5;
            t.check(
              'sidekick: its open menu: blobs as far apart as usual, no blob, name, badge or the Sidekick on another, nothing off the screen or on Prism\'s bar',
              geo['least'] is num && w.isEmpty && spaced,
              '${w.isEmpty ? 'clear' : w.join(', ')}; blobs ${geo['blobBlob']} apart (usual ${geo['usualGap']}), the Sidekick at ${geo['cy']}; the smallest gap ${geo['least']} points (blob to blob ${geo['blobBlob']}, name to blob ${geo['nameBlob']}, name to badge ${geo['nameBadge']}, name to the Sidekick ${geo['nameSidekick']}, to the edge ${geo['edge']}, to Prism\'s bar ${geo['bar']}); turned ${geo['turned']}°, ${geo['grown']}×; names ${geo['names']}',
            );
          }
          // Only one menu open at a time (188, the owner's choice). With the Sidekick's blobs out,
          // one tap on Prism's button closes them and opens Prism's; with Prism's out, one tap on
          // the Sidekick closes them and opens its own. Never both open at once.
          if (opened) {
            String both(Map<String, Object?> m) =>
                'the Sidekick\'s blobs ${m['menu'] == true ? 'out' : 'in'}, Prism\'s ${_open ? 'out' : 'in'}; the triangle points ${_pointsDown(_signTurn.target) ? 'down' : 'up'}';
            final int tapsWas = _buttonTapsFromSidekick;
            s = await menu('button', settleMs: 900);
            await Robot.wait(400);
            t.check(
              'one menu at a time: with the Sidekick\'s blobs out, one tap on Prism\'s button closes them and opens Prism\'s',
              s['menu'] != true &&
                  _open &&
                  _buttonTapsFromSidekick == tapsWas + 1 &&
                  _pointsDown(_signTurn.target),
              '${both(s)}; Prism was given ${_buttonTapsFromSidekick - tapsWas} tap(s); the Sidekick\'s menu took the tap ${s['menuTap'] ?? '?'}',
            );
            final int openingsWas = _sidekickOpenings;
            final bool swapped = await openMenu();
            await Robot.wait(400);
            t.check(
              'one menu at a time: with Prism\'s blobs out, one tap on the Sidekick closes them and opens its own',
              swapped &&
                  !_open &&
                  _sidekickOpenings > openingsWas &&
                  !_pointsDown(_signTurn.target),
              swapped
                  ? '${both(tapped)}; Prism was told ${_sidekickOpenings - openingsWas} time(s)'
                  : 'the Sidekick\'s blobs did not open: ${whyNot()}',
            );
            // (Back as before: the Sidekick's blobs out, Prism's in.)
            if (_open) {
              _setOpen(false);
              await Robot.wait(600);
            }
            if (!swapped) {
              await openMenu();
            }
          }
          // Dragged with its blobs out (192): a drag begun on the Sidekick in the middle of its
          // blobs folds them away within 0.25 s and carries it, 1:1; once it has come to rest its
          // blobs come out again round it, clear of each other. A tap still only closes them. Dropped
          // on the cross at the top, it is sent away and its blobs stay in.
          if (opened) {
            double numIn(Object? v) => v is num ? v.toDouble() : double.nan;
            Map<String, Object?> m0 = await where();
            if (m0['menu'] != true) {
              await openMenu();
              m0 = await where();
            }
            final List<Object?> mid0 =
                (m0['lensMid'] as List<Object?>?) ?? const <Object?>[];
            final double hPt = numIn(m0['h']) / dp;
            final double sizePt = numIn(m0['size']) / dp;
            final double y0 = mid0.length == 2 ? numIn(mid0[1]) : hPt / 2;
            final int dy = y0 > hPt / 2 ? -120 : 120;
            // (194: round the spot it was going to, which is where it rests now, within 6 points.)
            bool reopenedRound(Map<String, Object?> m) {
              final List<Object?> a =
                  (m['menuReopenAt'] as List<Object?>?) ?? const <Object?>[];
              final List<Object?> b =
                  (m['lensMid'] as List<Object?>?) ?? const <Object?>[];
              return a.length == 2 &&
                  b.length == 2 &&
                  (numIn(a[0]) - numIn(b[0])).abs() < 6 &&
                  (numIn(a[1]) - numIn(b[1])).abs() < 6;
            }

            final double want =
                (y0 + dy).clamp(48 + sizePt / 2, hPt - 48 - sizePt / 2) - y0;
            final int dragsWas = numIn(m0['menuDrags']).isNaN
                ? 0
                : numIn(m0['menuDrags']).toInt();
            final int reopensWas = numIn(m0['menuReopens']).isNaN
                ? 0
                : numIn(m0['menuReopens']).toInt();
            final Map<String, Object?> dr = await t.lens(<String, Object?>{
              'op': 'menu',
              'what': 'dragLens',
              'dy': dy,
              'settleMs': 1800,
            }, extraMs: 4000);
            t.lensRun('menu dragLens', dr);
            await Robot.wait(900);
            Map<String, Object?> m1 = await where();
            final List<Object?> mid1 =
                (m1['lensMid'] as List<Object?>?) ?? const <Object?>[];
            final double moved = mid1.length == 2
                ? numIn(mid1[1]) - y0
                : double.nan;
            final double foldMs = numIn(m1['menuFoldMs']);
            t.check(
              'sidekick: dragged with its blobs out, they fold away within 0.25 s and it is carried 1:1',
              numIn(m1['menuDrags']) == dragsWas + 1 &&
                  foldMs >= 0 &&
                  foldMs <= 250 &&
                  (moved - want).abs() < 24,
              'its blobs all in ${foldMs.isNaN || foldMs < 0 ? '?' : foldMs.round()} ms after it was picked up; it moved ${moved.isNaN ? '?' : moved.toStringAsFixed(0)} points (dragged $dy from ${y0.toStringAsFixed(0)}, ${want.toStringAsFixed(0)} meant)',
            );
            t.check(
              'sidekick: dragged with its blobs out, let go, its blobs come out again at once, round where it comes to rest',
              m1['menu'] == true &&
                  numIn(m1['menuReopens']) == reopensWas + 1 &&
                  numIn(m1['menuReopenLagMs']) >= 0 &&
                  numIn(m1['menuReopenLagMs']) <= 120 &&
                  reopenedRound(m1),
              'its blobs ${m1['menu'] == true ? 'out' : 'in'}, opened again ${numIn(m1['menuReopens']).isNaN ? '?' : numIn(m1['menuReopens']).toInt() - reopensWas} time(s), ${numIn(m1['menuReopenLagMs']).isNaN ? '?' : numIn(m1['menuReopenLagMs']).round()} ms after the let-go, round ${m1['menuReopenAt'] ?? 'where it was still'} (it rests at ${m1['lensMid']}); its last touch: ${m1['touch'] ?? '?'}',
            );
            if (m1['menu'] == true) {
              final Map<String, Object?> geo = await menu('geometry');
              final List<Object?> w =
                  (geo['wrong'] as List<Object?>?) ?? const <Object?>[];
              t.check(
                'sidekick: after the drag, its blobs out again clear of each other',
                geo['least'] is num && w.isEmpty,
                '${w.isEmpty ? 'clear' : w.join(', ')}; the smallest gap ${geo['least']} points; turned ${geo['turned']}°, ${geo['grown']}×',
              );
              // A tap on it with its blobs out: they close, and do not come out again.
              await menu('middle', settleMs: 900);
              await Robot.wait(1500);
              m1 = await where();
              t.check(
                'sidekick: a tap on it with its blobs out closes them, and they stay in',
                m1['menu'] != true &&
                    numIn(m1['menuReopens']) == reopensWas + 1,
                'its blobs ${m1['menu'] == true ? 'out' : 'in'}, opened again ${numIn(m1['menuReopens']).isNaN ? '?' : numIn(m1['menuReopens']).toInt() - reopensWas} time(s) in all',
              );
            }
            // Carried to the top in the middle with its blobs out (where its cross was in 190 to
            // 192): from 193 it only moves, and its blobs come out again where it comes to rest.
            if (await openMenu()) {
              final Map<String, Object?> dc = await t.lens(<String, Object?>{
                'op': 'menu',
                'what': 'dragLens',
                'toTop': true,
                'settleMs': 1800,
              }, extraMs: 4000);
              t.lensRun('menu dragLens to the top', dc);
              await Robot.wait(1200);
              m1 = await where();
              t.check(
                'sidekick: carried to the top middle with its blobs out, it only moves, and its blobs come out again',
                m1['lens'] == true &&
                    m1['menu'] == true &&
                    numIn(m1['menuReopens']) == reopensWas + 2,
                'shown ${m1['lens']}, its blobs ${m1['menu'] == true ? 'out' : 'in'}, opened again ${numIn(m1['menuReopens']).isNaN ? '?' : numIn(m1['menuReopens']).toInt() - reopensWas} time(s) in all',
              );
            }
            // (Its blobs out again, for what follows.)
            if ((await where())['menu'] != true) {
              await openMenu();
            }
          }
          s = await menu('hold', i: 1);
          t.check(
            'sidekick: holding a blob brings its small menu',
            s['pop'] == 1,
            'small menu ${s['pop']}; the Sidekick at ${(((s['y'] as num?) ?? 0) / dpr).round()} points from the top; blobs ${s['layout'] ?? '?'}',
          );
          s = await menu('outside', settleMs: 700);
          t.check(
            'sidekick: a tap beside it puts the small menu away, the blobs stay',
            s['pop'] == -1 && s['menu'] == true,
            'small menu ${s['pop']}, blobs ${s['menu']}',
          );
          // Down on Remove, slid onto Change, let go there: what is under the finger as it
          // lifts is not what it came down on, so nothing is done, and the small menu stays.
          final List<String> beforeSlide = stored(await where());
          final int asksSlide = _sideAsks;
          await menu('hold', i: 1);
          s = await menu('popSlide', which: 1, to: 0, settleMs: 900);
          await Robot.wait(600);
          t.check(
            'sidekick: pressed on Remove and let go on Change, nothing is done and the small menu stays',
            s['pop'] == 1 &&
                s['menu'] == true &&
                stored(s).join(' ') == beforeSlide.join(' ') &&
                _sideAsks == asksSlide &&
                !_drawerOpen,
            'small menu ${s['pop']}, its menu ${stored(s).join(' ')}, Prism asked ${_sideAsks - asksSlide} times',
          );
          await menu('outside', settleMs: 700);
          // Remove: done by Android alone. Over another app where there is one, so that it can be
          // seen that Prism is not brought forward for it.
          final int asksBefore = _sideAsks;
          final List<String> sideBefore = stored(await where());
          bool over = false, left = false;
          if (t.other != null) {
            s = await t.lens(<String, Object?>{
              'op': 'leave',
              'pkg': otherPkg,
            }, extraMs: 3000);
            left = s['ok'] != false;
            over = left && s['fg'] == false;
            if (over) {
              final bool opened = await openMenu();
              t.check(
                'sidekick: over another app, a tap opens its blobs',
                opened,
                opened ? '' : whyNot(),
              );
            }
          }
          if (!over) {
            t.note(
              'the Sidekick\'s Remove was tried in Prism, not over another app (${t.other == null ? 'none of the usual apps was found' : 'the other app did not come to the front'})',
            );
            if ((await where())['menu'] != true) {
              await openMenu();
            }
          }
          await menu('hold', i: 1);
          s = await menu('pop', which: 1, settleMs: 1200);
          await Robot.wait(900);
          s = await where();
          final List<String> afterRemove = together(
            <String>[...sideBefore]..removeAt(1),
          );
          t.check(
            'sidekick: Remove takes that blob out of its own menu, and the others close up',
            stored(s).join(' ') == afterRemove.join(' '),
            'its menu ${stored(s).join(' ')} (was ${sideBefore.join(' ')})',
          );
          t.check(
            over
                ? 'sidekick: Remove over another app leaves that app in front: Prism is not brought forward'
                : 'sidekick: Remove asks nothing of Prism',
            (!over || s['fg'] == false) &&
                _sideAsks == asksBefore &&
                !_drawerOpen,
            'Prism in front ${s['fg']}, asked to choose ${_sideAsks - asksBefore} times, list $_drawerOpen',
          );
          t.check(
            'sidekick: Remove leaves Prism\'s menu as it was, and its blobs as they were',
            keys().join(' ') == mainBefore.join(' ') && _open == openBefore,
            'Prism ${keys().join(' ')}, blobs out $_open',
          );
          heard(
            'sidekick: Prism has been told its keys again, only for their pictures',
            _sideKeys.join(' ') == afterRemove.join(' '),
            'Prism was told ${_sideKeys.join(' ')}',
          );
          if (left) {
            // (Also when the other app was slow to come to the front: Prism comes back, and the
            // speck that kept the screen on goes.)
            await t.lens(<String, Object?>{'op': 'front'}, extraMs: 4000);
            await Robot.wait(900);
          }
          // Add, closed without choosing.
          if (await openMenu()) {
            await menu('hold', i: 0);
            s = await menu('pop', which: 2, settleMs: 1200);
            await Robot.wait(1200);
            heard(
              'sidekick: Add brings Prism\'s list, only to choose for the place after it',
              _drawerOpen &&
                  _editSlot == _sideSlot &&
                  _sideAsk?.add == true &&
                  _sideAsk?.slot == 0,
              'list $_drawerOpen, place $_editSlot, asked for ${_sideAsk?.slot} (add ${_sideAsk?.add})',
            );
            heard(
              'sidekick: while Prism\'s list is up for it, Prism\'s triangle points down (a tap closes the list)',
              !turns || _pointsDown(_signTurn.target),
              'turned ${(_signTurn.target * 180 / math.pi).toStringAsFixed(0)}°, a tap would: ${_tapOutcome().name}',
            );
            await Robot.tap(_home, after: 1300);
            s = await where();
            heard(
              'sidekick: closed without choosing, both menus are as they were and Prism\'s blobs do not open',
              !_drawerOpen &&
                  _sideAsk == null &&
                  stored(s).join(' ') == afterRemove.join(' ') &&
                  keys().join(' ') == mainBefore.join(' ') &&
                  _open == openBefore,
              'its menu ${stored(s).join(' ')}; Prism ${keys().join(' ')}, blobs out $_open',
            );
          }
          // Change, choosing the first thing.
          List<String> afterChange = afterRemove;
          if (await openMenu()) {
            await menu('hold', i: 0);
            s = await menu('pop', which: 0, settleMs: 1200);
            await Robot.wait(1200);
            heard(
              'sidekick: Change brings Prism\'s list, only to choose for that blob, and the button wears it meanwhile',
              _drawerOpen &&
                  _editSlot == _sideSlot &&
                  _sideAsk?.add == false &&
                  _sideAsk?.slot == 0 &&
                  _sideAsk?.key == afterRemove[0] &&
                  _face.target == 1,
              'list $_drawerOpen, place $_editSlot, asked for ${_sideAsk?.slot} ${_sideAsk?.key}, button as the blob ${_face.target}',
            );
            final Offset? first = Robot.spot('choice0');
            if (first != null) {
              await seenTap(
                'Prism\'s list: its first choice',
                first,
                after: 1700,
              );
            }
            s = await where();
            afterChange = <String>[...afterRemove]..[0] = 'action:0';
            heard(
              'sidekick: what was chosen is in that place of the Sidekick\'s menu, and only there',
              stored(s).join(' ') == afterChange.join(' ') &&
                  keys().join(' ') == mainBefore.join(' '),
              'its menu ${stored(s).join(' ')}; Prism ${keys().join(' ')}',
            );
            heard(
              'sidekick: chosen, Prism\'s blobs do not open',
              _open == openBefore,
              'blobs out $_open',
            );
            clean('after changing a Sidekick blob');
          }
          // Add, choosing the first thing: right after the blob that was held, and only there.
          if (await openMenu()) {
            await menu('hold', i: 1);
            s = await menu('pop', which: 2, settleMs: 1200);
            await Robot.wait(1200);
            final Offset? first = Robot.spot('choice0');
            if (first != null) {
              await seenTap(
                'Prism\'s list: its first choice',
                first,
                after: 1700,
              );
            }
            s = await where();
            final List<String> want = together(
              <String>[...filled(afterChange)]..insert(2, 'action:0'),
            );
            heard(
              'sidekick: Add puts what was chosen right after the held blob, in the Sidekick\'s menu only',
              stored(s).join(' ') == want.join(' ') &&
                  keys().join(' ') == mainBefore.join(' ') &&
                  _open == openBefore,
              'its menu ${stored(s).join(' ')} (want ${want.join(' ')}); Prism ${keys().join(' ')}, blobs out $_open',
            );
            clean('after adding a Sidekick blob');
          }
          // The whole way round, over another app: Change and Add bring Prism forward with its
          // list; chosen, or the list closed without choosing, Prism steps back to that app, and
          // the Sidekick has what was chosen (or what it had).
          const List<String> roundTrip = <String>[
            'sidekick: over another app, Change brings Prism forward with its list',
            'sidekick: over another app, Change chosen: back in that app, and the Sidekick has it',
            'sidekick: over another app, Change closed without choosing: back in that app, nothing changed',
            'sidekick: over another app, Add brings Prism forward with its list',
            'sidekick: over another app, Add chosen: back in that app, and the Sidekick has it after the held blob',
            'sidekick: over another app, Add closed without choosing: back in that app, nothing changed',
          ];
          if (t.other == null || !lineOk) {
            skip(
              roundTrip,
              t.other == null
                  ? 'none of the usual apps was found to be "another app"'
                  : 'Android\'s line to Prism leads to Prism #$lineTo, not to this one (#$testIn)',
            );
          } else {
            await t.lens(<String, Object?>{
              'op': 'sidekick',
              'keys': <String>[
                'action:4',
                'action:3',
                'screen:0',
                'empty:',
                'empty:',
              ],
            });
            await picturesIn('the round trip\'s menu was set');
            // One trip: over the other app, the held blob's part [which] (0 Change, 2 Add),
            // then [choose] or close the list. Answers what Android keeps afterwards, or null if
            // the trip could not be made.
            Future<List<String>?> trip(
              int which,
              bool choose,
              String forward,
              String back,
            ) async {
              Map<String, Object?> m = await t.lens(<String, Object?>{
                'op': 'leave',
                'pkg': otherPkg,
              }, extraMs: 3000);
              if (m['ok'] == false || m['fg'] != false || !await openMenu()) {
                skip(
                  <String>[forward, back],
                  'the other app did not come to the front, or the Sidekick\'s blobs did not open over it',
                );
                if (m['ok'] != false) {
                  await t.lens(<String, Object?>{'op': 'front'}, extraMs: 4000);
                }
                return null;
              }
              await menu('hold', i: 0);
              await menu('pop', which: which, settleMs: 1200);
              await Robot.wait(1500);
              m = await where();
              final bool up =
                  m['fg'] == true &&
                  _drawerOpen &&
                  _editSlot == _sideSlot &&
                  _sideAsk?.add == (which == 2) &&
                  _pickBack;
              t.check(
                forward,
                up,
                'Prism in front ${m['fg']}, list $_drawerOpen, for the Sidekick ${_editSlot == _sideSlot}, steps back after $_pickBack',
              );
              if (!up) {
                skip(<String>[back], 'Prism\'s list did not come up for it');
                await calm();
                await t.lens(<String, Object?>{'op': 'front'}, extraMs: 4000);
                return null;
              }
              final Offset? first = choose ? Robot.spot('choice0') : null;
              if (choose && first != null) {
                await seenTap(
                  'Prism\'s list: its first choice',
                  first,
                  after: 2000,
                );
              } else {
                await Robot.tap(_home, after: 2000);
              }
              m = await where();
              return <String>[
                if (m['fg'] == false) 'away',
                for (final Object? k
                    in (m['sidekickKeys'] as List<Object?>?) ??
                        const <Object?>[])
                  '$k',
                '|',
                ...'${m['sideKeys']}'.split(','),
              ];
            }

            // (What a trip answers: 'away' first if Prism stepped back, then the five keys kept,
            // then '|' and the keys shown.)
            bool away(List<String> r) => r.isNotEmpty && r.first == 'away';
            List<String> kept(List<String> r) => r
                .skipWhile((String k) => k == 'away')
                .takeWhile((String k) => k != '|')
                .toList();
            List<String> shownOf(List<String> r) =>
                r.skipWhile((String k) => k != '|').skip(1).toList();
            List<String>? r = await trip(0, true, roundTrip[0], roundTrip[1]);
            if (r != null) {
              t.check(
                roundTrip[1],
                away(r) &&
                    kept(r).first == 'action:0' &&
                    shownOf(r).contains('action:0'),
                'Prism stepped back ${away(r)}; kept ${kept(r).join(' ')}; shown ${shownOf(r).join(',')}',
              );
            }
            List<String> was = stored(await where());
            r = await trip(0, false, roundTrip[0], roundTrip[2]);
            if (r != null) {
              t.check(
                roundTrip[2],
                away(r) && kept(r).join(' ') == was.join(' '),
                'Prism stepped back ${away(r)}; kept ${kept(r).join(' ')} (was ${was.join(' ')})',
              );
            }
            was = stored(await where());
            r = await trip(2, true, roundTrip[3], roundTrip[4]);
            if (r != null) {
              final List<String> want = together(
                <String>[...filled(was)]..insert(1, 'action:0'),
              );
              t.check(
                roundTrip[4],
                away(r) &&
                    kept(r).join(' ') == want.join(' ') &&
                    shownOf(r).length == filled(want).length,
                'Prism stepped back ${away(r)}; kept ${kept(r).join(' ')} (want ${want.join(' ')}); shown ${shownOf(r).join(',')}',
              );
            }
            was = stored(await where());
            r = await trip(2, false, roundTrip[3], roundTrip[5]);
            if (r != null) {
              t.check(
                roundTrip[5],
                away(r) && kept(r).join(' ') == was.join(' '),
                'Prism stepped back ${away(r)}; kept ${kept(r).join(' ')} (was ${was.join(' ')})',
              );
            }
            await t.lens(<String, Object?>{'op': 'front'}, extraMs: 4000);
            await calm();
          }
        }
        // ------------------------------------------------ the Sidekick's own settings
        // From build 178 they are its own panel, drawn by Android over the app it is in
        // (SidekickPanel.kt): Prism neither comes forward nor is asked anything. Each way of
        // opening it, its place, each of its parts, its two dials, and each way of closing it.
        Future<Map<String, Object?>> panel(
          String what, {
          String part = '',
          Object? dx,
          List<double>? again,
          int gapMs = 50,
          bool pixels = false,
          int settleMs = 800,
          int holdMs = 700,
          int legMs = 400,
        }) => t.lens(<String, Object?>{
          'op': 'panel',
          'what': what,
          'part': part,
          'dx': ?dx,
          'again': ?again,
          'gapMs': gapMs,
          'pixels': pixels,
          'settleMs': settleMs,
          'holdMs': holdMs,
          'legMs': legMs,
        }, extraMs: 4000);
        Map<Object?, Object?>? kept(Map<String, Object?> m) =>
            m['sidekickSettings'] is Map
            ? m['sidekickSettings']! as Map<Object?, Object?>
            : null;
        double numOf(Object? v) => v is num ? v.toDouble() : double.nan;
        bool panelUp(Map<String, Object?> m) =>
            m['panelOpen'] == true && m['panelOpenFully'] == true;
        // (196) "Hold to dismiss" where it should be: 10 points under the Sidekick's glass (or over
        // it, where there is no room under it), centred on it unless it had to slide in to stay 12
        // points from the screen's side; fully on the screen, between the lowest and highest it may
        // reach; its touch at least 48 tall, clear of the Sidekick's own touch (its glass and 6
        // points round it), and kept from Back near an edge.
        (bool, String) pillOk(Map<String, Object?> m) {
          final Map<Object?, Object?> pm = m['pill'] is Map
              ? m['pill']! as Map<Object?, Object?>
              : const <Object?, Object?>{};
          List<double> four(Object? v) => <double>[
            for (final Object? x in (v is List ? v : const <Object?>[]))
              numOf(x),
          ];
          final List<double> b = four(pm['box']),
              tch = four(pm['touch']),
              gl = four(pm['glass']),
              sc = four(pm['screen']);
          if (b.length != 4 ||
              tch.length != 4 ||
              gl.length != 3 ||
              sc.length != 2) {
            return (false, 'no pill in the panel\'s state');
          }
          final bool above = pm['above'] == true;
          final double l = b[0], t = b[1], r = b[0] + b[2], bt = b[1] + b[3];
          final double floor = numOf(pm['floor']), ceil = numOf(pm['ceiling']);
          final bool onScreen =
              l >= 12 - 0.5 &&
              r <= sc[0] - 12 + 0.5 &&
              t >= ceil - 0.5 &&
              bt <= floor + 0.5;
          final bool placed = above
              ? bt <= gl[1] - gl[2] - 10 + 0.5
              : t >= gl[1] + gl[2] + 10 - 0.5;
          final bool slid =
              (l - 12).abs() < 0.6 || (r - (sc[0] - 12)).abs() < 0.6;
          final bool centred = ((l + r) / 2 - gl[0]).abs() < 0.6 || slid;
          // The Sidekick's touch is its glass and 6 points round it: the pill's touch never in it.
          final double nx = gl[0].clamp(tch[0], tch[0] + tch[2]),
              ny = gl[1].clamp(tch[1], tch[1] + tch[3]);
          final double gap = math.sqrt(
            (gl[0] - nx) * (gl[0] - nx) + (gl[1] - ny) * (gl[1] - ny),
          );
          final bool clearOfGlass = gap >= gl[2] + 6 - 0.5;
          final bool tall = tch[3] >= 47.5;
          final bool nearEdge = tch[0] < 48 || tch[0] + tch[2] > sc[0] - 48;
          final bool kept = !nearEdge || pm['excluded'] == true;
          final List<double> over = four(pm['overPanel']);
          return (
            onScreen &&
                placed &&
                centred &&
                clearOfGlass &&
                tall &&
                kept &&
                m['holdLabel'] == 'Hold to dismiss',
            '${above ? 'over' : 'under'} the glass (${gl.map((double v) => v.toStringAsFixed(0)).join(',')}), at ${b.map((double v) => v.toStringAsFixed(0)).join(',')}${slid ? ', slid in from the side' : ''}; on the screen $onScreen (${sc.map((double v) => v.toStringAsFixed(0)).join('×')}, from ${ceil.toStringAsFixed(0)} to ${floor.toStringAsFixed(0)}), placed $placed, centred $centred; its touch ${tch[3].toStringAsFixed(1)} tall, ${gap.toStringAsFixed(1)} from the glass\'s middle, kept from Back $kept; "${m['holdLabel']}"; over the panel ${over.length == 2 ? '${over[0].toStringAsFixed(0)} × ${over[1].toStringAsFixed(0)}' : '?'} points',
          );
        }

        final double wPx = (s['w'] as num?)?.toDouble() ?? w;
        // How far the Sidekick rests from its edge, and how much of it shows tucked, in points.
        double fromEdge(Map<String, Object?> m) {
          final double x = numOf(m['x']), size = numOf(m['size']);
          return math.min(x, wPx - x - size) / dp;
        }

        double showing(Map<String, Object?> m) {
          final double x = numOf(m['x']), size = numOf(m['size']);
          return (x < 0 ? x + size : wPx - x).clamp(0, size) / dp;
        }

        // Opens it by holding the closed Sidekick; true if it came up.
        Future<bool> holdOpen(String why) async {
          await press(why, <Offset>[], holdMs: _holdMs + 300, settleMs: 1500);
          await Robot.wait(700);
          return panelUp(await where());
        }

        Future<void> shut() async {
          if ((await where())['panelOpen'] == true) {
            await panel('tap', part: 'close', settleMs: 900);
          }
        }

        // (Read now: the round trips just before bring Prism forward on purpose.)
        s = await where();
        final double addsWas = numOf(s['lensAdds']),
            removesWas = numOf(s['lensRemoves']);
        final int forwardsWas = numOf(s['forwards']).isNaN
            ? -1
            : numOf(s['forwards']).toInt();
        final bool wasTucked = s['tucked'] == true;
        final Object? closedWas = s['panelClosed'];
        final double openedWas = numOf(s['panelOpened']);
        // Only one menu open at a time (188): Prism's blobs are out as the Sidekick is held; its
        // panel opens, and Prism's blobs close.
        _setOpen(true);
        await Robot.wait(700);
        final int heldOpeningsWas = _sidekickOpenings;
        final bool opened = await holdOpen('sidekick held');
        t.check(
          'one menu at a time: with Prism\'s blobs out, holding the Sidekick opens its panel and closes them',
          opened && !_open && _sidekickOpenings > heldOpeningsWas,
          'its panel ${opened ? 'open' : 'not open'}, Prism\'s blobs ${_open ? 'out' : 'in'}; Prism was told ${_sidekickOpenings - heldOpeningsWas} time(s)',
        );
        if (_open) {
          _setOpen(false);
          await Robot.wait(600);
        }
        // Still open well after the finger has lifted, never closed meanwhile, and the Sidekick
        // put above it without the panel changing at all (build 178 closed by itself, about
        // 0.6 to 1 s after the opening hold was let go, on the owner's phones).
        await Robot.wait(900);
        s = await where();
        // (Its window is never taken off or put back for its panel: build 180's blink.)
        bool lensUntouched(Map<String, Object?> m) =>
            numOf(m['lensAdds']) == addsWas &&
            numOf(m['lensRemoves']) == removesWas;
        // Its middle where it really is on the screen ("lensMid", from its window's place, as the
        // shade's hole and the stand-in find it), in points. (Build 182 compared the hole with the
        // middle worked out from where its window was asked to be, x and y: on both phones that
        // was off by some way, while the hole was on the Sidekick.)
        List<double> midOf(Map<String, Object?> m) {
          final List<Object?> l =
              (m['lensMid'] as List<Object?>?) ?? const <Object?>[];
          return l.length == 2
              ? <double>[numOf(l[0]), numOf(l[1])]
              : <double>[double.nan, double.nan];
        }

        List<double> askedMid(Map<String, Object?> m) => <double>[
          (numOf(m['x']) + numOf(m['size']) / 2) / dp,
          (numOf(m['y']) + numOf(m['size']) / 2) / dp,
        ];
        String pts(List<Object?> l) =>
            l.map((Object? v) => numOf(v).toStringAsFixed(1)).join(', ');
        bool atItsSpot(Map<String, Object?> m) {
          final List<Object?> hole =
              (m['panelHole'] as List<Object?>?) ?? const <Object?>[];
          final List<double> c = midOf(m);
          return m['lens'] == true &&
              hole.length == 2 &&
              (numOf(hole[0]) - c[0]).abs() < 4 &&
              (numOf(hole[1]) - c[1]).abs() < 4;
        }

        String spotSaid(Map<String, Object?> m) =>
            'the hole at [${pts((m['panelHole'] as List<Object?>?) ?? const <Object?>[])}], the Sidekick\'s middle on the screen at [${pts(midOf(m))}] (from where its window was asked to be: [${pts(askedMid(m))}])${m['roaming'] == true ? ', roaming' : ''}, its window ${m['window']} px';
        // Where the two figures for its middle differ, every check that uses x and y is off by as much.
        void noteOffset(Map<String, Object?> m) {
          final List<double> c = midOf(m), a = askedMid(m);
          if (!c.any((double v) => v.isNaN) &&
              ((c[0] - a[0]).abs() > 4 || (c[1] - a[1]).abs() > 4)) {
            t.note(
              'the Sidekick\'s middle worked out from where its window was asked to be (x, y) is ${(a[0] - c[0]).toStringAsFixed(1)}, ${(a[1] - c[1]).toStringAsFixed(1)} points from where it is on the screen: checks that use x and y are off by as much',
            );
          }
        }

        heard(
          'sidekick panel: still open 1.5 s after the hold is let go, never closed, the Sidekick at its spot, the panel unchanged',
          s['panelOpen'] == true &&
              numOf(s['panelOpened']) == openedWas + 1 &&
              s['panelClosed'] == closedWas &&
              lensUntouched(s) &&
              atItsSpot(s) &&
              numOf(s['panelLeastSinceOpen']) >= 0.999 &&
              numOf(s['panelShade']) == 0,
          'open ${s['panelOpen']}, opened ${numOf(s['panelOpened']) - openedWas} time(s), last closed "${s['panelClosed']}" (before: "$closedWas"), its window added ${numOf(s['lensAdds']) - addsWas} and taken off ${numOf(s['lensRemoves']) - removesWas} times, ${spotSaid(s)}, the panel at least ${numOf(s['panelLeastSinceOpen']).toStringAsFixed(2)}, shade ${numOf(s['panelShade']).toStringAsFixed(2)}',
        );
        noteOffset(s);
        heard(
          'sidekick panel: held, its own settings come up, over the app it is in',
          opened,
          'open ${s['panelOpen']}, fully ${s['panelOpenFully']}',
        );
        void inPanel(String name, bool ok, [String note = '']) => opened
            ? t.check(name, ok, note)
            : t.skip(name, 'its own settings did not come up');
        inPanel(
          'sidekick panel: Prism did not come forward, and its own settings stayed shut',
          numOf(s['forwards']).toInt() == forwardsWas &&
              !_panelOpen &&
              !_pointsDown(_signTurn.target),
          'brought forward ${numOf(s['forwards']).toInt() - forwardsWas} times, Prism\'s settings ${_panelOpen ? 'open' : 'shut'}',
        );
        inPanel(
          'sidekick panel: it never takes the focus (Back and the keyboard stay the app\'s)',
          s['panelFocusable'] == false,
          'focusable ${s['panelFocusable']}',
        );
        final List<Object?> pbox =
            (s['panelBox'] as List<Object?>?) ?? const <Object?>[];
        // Its middle, in points, where it is on the screen.
        final double sidekickX = midOf(s)[0];
        final double sidekickR = numOf(s['lensRadius']);
        final bool sidekickRight = s['panelOnRight'] == true;
        // How far the open panel reaches over the Sidekick's glass, sideways, in points (0 or less:
        // clear of it). From build 185 the panel ends before the Sidekick's furthest Hovering spot,
        // so this is never more than 0, whatever its Hovering (the owner's rule).
        double overOf(Map<String, Object?> m) {
          final List<Object?> b =
              (m['panelBox'] as List<Object?>?) ?? const <Object?>[];
          final double x = midOf(m)[0], r = numOf(m['lensRadius']);
          return b.length != 4
              ? double.nan
              : (m['panelOnRight'] == true
                    ? numOf(b[0]) + numOf(b[2]) - (x - r)
                    : x + r - numOf(b[0]));
        }

        String sideOf(Map<String, Object?> m) {
          final double o = overOf(m);
          final List<Object?> b =
              (m['panelBox'] as List<Object?>?) ?? const <Object?>[];
          return 'the Sidekick on the ${m['panelOnRight'] == true ? 'right' : 'left'}, its middle at ${midOf(m)[0].toStringAsFixed(1)}, its glass ${numOf(m['lensRadius']).toStringAsFixed(1)} across from it, Hovering ${numOf(kept(m)?['gap']).toStringAsFixed(1)}; the panel ${o > 0 ? 'over its glass by ${o.toStringAsFixed(1)} points' : 'clear of it by ${(-o).toStringAsFixed(1)} points'}; box ${b.map((Object? v) => numOf(v).round()).join(', ')}';
        }

        final String sideSaid = sideOf(s);
        // Its width: the screen, less 8 points at the far edge, the Sidekick's furthest Hovering
        // (15 from 191; 36 before), its window (its glass and 5 points round it) and 8 to spare.
        final double screenW = numOf(s['w']) / dp;
        final double wantW = math.max(
          250,
          screenW - 8 - (RestBubble.gapMax + 2 * (sidekickR + 5) + 8),
        );
        inPanel(
          'sidekick panel: it ends before the Sidekick\'s furthest Hovering spot, on the side away from it',
          pbox.length == 4 &&
              (numOf(pbox[2]) - wantW).abs() < 2 &&
              (sidekickRight
                  ? numOf(pbox[0]) + numOf(pbox[2]) / 2 < sidekickX
                  : numOf(pbox[0]) + numOf(pbox[2]) / 2 > sidekickX) &&
              overOf(s) <= 0.5,
          '$sideSaid; width ${pbox.length == 4 ? numOf(pbox[2]).toStringAsFixed(1) : '?'} (want ${wantW.toStringAsFixed(1)} on a ${screenW.toStringAsFixed(0)}-point screen)',
        );
        inPanel('sidekick panel: it grew out of the Sidekick, where it is', () {
          final List<Object?> from =
              (s['panelFrom'] as List<Object?>?) ?? const <Object?>[];
          return from.length == 3 && (numOf(from[0]) - sidekickX).abs() < 6;
        }(), 'from ${s['panelFrom']}');
        inPanel(
          'sidekick panel: the Sidekick stays in sight at its spot, its window never taken off',
          atItsSpot(s) && lensUntouched(s) && s['covered'] != true,
          'shown ${s['lens']}, ${spotSaid(s)}, its window added ${numOf(s['lensAdds']) - addsWas} and taken off ${numOf(s['lensRemoves']) - removesWas} times, hidden ${s['covered']}',
        );
        // Opening and closing (the same moments, both ways), and open: the panel draws nothing
        // over the Sidekick's glass, so the Sidekick (its own window, under the panel's) shows on
        // every frame. Each moment is written into the report in words, with what the panel drew
        // there: whether it ran, its rectangle, the Sidekick's place and size, how faded it was.
        if (opened) {
          const String clearOfIt =
              'sidekick panel: growing, shrinking and open, the panel never draws over the Sidekick\'s glass';
          final Map<String, Object?> m = await t.lens(<String, Object?>{
            'op': 'panel',
            'what': 'sample',
            'stages': <double>[0.03, 0.06, 0.12, 0.25, 0.5, 0.8, 1.0],
          }, extraMs: 4000);
          final List<Map<String, Object?>> stages = <Map<String, Object?>>[
            for (final Object? x
                in (m['samples'] as List<Object?>?) ?? const <Object?>[])
              if (x is Map) x.cast<String, Object?>(),
          ];
          bool clear(Map<String, Object?> st) =>
              numOf(st['sampleDraws']) >= 1 &&
              numOf(st['sampleMiddle']) == 0 &&
              numOf(st['sampleRing']) <= 8;
          String said(Map<String, Object?> st) =>
              '${(numOf(st['sampleAt']) * 100).round()}% open: the panel ${numOf(st['sampleDraws']) >= 1 ? 'drawn' : 'NOT drawn'}${st['sampleCovers'] == true ? ', its rectangle over the glass' : ', clear of the glass'}, faded to ${numOf(st['sampleFade']).toStringAsFixed(2)}; over the glass: middle ${numOf(st['sampleMiddle']).toInt()}, ring ${numOf(st['sampleRing']).toInt()} (of 255); just beside it ${numOf(st['sampleBeside']).toInt()}; rectangle ${st['sampleRect']}, the Sidekick at ${st['sampleLens']}, glass ${numOf(st['sampleSr']).toStringAsFixed(1)}';
          if (stages.isEmpty) {
            t.check(
              clearOfIt,
              false,
              'no samples: ${m['note'] ?? 'no answer'}',
            );
          } else {
            for (final Map<String, Object?> st in stages) {
              t.note('the Sidekick under its panel, ${said(st)}');
            }
            t.check(
              clearOfIt,
              stages.every(clear),
              stages
                  .where((Map<String, Object?> st) => !clear(st))
                  .map(said)
                  .join(' | '),
            );
          }
          // Hovering at the edge, at its usual 8 and at its furthest (15, from 191): the panel never
          // reaches the glass, and does not move.
          final Object? gapWas = kept(await where())?['gap'];
          final List<String> wrongs = <String>[];
          final List<Object?> boxWas = pbox;
          for (final int g in <int>[0, 8, RestBubble.gapMax.round()]) {
            final Map<String, Object?> h = await t.lens(<String, Object?>{
              'op': 'panel',
              'what': 'gap',
              'value': g,
              'settleMs': 1000,
            }, extraMs: 3000);
            final List<Object?> b =
                (h['panelBox'] as List<Object?>?) ?? const <Object?>[];
            final bool still =
                b.length == 4 &&
                boxWas.length == 4 &&
                (numOf(b[0]) - numOf(boxWas[0])).abs() < 1 &&
                (numOf(b[2]) - numOf(boxWas[2])).abs() < 1;
            if (!(overOf(h) <= 0.5) || !still) {
              wrongs.add(
                'Hovering $g: ${sideOf(h)}${still ? '' : ' (the panel moved)'}',
              );
            }
          }
          await t.lens(<String, Object?>{
            'op': 'panel',
            'what': 'gap',
            'value': numOf(gapWas).isNaN ? 8 : numOf(gapWas),
            'settleMs': 900,
          }, extraMs: 3000);
          t.check(
            'sidekick panel: at Hovering 0, 8 and 15 the panel never reaches the Sidekick\'s glass, and stays put',
            wrongs.isEmpty,
            wrongs.isEmpty ? 'clear at all three' : wrongs.join(' | '),
          );
          // Dragged by hand while the panel is open: the Sidekick moves, the panel stays open and
          // follows it up and down (when it is short enough to move; a panel as tall as the screen
          // stays where it is).
          // (Toward the middle of the screen, where there is room: let go, the Sidekick rests no
          // nearer than 48 points to the top or the bottom, so dragged 120 up from high on the
          // screen it would come to rest only part of the way: 190's one miss on the S26, which
          // moved −60 of −120.)
          final Map<String, Object?> d0 = await where();
          final double sizePt = numOf(d0['size']) / dp;
          final double hPt = numOf(d0['h']) / dp;
          final double from = midOf(d0)[1];
          final int dy = from > hPt / 2 ? -120 : 120;
          final double want =
              (from + dy).clamp(48 + sizePt / 2, hPt - 48 - sizePt / 2) - from;
          final Map<String, Object?> d1 = await t.lens(<String, Object?>{
            'op': 'panel',
            'what': 'dragLens',
            'dy': dy,
            'settleMs': 1500,
          }, extraMs: 5000);
          final double moved = midOf(d1)[1] - midOf(d0)[1];
          final List<Object?> b0 =
                  (d0['panelBox'] as List<Object?>?) ?? const <Object?>[],
              b1 = (d1['panelBox'] as List<Object?>?) ?? const <Object?>[];
          // (As tall as it may be: from the panel's own record of its limits. From 186 those end
          // above Prism's bar, so the old figure, the screen less fixed margins, no longer said.)
          final bool tall =
              b0.length == 4 &&
              (d0['panelFills'] == true ||
                  numOf(b0[3]) >=
                      numOf(d0['panelBottomLimit']) -
                          numOf(d0['panelTopLimit']) -
                          1);
          final double boxMoved = b0.length == 4 && b1.length == 4
              ? (numOf(b1[1]) + numOf(b1[3]) / 2) -
                    (numOf(b0[1]) + numOf(b0[3]) / 2)
              : double.nan;
          t.check(
            'sidekick panel: dragged by hand with the panel open, the Sidekick moves and the panel follows it',
            d1['panelOpen'] == true &&
                (moved - want).abs() < 40 &&
                (tall
                    ? boxMoved.abs() < 2 || (boxMoved - moved).abs() < 30
                    : (boxMoved - moved).abs() < 30),
            'the Sidekick moved ${moved.toStringAsFixed(0)} points (dragged $dy from ${from.toStringAsFixed(0)} down the screen, ${want.toStringAsFixed(0)} meant), the panel ${boxMoved.toStringAsFixed(0)}${tall ? ' (as tall as it may be: it may only stay or follow)' : ''}; open ${d1['panelOpen']}; the panel ${b0.length == 4 ? numOf(b0[3]).toStringAsFixed(0) : '?'} tall, may reach from ${numOf(d0['panelTopLimit']).toStringAsFixed(0)} to ${numOf(d0['panelBottomLimit']).toStringAsFixed(0)}, fills it ${d0['panelFills']}',
          );
          // Back to where it was, for what follows.
          await t.lens(<String, Object?>{
            'op': 'panel',
            'what': 'dragLens',
            'dy': -moved.round(),
            'settleMs': 1500,
          }, extraMs: 5000);
          // (196) "Hold to dismiss" high and low on the screen, at Hovering 8 and −48: under the
          // Sidekick (over it low down, where there is no room under it), fully on the screen. The
          // Sidekick is carried to the top and the bottom with the panel open (it stops 48 points
          // from each), and at each its Hovering set as its dial would.
          final Map<String, Object?> p0 = await where();
          final double homeY = midOf(p0)[1];
          for (final (String where0, int dy) in <(String, int)>[
            ('high', -2000),
            ('low', 2000),
          ]) {
            await t.lens(<String, Object?>{
              'op': 'panel',
              'what': 'dragLens',
              'dy': dy,
              'settleMs': 1600,
            }, extraMs: 6000);
            for (final int g in <int>[8, -48]) {
              final Map<String, Object?> pm = await t.lens(<String, Object?>{
                'op': 'panel',
                'what': 'gap',
                'value': g,
                'settleMs': 1100,
              }, extraMs: 3000);
              final (bool ok, String said) = pillOk(pm);
              t.check(
                'sidekick panel: "Hold to dismiss" under (or over) the Sidekick, fully on the screen, $where0, at Hovering ${g < 0 ? '−${-g}' : '$g'}',
                pm['panelOpen'] == true && ok,
                'panel open ${pm['panelOpen']}; $said',
              );
            }
          }
          await t.lens(<String, Object?>{
            'op': 'panel',
            'what': 'gap',
            'value': numOf(gapWas).isNaN ? 8 : numOf(gapWas),
            'settleMs': 900,
          }, extraMs: 3000);
          final Map<String, Object?> p1 = await where();
          await t.lens(<String, Object?>{
            'op': 'panel',
            'what': 'dragLens',
            'dy': (homeY - midOf(p1)[1]).round(),
            'settleMs': 1500,
          }, extraMs: 5000);
        }
        // Both dials on the screen as it opens, without scrolling; and its bottom at least 8 points
        // above Prism's bar (in Prism) and above Android's own bar (build 186).
        bool dialsShown(Map<String, Object?> m) {
          final List<Object?> b =
              (m['panelBox'] as List<Object?>?) ?? const <Object?>[];
          final List<Object?> dials =
              (m['panelDials'] as List<Object?>?) ?? const <Object?>[];
          if (b.length != 4 || dials.length != 2) {
            return false;
          }
          final double top = numOf(b[1]), bottom = numOf(b[1]) + numOf(b[3]);
          return dials.every((Object? d) {
            final List<Object?> r = d is List ? d : const <Object?>[];
            return r.length == 4 &&
                numOf(r[1]) >= top - 0.5 &&
                numOf(r[1]) + numOf(r[3]) <= bottom + 0.5;
          });
        }

        // How much room is left under the dials, inside the panel, in points (187: at least 8 on
        // the S25 at font scale 1).
        String spareUnderDials(Map<String, Object?> m) {
          final List<Object?> b =
              (m['panelBox'] as List<Object?>?) ?? const <Object?>[];
          final List<Object?> dials =
              (m['panelDials'] as List<Object?>?) ?? const <Object?>[];
          if (b.length != 4 || dials.isEmpty) {
            return 'room under the dials unknown';
          }
          double lowest = double.negativeInfinity;
          for (final Object? d in dials) {
            final List<Object?> r = d is List ? d : const <Object?>[];
            if (r.length == 4) {
              lowest = math.max(lowest, numOf(r[1]) + numOf(r[3]));
            }
          }
          final double room = numOf(b[1]) + numOf(b[3]) - lowest;
          return '${room.toStringAsFixed(1)} points to spare under the dials';
        }

        double bottomOf(Map<String, Object?> m) {
          final List<Object?> b =
              (m['panelBox'] as List<Object?>?) ?? const <Object?>[];
          return b.length == 4 ? numOf(b[1]) + numOf(b[3]) : double.nan;
        }

        final double screenH = numOf(s['h']) / dp;
        final ui.FlutterView view0 =
            WidgetsBinding.instance.platformDispatcher.views.first;
        final double navTop =
            screenH - view0.padding.bottom / view0.devicePixelRatio;
        final double barTop = _home.dy - _button * 0.62;
        inPanel(
          'sidekick panel: both dials on the screen as it opens, without scrolling',
          dialsShown(s) && numOf(s['panelScroll']) == 0,
          'box ${s['panelBox']}, dials ${s['panelDials']}, scrolled ${s['panelScroll']}; ${spareUnderDials(s)}',
        );
        // The dials' ticks inside their pills, with room under them, from their pixels (188: they
        // ran past the pills' rounded ends, 5 points from the bottom edge).
        if (opened) {
          final Map<String, Object?> px = await panel('pixels');
          bool fits(String d) =>
              numOf(px['pix${d}TickPx']) > 0 &&
              numOf(px['pix${d}TickOutside']) == 0 &&
              numOf(px['pix${d}TickRoom']) >= 6;
          String said(String d) =>
              '${numOf(px['pix${d}TickPx']).round()} tick pixels, ${numOf(px['pix${d}TickOutside']).round()} outside the pill, ${numOf(px['pix${d}TickRoom']).toStringAsFixed(1)} points under the lowest';
          t.check(
            'sidekick panel: the dials\' ticks sit inside their pills, with room under them',
            px['pixNote'] == null && fits('gap') && fits('tuck'),
            px['pixNote'] != null
                ? '${px['pixNote']}'
                : 'Hovering: ${said('gap')}; Tucked in: ${said('tuck')}; text size ${numOf(px['pixFontScale']).toStringAsFixed(2)}',
          );
          // (The point the held-dial check reads for "the rest of the panel" is solid now, with
          // no dial held: so its 0 while one is held means the panel is gone there, not that the
          // point missed the panel, as 189's did on the S25.)
          final double full = numOf(px['pixSurfaceAlpha']).isNaN
              ? 255
              : numOf(px['pixSurfaceAlpha']);
          t.check(
            'sidekick panel: with no dial held, the point read for "the rest of the panel" is solid',
            numOf(px['pixRest']) >= full - 5,
            'it reads ${px['pixRest']} of ${full.round()}',
          );
        }
        inPanel(
          'sidekick panel: in Prism, its bottom at least 8 points above Prism\'s bar',
          bottomOf(s) <= math.min(barTop, navTop) - 8 + 0.5,
          'its bottom at ${bottomOf(s).toStringAsFixed(1)}, Prism\'s bar from ${barTop.toStringAsFixed(1)} (Android was told ${s['panelBarTop']}), Android\'s bar from ${navTop.toStringAsFixed(1)}; in Prism ${s['panelInPrism']}',
        );
        inPanel(
          'sidekick panel: no shade: nothing is drawn around the Sidekick or the panel',
          numOf(s['panelShade']) == 0,
          'shade ${numOf(s['panelShade']).toStringAsFixed(2)}',
        );
        // (196) The header is only its title and the X: "Dismiss" is a pill of its own, under the
        // Sidekick.
        {
          final Map<Object?, Object?> hd = s['panelHeader'] is Map
              ? s['panelHeader']! as Map<Object?, Object?>
              : const <Object?, Object?>{};
          inPanel(
            'sidekick panel: the header has no Dismiss: only its title and the X',
            hd.isNotEmpty && hd['dismiss'] == null && s['pill'] is Map,
            'header ${hd.isEmpty ? 'not read' : 'title to ${numOf(hd['titleRight']).toStringAsFixed(1)}, the X\'s touch from ${numOf(hd['closeTouchLeft']).toStringAsFixed(1)}, Dismiss in it ${hd['dismiss'] != null}'}; the pill ${s['pill'] is Map ? 'under the Sidekick' : 'not there'}',
          );
          final (bool ok, String said) = pillOk(s);
          inPanel(
            'sidekick panel: "Hold to dismiss" under (or over) the Sidekick, fully on the screen, as it opens',
            ok,
            said,
          );
        }
        // Each two-way choice, changed in the panel and put back: kept by Android, and Prism's
        // copy follows; Prism's own choice is not touched.
        Future<void> choice(
          String what,
          String part,
          String key,
          bool Function() copy,
          bool Function() prismOwn, {
          required bool first,
        }) async {
          if (!opened) {
            t.skip(
              'sidekick panel: $what changed, kept by Android, Prism\'s own untouched',
              'its own settings did not come up',
            );
            return;
          }
          final Map<Object?, Object?>? had = kept(await where());
          final bool was = had?[key] == true, prismWas = prismOwn();
          // (Index 0 is [first]'s value, index 1 the other.)
          int at(bool v) => v == first ? 0 : 1;
          s = await panel('tap', part: '$part.${at(!was)}');
          final Map<Object?, Object?>? now = kept(s);
          await Robot.wait(300);
          t.check(
            'sidekick panel: $what changed, kept by Android, Prism\'s own untouched',
            now?[key] == !was && copy() == !was && prismOwn() == prismWas,
            'Android ${now?[key]}, Prism\'s copy ${copy()}, Prism\'s own ${prismOwn()} (was $prismWas)',
          );
          s = await panel('tap', part: '$part.${at(was)}');
          await Robot.wait(300);
          t.check(
            'sidekick panel: $what back as it was',
            kept(s)?[key] == was && copy() == was,
            'Android ${kept(s)?[key]}, Prism\'s copy ${copy()}',
          );
        }

        await choice(
          'Labels',
          'names',
          'names',
          () => lensOf.sideNames,
          () => BlobSlots.instance.names,
          first: true,
        );
        await choice(
          'Icons',
          'prismIcons',
          'prismIcons',
          () => lensOf.sidePrismIcons,
          () => Apps.instance.blobPrismIcons,
          first: true,
        );
        await choice(
          'Colours',
          'vivid',
          'vivid',
          () => lensOf.sideVivid,
          () => Apps.instance.blobVivid,
          first: false,
        );
        // Its look: another one chosen, then its own again.
        if (opened) {
          final String lookWas = '${kept(await where())?['look'] ?? ''}'.isEmpty
              ? 'window'
              : '${kept(await where())?['look']}';
          final String prismLook = Apps.instance.blobLook;
          final String other = lookWas == 'halo' ? 'pearls' : 'halo';
          s = await panel('tap', part: 'look.$other');
          await Robot.wait(300);
          t.check(
            'sidekick panel: another look chosen, kept by Android, Prism\'s own untouched',
            kept(s)?['look'] == other &&
                lensOf.sideLook == other &&
                Apps.instance.blobLook == prismLook,
            'Android ${kept(s)?['look']}, Prism\'s copy ${lensOf.sideLook}, Prism\'s own ${Apps.instance.blobLook}',
          );
          s = await panel('tap', part: 'look.$lookWas');
          t.check(
            'sidekick panel: its own look back',
            kept(s)?['look'] == lookWas,
            'Android ${kept(s)?['look']}, was $lookWas',
          );
        } else {
          t.skip(
            'sidekick panel: another look chosen, kept by Android, Prism\'s own untouched',
            'its own settings did not come up',
          );
        }
        // "Over other apps", off and on again, over Prism: the Sidekick stays (it is in Prism).
        if (opened) {
          s = await panel('tap', part: 'overApps', settleMs: 900);
          t.check(
            'sidekick panel: "Over other apps" off: kept by Android, it stays here, the panel stays',
            kept(s)?['overApps'] == false &&
                !lensOf.floatOut.value &&
                s['lens'] == true &&
                panelUp(s),
            'Android ${kept(s)?['overApps']}, Prism\'s copy ${lensOf.floatOut.value}, shown ${s['lens']}, panel ${s['panelOpen']}',
          );
          s = await panel('tap', part: 'overApps', settleMs: 900);
          t.check(
            'sidekick panel: "Over other apps" on again',
            kept(s)?['overApps'] == true && lensOf.floatOut.value,
            'Android ${kept(s)?['overApps']}',
          );
        }
        // The two dials. Touching one puts the Sidekick in that state at once; the rest of the
        // panel goes see-through, "Where it rests" stays solid; sliding toward the middle of the
        // screen is more; let go, the panel is solid again within 0.3 s, and the Sidekick goes back
        // to the state it was in.
        final double inward = s['panelOnRight'] == true ? -1 : 1;
        // While a dial is held: the whole "Where it rests" section (its title and both dials) is
        // drawn solid, apart from the see-through rest of the panel (187).
        bool solidRests(Map<String, Object?> m) {
          final List<Object?> drawn =
              (m['panelSolidParts'] as List<Object?>?) ?? const <Object?>[];
          final Map<Object?, Object?> dials =
              (m['panelDialsAlpha'] as Map<Object?, Object?>?) ??
              const <Object?, Object?>{};
          return <String>['title', 'gap', 'tuck'].every(drawn.contains) &&
              numOf(m['panelSolidAlpha']) >= 0.999 &&
              numOf(dials['gap']) >= 0.999 &&
              numOf(dials['tuck']) >= 0.999;
        }

        // From the section's own pixels (188: 187 read only what was meant to be drawn, and passed
        // while the phone showed nothing): its area solid (255), the rest of the panel gone (0, from
        // 191; 0.2 in 189 and 190, 0.4 before), and both dials' numbers there, drawn solid.
        bool solidPixels(Map<String, Object?> m) {
          // (As opaque as the panel's own colour can be: 255 in every look so far.)
          final double full = numOf(m['pixSurfaceAlpha']).isNaN
              ? 255
              : numOf(m['pixSurfaceAlpha']);
          return numOf(m['pixBlockLeast']) >= full - 5 &&
              numOf(m['pixRest']) <= 0.06 * full &&
              <String>['gap', 'tuck'].every(
                (String d) =>
                    numOf(m['pix${d}NumberPx']) >= 30 &&
                    numOf(m['pix${d}NumberLeast']) >= full - 5,
              );
        }

        String pixelsSaid(Map<String, Object?> m) => m['pixNote'] != null
            ? 'its pixels: ${m['pixNote']}'
            : 'its pixels: the section at least ${m['pixBlockLeast']} of 255, the rest ${m['pixRest']}; '
                  'Hovering\'s number ${m['pixgapNumberPx']} pixels at least ${m['pixgapNumberLeast']}, '
                  'Tucked in\'s ${m['pixtuckNumberPx']} at least ${m['pixtuckNumberLeast']}';

        // Let go: the panel was drawn solid again (over 0.97) within 0.3 s, and is solid now, with
        // "Where it rests" no longer drawn apart.
        bool solidSoon(Map<String, Object?> m) {
          final double after = numOf(m['panelSolidAfterMs']);
          return after >= 0 &&
              after <= 300 &&
              numOf(m['panelAlpha']) > 0.97 &&
              m['panelSettling'] != true &&
              m['panelSolidDial'] == '';
        }

        Future<void> dial(String id, String name, bool tucks) async {
          if (!opened) {
            t.skip(
              'sidekick panel: $name touched, the Sidekick goes there, the rest of the panel see-through, "Where it rests" solid',
              'its own settings did not come up',
            );
            return;
          }
          final double was = numOf(kept(await where())?[id]);
          s = await panel(
            'press',
            part: 'ruler.$id',
            holdMs: 900,
            pixels: true,
          );
          t.check(
            'sidekick panel: $name touched, the Sidekick goes there, the rest of the panel see-through, "Where it rests" solid',
            (s['tucked'] == true) == tucks &&
                numOf(s['panelAlpha']) <= 0.06 &&
                s['panelSolidDial'] == id &&
                solidRests(s) &&
                solidPixels(s) &&
                numOf(s['panelShade']) == 0 &&
                numOf(s['panelLeastSinceOpen']) >= 0.999 &&
                s['lens'] == true,
            'tucked ${s['tucked']}, the rest of the panel ${numOf(s['panelAlpha']).toStringAsFixed(2)} opaque; ${pixelsSaid(s)}; meant to be drawn solid ${s['panelSolidParts']} at ${numOf(s['panelSolidAlpha']).toStringAsFixed(2)}; shade ${numOf(s['panelShade']).toStringAsFixed(2)}, its contents at least ${numOf(s['panelLeastSinceOpen']).toStringAsFixed(2)}',
          );
          // (The press lets go about half a second after it answers.)
          await Robot.wait(1000);
          s = await where();
          t.check(
            'sidekick panel: $name let go, the panel is solid again within 0.3 s, the Sidekick as it was',
            solidSoon(s) &&
                numOf(s['panelLeastSinceOpen']) >= 0.999 &&
                (s['tucked'] == true) == wasTucked,
            'solid again ${numOf(s['panelSolidAfterMs']).round()} ms after the let-go, now ${numOf(s['panelAlpha']).toStringAsFixed(2)} opaque, drawn apart "${s['panelSolidDial']}", its contents at least ${numOf(s['panelLeastSinceOpen']).toStringAsFixed(2)}, tucked ${s['tucked']} (was $wasTucked)',
          );
          // Slid toward the middle by 4 points' worth (16 points of finger a point), then back.
          final double max = id == 'gap'
              ? RestBubble.gapMax
              : RestBubble.tuckMax;
          final double min = id == 'gap'
              ? RestBubble.gapMin
              : RestBubble.tuckMin;
          final double step = was + 4 <= max ? 4 : -4;
          s = await panel(
            'drag',
            part: 'ruler.$id',
            dx: <double>[inward * step * 16],
            legMs: 700,
            settleMs: 1300,
          );
          final double now = numOf(kept(s)?[id]);
          t.check(
            'sidekick panel: $name slid toward the ${step > 0 ? 'middle' : 'edge'}, ${step.abs().round()} points ${step > 0 ? 'more' : 'less'}, kept by Android',
            (now - (was + step).clamp(min, max)).abs() < 0.01 &&
                (numOf(id == 'gap' ? lensOf.sideGap : lensOf.sideTuck) - now)
                        .abs() <
                    0.01,
            'was ${was.round()}, now ${now.round()}, Prism\'s copy ${(id == 'gap' ? lensOf.sideGap : lensOf.sideTuck).round()}',
          );
          if (id == 'gap' && !wasTucked) {
            await Robot.wait(600);
            final Map<String, Object?> r = await where();
            t.check(
              'sidekick panel: it rests at the new distance',
              (fromEdge(r) - now).abs() < 6 && r['tucked'] != true,
              '${fromEdge(r).toStringAsFixed(1)} points from the edge',
            );
          }
          s = await panel(
            'drag',
            part: 'ruler.$id',
            dx: <double>[-inward * step * 16],
            legMs: 700,
            settleMs: 1300,
          );
          t.check(
            'sidekick panel: $name slid back',
            (numOf(kept(s)?[id]) - was).abs() < 0.01,
            'now ${numOf(kept(s)?[id]).round()}, was ${was.round()}',
          );
        }

        await dial('gap', 'Hovering', false);
        await dial('tuck', 'Tucked in', true);
        // A dial turned in one long drag: the rest of the panel stays see-through the whole time.
        // Then two strokes with a finger back on it 0.05 s after the let-go: it carries straight on,
        // with no dip in between. A moment after the last stroke, solid again within 0.3 s (187).
        if (opened) {
          final double was = numOf(kept(await where())?['gap']);
          final double way = RestBubble.gapMax - was >= 6 ? 1 : -1;
          Map<String, Object?> d = await panel(
            'drag',
            part: 'ruler.gap',
            dx: <double>[
              inward * way * 30,
              -inward * way * 30,
              inward * way * 30,
            ],
            legMs: 500,
            settleMs: 200,
          );
          final double most = numOf(d['panelHeldAlphaMost']);
          final int frames = numOf(d['panelHeldFrames']).isNaN
              ? 0
              : numOf(d['panelHeldFrames']).toInt();
          t.check(
            'sidekick panel: a dial dragged for 1.5 s, the rest of the panel stays see-through the whole time',
            frames >= 3 && most <= 0.06,
            'the most opaque it was drawn ${most.toStringAsFixed(2)}, over $frames frames',
          );
          await Robot.wait(600);
          final int carried = numOf(d['panelCarriedOn']).isNaN
              ? 0
              : numOf(d['panelCarriedOn']).toInt();
          d = await panel(
            'drag',
            part: 'ruler.gap',
            dx: <double>[-inward * way * 30],
            again: <double>[inward * way * 30],
            gapMs: 50,
            legMs: 400,
            settleMs: 200,
          );
          final int carriedNow = numOf(d['panelCarriedOn']).isNaN
              ? 0
              : numOf(d['panelCarriedOn']).toInt();
          t.check(
            'sidekick panel: a finger back on the dial 0.05 s after the let-go carries straight on, no dip',
            numOf(d['panelHeldAlphaMost']) <= 0.06 && carriedNow == carried + 1,
            'the most opaque it was drawn over both strokes ${numOf(d['panelHeldAlphaMost']).toStringAsFixed(2)}, over ${numOf(d['panelHeldFrames']).isNaN ? 0 : numOf(d['panelHeldFrames']).toInt()} frames; carried on ${carriedNow - carried} time(s)',
          );
          await Robot.wait(400);
          s = await where();
          t.check(
            'sidekick panel: let go after the last stroke, the panel is solid again within 0.3 s',
            solidSoon(s),
            'solid again ${numOf(s['panelSolidAfterMs']).round()} ms after the let-go, now ${numOf(s['panelAlpha']).toStringAsFixed(2)} opaque, settling ${s['panelSettling']}, drawn apart "${s['panelSolidDial']}"',
          );
          await lensOf.testPut(<String, Object>{'gap': was});
          await Robot.wait(400);
        }
        // A flick: it coasts on past where the finger stopped, and lands on a whole point.
        if (opened) {
          final double was = numOf(kept(await where())?['gap']);
          final double room = RestBubble.gapMax - was;
          final double way = room >= 8 ? 1 : -1;
          s = await panel(
            'flick',
            part: 'ruler.gap',
            dx: <double>[inward * way * 48],
            settleMs: 2200,
          );
          final double now = numOf(kept(s)?['gap']);
          t.check(
            'sidekick panel: Hovering flicked, it coasts past the finger and lands on a whole point',
            (now - now.roundToDouble()).abs() < 0.001 && (now - was) * way > 3,
            'was ${was.round()}, now $now, the finger moved 3 points\' worth',
          );
          await lensOf.testPut(<String, Object>{'gap': was});
          await Robot.wait(400);
        }
        // Prism's panel colours, kept by Android for this panel.
        t.check(
          'sidekick panel: Prism\'s panel colours have reached it',
          numOf(kept(await where())?['palette']) >= 16,
          '${kept(await where())?['palette']} colours kept',
        );
        // Closed by its X: the Sidekick as it was.
        if (opened) {
          s = await panel('tap', part: 'close', settleMs: 900);
          t.check(
            'sidekick panel: its X closes it, back into the Sidekick, which is as it was',
            s['panelOpen'] != true &&
                s['lens'] == true &&
                (s['tucked'] == true) == wasTucked,
            'open ${s['panelOpen']}, shown ${s['lens']}, tucked ${s['tucked']}',
          );
        }
        // Over another app: the panel ends above Android's own bar, and its dials are on the screen.
        if (opened && t.other != null) {
          const String outside =
              'sidekick panel: over another app, its bottom at least 8 points above Android\'s bar, its dials on the screen';
          await shut();
          final Map<String, Object?> lv = await t.lens(<String, Object?>{
            'op': 'leave',
            'pkg': otherPkg,
          }, extraMs: 3000);
          if (lv['ok'] != false && lv['fg'] == false) {
            final bool up = await holdOpen('sidekick held over another app');
            final Map<String, Object?> o = await where();
            t.check(
              outside,
              up &&
                  o['panelInPrism'] != true &&
                  bottomOf(o) <= navTop - 8 + 0.5 &&
                  dialsShown(o),
              'open $up, in Prism ${o['panelInPrism']}, its bottom at ${bottomOf(o).toStringAsFixed(1)}, Android\'s bar from ${navTop.toStringAsFixed(1)}; box ${o['panelBox']}, dials ${o['panelDials']}',
            );
            await shut();
          } else {
            t.skip(outside, 'the other app did not come to the front');
          }
          if (lv['ok'] != false) {
            await t.lens(<String, Object?>{'op': 'front'}, extraMs: 4000);
          }
        }
        // Closed by a tap on the shade, by a tap on the Sidekick (which then does nothing else),
        // and by Home.
        for (final (String how, Future<void> Function() close)
            in <(String, Future<void> Function())>[
              (
                'a tap on the shade',
                () async => panel('tap', part: 'shade', settleMs: 900),
              ),
              (
                'a tap on the Sidekick',
                () async => press(
                  'sidekick tapped, its panel open',
                  <Offset>[],
                  holdMs: 60,
                  settleMs: 1100,
                ),
              ),
              ('Home', () async => panel('home', settleMs: 900)),
            ]) {
          if (!await holdOpen('sidekick held, to close it by $how')) {
            t.skip(
              'sidekick panel: $how closes it',
              'its own settings did not come up',
            );
            continue;
          }
          await close();
          await Robot.wait(500);
          s = await where();
          t.check(
            'sidekick panel: $how closes it',
            s['panelOpen'] != true && s['menu'] != true && s['lens'] == true,
            'open ${s['panelOpen']}, its blobs ${s['menu']}, shown ${s['lens']}, closed by "${s['panelClosed']}"',
          );
        }
        // The other two ways of opening it: held in the middle of its blobs, and Edit Sidekick.
        if (await openMenu()) {
          await menu('middleHold', settleMs: 1500);
          await Robot.wait(900);
          s = await where();
          heard(
            'sidekick panel: held in the middle of its blobs, its own settings come up',
            panelUp(s) && s['menu'] != true && !_panelOpen,
            'open ${s['panelOpen']}, its blobs ${s['menu']}',
          );
          await shut();
        }
        if (await openMenu()) {
          await menu('spaceHold', settleMs: 900);
          s = await menu('pop', which: 0, settleMs: 1500);
          await Robot.wait(900);
          s = await where();
          heard(
            'sidekick panel: Edit Sidekick brings its own settings',
            panelUp(s) && s['menu'] != true && !_panelOpen,
            'open ${s['panelOpen']}, its blobs ${s['menu']}',
          );
          await shut();
        }
        // The keyboard: Prism's own text field has it up, the Sidekick's panel opens over it and
        // closes again. The keyboard must stay up the whole time (decision A, build 177: the
        // panel never takes the focus). Prism's window reads how tall the keyboard is.
        Diag.instance.typingShown.value = true;
        await Robot.wait(400);
        Diag.instance.typing.requestFocus();
        double keyboard() => WidgetsBinding
            .instance
            .platformDispatcher
            .views
            .first
            .viewInsets
            .bottom;
        for (int i = 0; i < 30 && keyboard() <= 0; i++) {
          await Robot.wait(100);
        }
        if (keyboard() <= 0) {
          t.skip(
            'sidekick panel: opened and closed over a keyboard, the keyboard stays up',
            'the keyboard did not come up for Prism\'s own text field',
          );
        } else {
          await Robot.wait(500);
          final List<double> seen = <double>[];
          final Timer every = Timer.periodic(
            const Duration(milliseconds: 100),
            (Timer _) => seen.add(keyboard()),
          );
          final bool up = await holdOpen('sidekick held, over a keyboard');
          await shut();
          await Robot.wait(800);
          every.cancel();
          t.check(
            'sidekick panel: opened and closed over a keyboard, the keyboard stays up',
            up && seen.isNotEmpty && seen.every((double k) => k > 0),
            up
                ? (seen.every((double k) => k > 0)
                      ? 'up the whole time (${seen.length} readings)'
                      : 'down at ${seen.indexWhere((double k) => k <= 0) * 100} ms')
                : 'its own settings did not come up',
          );
        }
        Diag.instance.typing.unfocus();
        Diag.instance.typingShown.value = false;
        await Robot.wait(900);
        // The two distances at their ends (put by the test, as the dials would): it goes there.
        final double gapWas = lensOf.sideGap, tuckWas = lensOf.sideTuck;
        for (final double g in <double>[RestBubble.gapMin, RestBubble.gapMax]) {
          await lensOf.testPut(<String, Object>{'gap': g}, show: 'rest');
          await Robot.wait(900);
          s = await where();
          // (Below 0 the points are at its standard size, 84, and scale with it, 189.)
          final double k = numOf(s['size']) / dp / 84;
          final double want = g < 0 ? g * k : g;
          t.check(
            'sidekick: distance from the edge ${g.round()}, it rests there',
            (fromEdge(s) - want).abs() < 6 && s['tucked'] != true,
            '${fromEdge(s).toStringAsFixed(1)} points from the edge (${want.toStringAsFixed(1)} at its size)',
          );
          // How much of its glass is past the edge, and the grab area beside it (189).
          final List<Object?> mid =
              (s['lensMid'] as List<Object?>?) ?? const <Object?>[];
          final double r = numOf(s['lensRadius']);
          final double screenW = wPx / dp;
          final double pastShare = mid.length == 2 && r > 0
              ? math.max(
                      0,
                      math.max(r - numOf(mid[0]), numOf(mid[0]) + r - screenW),
                    ) /
                    (2 * r)
              : double.nan;
          final List<Object?> gb =
              (s['gripBox'] as List<Object?>?) ?? const <Object?>[];
          final double gripW = gb.length == 4 ? numOf(gb[2]) / dp : 0;
          final bool gripAtEdge =
              gb.length == 4 &&
              (numOf(gb[0]) <= 1 || numOf(gb[0]) + numOf(gb[2]) >= wPx - 1);
          // (Beside it: against where Android has put the Sidekick's own window on the screen,
          // measured as the strip's is. Until 191 this used its "y", which carries a stale offset
          // between a window's own place and the screen's (the 39 points in every report), so on
          // the S25 a strip in the right place read "beside it false".)
          final List<Object?> ls =
              (s['lensScreen'] as List<Object?>?) ?? const <Object?>[];
          final bool gripBeside =
              gb.length == 4 &&
              ls.length == 4 &&
              numOf(gb[1]) <= numOf(ls[1]) + 1 &&
              numOf(gb[1]) + numOf(gb[3]) >= numOf(ls[1]) + numOf(ls[3]) - 1;
          if (g < 0) {
            // (At −48, from 191, 43 of its glass's 74 points are past the edge: 58.1%. Its window
            // is its glass and 5 points round it.)
            final double wantShare = (-RestBubble.gapMin - 5) / 74;
            t.check(
              'sidekick: Hovering at its closest (${RestBubble.gapMin.round()}), ${(wantShare * 100).toStringAsFixed(1)}% of it past the edge',
              (pastShare - wantShare).abs() < 0.04,
              '${(pastShare * 100).toStringAsFixed(1)}% of its glass past the edge (${(wantShare * 100).toStringAsFixed(1)}% meant)',
            );
            // (190: the owner asked for more room, 80 wide and the Sidekick + 48 tall; and it must
            // be kept from Back, within Android's 200 points per edge.)
            final double gripH = gb.length == 4 ? numOf(gb[3]) / dp : 0;
            final List<Object?> ex =
                (s['gripExcluded'] as List<Object?>?) ?? const <Object?>[];
            final bool exAll = ex.any((Object? r) {
              final List<Object?> q = r is List ? r : const <Object?>[];
              return q.length == 4 &&
                  numOf(q[0]) <= 0 &&
                  numOf(q[1]) <= 0 &&
                  numOf(q[2]) >= numOf(gb.length == 4 ? gb[2] : 0) &&
                  numOf(q[3]) >= numOf(gb.length == 4 ? gb[3] : 0);
            });
            final double asked = numOf(s['edgeAskedDp']);
            final String nav = '${s['nav'] ?? '?'}';
            t.check(
              'sidekick: resting past the edge, a grab strip 80 points wide and 48 taller than it, at the edge, beside it',
              s['gripOpen'] == true &&
                  s['gripHover'] == true &&
                  gripW >= 79.5 &&
                  gripH >= numOf(s['size']) / dp + 47.5 &&
                  gripAtEdge &&
                  gripBeside,
              'grip ${s['gripOpen'] == true ? 'open' : 'none'} (for resting past the edge: ${s['gripHover']}), ${gripW.toStringAsFixed(1)} × ${gripH.toStringAsFixed(1)} points (the Sidekick ${(numOf(s['size']) / dp).toStringAsFixed(1)}), at the edge $gripAtEdge, beside it $gripBeside (the strip ${gb.length == 4 ? '${(numOf(gb[1]) / dp).round()}–${((numOf(gb[1]) + numOf(gb[3])) / dp).round()}' : '?'}, the Sidekick ${ls.length == 4 ? '${(numOf(ls[1]) / dp).round()}–${((numOf(ls[1]) + numOf(ls[3])) / dp).round()}' : '?'} points down the screen); '
                  '${showing(s).toStringAsFixed(1)} points of the Sidekick showing',
            );
            // Kept from Back: only where there is a Back swipe at the sides (gesture navigation).
            const String kept =
                'sidekick: resting past the edge, its grab strip kept from Back, within Android\'s 200 points per edge';
            if (!nav.startsWith('gestures') && nav != '?' && nav != 'unknown') {
              t.skip(
                kept,
                'not applicable: $nav navigation (no Back swipe at the sides)',
              );
            } else {
              t.check(
                kept,
                s['gripExcluded'] != null && exAll && asked <= 200.5,
                '${s['gripExcluded'] == null ? 'this Android cannot keep it from Back' : 'all of it ${exAll ? 'kept' : 'NOT kept'}, ${asked.toStringAsFixed(0)} of the 200 points Android allows at that edge${asked > 200.5 ? ' (OVER: Android will cut it short)' : ''}'}; navigation $nav; touches on a strip taken by Android so far: ${s['gripCancels']}',
              );
            }
          } else {
            t.check(
              'sidekick: Hovering at its farthest, wholly on the screen, no grab area added',
              pastShare == 0 && s['gripOpen'] != true,
              '${(pastShare * 100).toStringAsFixed(1)}% past the edge, grip ${s['gripOpen'] == true ? 'open' : 'none'}',
            );
          }
        }
        // Safe from Back with its blobs out (194): at Hovering −48 on each side, with its blobs
        // out, its spot is kept from Android's Back gesture (the menu covers the whole screen, so
        // it asks for it): its glass and at least 24 points above and below, from the edge.
        {
          const String safe =
              'sidekick: at Hovering −48 with its blobs out, on each side, its spot is kept from Back (its glass and 24 points above and below)';
          final String nav = '${(await where())['nav'] ?? '?'}';
          if (!nav.startsWith('gestures') && nav != '?' && nav != 'unknown') {
            t.skip(
              safe,
              'not applicable: $nav navigation (no Back swipe at the sides)',
            );
          } else {
            final List<String> said = <String>[];
            bool all = true;
            await lensOf.testPut(<String, Object>{
              'gap': RestBubble.gapMin,
            }, show: 'rest');
            await Robot.wait(900);
            for (final bool right in <bool>[false, true]) {
              // Carried to that side, halfway down; let go, it rests there.
              await press(
                'sidekick carried to the ${right ? 'right' : 'left'}',
                <Offset>[
                  Offset(sc.width * (right ? 0.9 : 0.1), sc.height * 0.5),
                ],
                legMs: 600,
                endMs: 200,
                settleMs: 1200,
              );
              await Robot.wait(700);
              // Its blobs out.
              await press(
                'sidekick tapped',
                <Offset>[],
                holdMs: 60,
                settleMs: 1100,
              );
              await Robot.wait(500);
              final Map<String, Object?> m = await where();
              final List<Object?> ex =
                  (m['menuExcluded'] as List<Object?>?) ?? const <Object?>[];
              final List<Object?> mid =
                  (m['lensMid'] as List<Object?>?) ?? const <Object?>[];
              final double r = numOf(m['lensRadius']);
              bool ok = false;
              String how =
                  'its blobs ${m['menu'] == true ? 'out' : 'in'}, nothing kept from Back';
              if (m['menu'] == true &&
                  ex.length == 4 &&
                  mid.length == 2 &&
                  !r.isNaN) {
                final double l = numOf(ex[0]) / dp, tp = numOf(ex[1]) / dp;
                final double rr = l + numOf(ex[2]) / dp,
                    bt = tp + numOf(ex[3]) / dp;
                final double gx = numOf(mid[0]), gy = numOf(mid[1]);
                final bool atEdge = right ? rr >= wPx / dp - 1 : l <= 1;
                final bool across = right ? l <= gx - r : rr >= gx + r;
                ok =
                    atEdge &&
                    across &&
                    tp <= gy - r - 23.5 &&
                    bt >= gy + r + 23.5;
                how =
                    'kept ${l.toStringAsFixed(0)}–${rr.toStringAsFixed(0)} across, ${tp.toStringAsFixed(0)}–${bt.toStringAsFixed(0)} down; its glass ${(gx - r).toStringAsFixed(0)}–${(gx + r).toStringAsFixed(0)} across, ${(gy - r).toStringAsFixed(0)}–${(gy + r).toStringAsFixed(0)} down';
              }
              all = all && ok;
              said.add(
                '${right ? 'right' : 'left'}: ${ok ? 'kept' : 'NOT kept'} ($how)',
              );
              // Its blobs in again.
              await t.lens(<String, Object?>{
                'op': 'menu',
                'what': 'outside',
                'settleMs': 700,
              });
              await Robot.wait(600);
            }
            t.check(safe, all, '${said.join('; ')}; navigation $nav');
          }
        }
        for (final double k in <double>[
          RestBubble.tuckMin,
          RestBubble.tuckMax,
        ]) {
          await lensOf.testPut(<String, Object>{'tuck': k}, show: 'tuck');
          await Robot.wait(1100);
          s = await where();
          t.check(
            'sidekick: tucked, ${k.round()} points showing',
            s['tucked'] == true && (showing(s) - k).abs() < 8,
            '${showing(s).toStringAsFixed(1)} points showing, tucked ${s['tucked']}',
          );
        }
        await lensOf.testPut(<String, Object>{
          'gap': gapWas,
          'tuck': tuckWas,
        }, show: wasTucked ? 'tuck' : 'rest');
        await Robot.wait(900);
        // Switched off in Prism: it goes, and its panel with it; switched off everywhere, Prism's
        // settings page offers to bring it back, which brings it back.
        if (await holdOpen('sidekick held, to switch it off')) {
          s = await panel('tap', part: 'inApp', settleMs: 1300);
          await Robot.wait(600);
          s = await where();
          t.check(
            'sidekick panel: "In Prism" off: kept by Android, the Sidekick goes, and so does the panel',
            kept(s)?['inApp'] == false &&
                !lensOf.floatIn.value &&
                s['lens'] != true &&
                s['panelOpen'] != true,
            'Android ${kept(s)?['inApp']}, shown ${s['lens']}, panel ${s['panelOpen']}',
          );
          lensOf.setFloating(overApps: false);
          await Robot.wait(600);
          if (mounted) {
            showPrismSettings(context);
          }
          await Robot.wait(1200);
          final BuildContext? line = Robot.key('bringBack').currentContext;
          if (line != null && line.mounted) {
            await Scrollable.ensureVisible(line, alignment: 0.5);
            await Robot.wait(500);
          }
          final Offset? bring = Robot.spot('bringBack');
          t.check(
            'settings page: off everywhere, "Bring back the Sidekick" is there',
            bring != null,
          );
          if (bring != null) {
            await seenTap('settings page: "Bring back"', bring, after: 1200);
          }
          s = await where();
          t.check(
            'settings page: "Bring back" brings it back, on everywhere',
            lensOf.floatIn.value &&
                lensOf.floatOut.value &&
                kept(s)?['inApp'] == true &&
                kept(s)?['overApps'] == true &&
                Robot.spot('bringBack') == null,
            'Android ${kept(s)?['inApp']}/${kept(s)?['overApps']}, the line ${Robot.spot('bringBack') == null ? 'gone' : 'still there'}',
          );
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            await Robot.wait(900);
          }
          lensOf.setFloating(inPrism: true, overApps: true);
          await t.lens(<String, Object?>{'op': 'side', 'on': true});
          await Robot.wait(1200);
        } else {
          t.skip(
            'sidekick panel: "In Prism" off: kept by Android, the Sidekick goes, and so does the panel',
            'its own settings did not come up',
          );
        }
        s = await where();
        t.check(
          'sidekick: its settings closed, it is back in sight, out at its place',
          s['lens'] == true && s['covered'] != true && s['panelOpen'] != true,
          'shown ${s['lens']}, hidden ${s['covered']}, panel ${s['panelOpen']}, tucked ${s['tucked']}',
        );
        clean('after the Sidekick\'s settings');
        // Moved first, then still: never the settings.
        final double sx = (s['x'] as num?)?.toDouble() ?? w / 2;
        s = await where();
        final Offset mid = Offset(
          (((s['x'] as num?)?.toDouble() ?? sx) +
                  ((s['size'] as num?)?.toDouble() ?? 0) / 2) /
              dpr,
          (((s['y'] as num?)?.toDouble() ?? h / 2) +
                  ((s['size'] as num?)?.toDouble() ?? 0) / 2) /
              dpr,
        );
        s = await press(
          'sidekick moved, then held still',
          <Offset>[mid - const Offset(70, 40)],
          legMs: 250,
          endMs: _holdMs + 500,
        );
        await Robot.wait(900);
        t.check(
          'sidekick: moved first and then held still, it is a move: no settings',
          !_panelOpen && s['lens'] == true,
        );
        // Let go low on the screen but away from the middle: it stays.
        s = await press(
          'sidekick let go low, at the side',
          <Offset>[Offset(sc.width * 0.18, sc.height * 0.8)],
          legMs: 600,
          endMs: 200,
        );
        await Robot.wait(900);
        s = await where();
        t.check(
          'sidekick: let go low at the side, it is not dismissed',
          s['lens'] == true && s['guest'] == true,
          'shown ${s['lens']}',
        );
        // From 193 the Sidekick has no cross: carried or flung anywhere, it only moves. It is sent
        // away only from its settings panel's "Dismiss". (Where its cross was in 190 to 192: the
        // top, in the middle.)
        final Offset topMiddle = Offset(sc.width / 2, 100);
        s = await press(
          'sidekick carried to the top middle',
          <Offset>[topMiddle],
          legMs: 700,
          endMs: 300,
          settleMs: 1500,
        );
        await Robot.wait(900);
        s = await where();
        t.check(
          'sidekick: carried to the top middle and let go, it only moves: it is still there',
          s['lens'] == true && s['guest'] == true,
          'shown ${s['lens']}',
        );
        t.check(
          'sidekick: carried to the top, the notification shade never comes down',
          s['prismFocus'] != false,
          'Prism has the focus ${s['prismFocus']}',
        );
        // A fast fling up, toward the top middle, from halfway down: it only moves.
        s = await press(
          'sidekick carried halfway down',
          <Offset>[Offset(sc.width * 0.85, sc.height * 0.55)],
          legMs: 600,
          endMs: 200,
          settleMs: 1200,
        );
        await Robot.wait(600);
        s = await where();
        final Offset flingFrom = Offset(
          (numOf(s['x']) + numOf(s['size']) / 2) / dpr,
          (numOf(s['y']) + numOf(s['size']) / 2) / dpr,
        );
        s = await press(
          'sidekick flung up',
          <Offset>[
            Offset(
              flingFrom.dx + (topMiddle.dx - flingFrom.dx) * 0.4,
              flingFrom.dy - 160,
            ),
          ],
          legMs: 120,
          flick: true,
          settleMs: 1500,
        );
        await Robot.wait(900);
        s = await where();
        t.check(
          'sidekick: flung up fast toward the top middle, it only moves: it is still there',
          s['lens'] == true && s['guest'] == true && s['prismFocus'] != false,
          'shown ${s['lens']}, Prism has the focus ${s['prismFocus']}, flung from ${flingFrom.dx.round()},${flingFrom.dy.round()}',
        );
        // Held: its panel, and "Hold to dismiss" under the Sidekick (196), held to the end (195):
        // the panel closes and the Sidekick is sent away, until it is brought back (the next app
        // opened from Prism, or here the test's own bring-back). Let go, slid off or only tapped
        // before the end: nothing.
        {
          const List<String> holds = <String>[
            'sidekick: "Hold to dismiss" pressed: the fill sweeps across it, and it says "Keep holding…", still where it should be',
            'sidekick: "Hold to dismiss" pressed for 0.6 s and let go: nothing happens, and the fill drains back within 0.5 s',
            'sidekick: "Hold to dismiss" slid off at 0.8 s: nothing happens, and the fill drains back',
            'sidekick: a tap on "Hold to dismiss" does nothing, and it still says so',
            'sidekick: "Hold to dismiss" held for 1.3 s: "Dismissed", with a light tick at 25, 50 and 75% and a heavy one at 100%',
            'sidekick: held, its panel\'s "Hold to dismiss" held to the end sends it away, and the panel closes',
          ];
          final int was = numOf(s['sidekickDismissals']).isNaN
              ? 0
              : numOf(s['sidekickDismissals']).toInt();
          String fillSaid(Map<String, Object?> m) =>
              'panel open ${m['panelOpen']}, sent away ${m['sideGone']}; most filled ${(numOf(m['holdMost']) * 100).toStringAsFixed(0)}%, ended "${m['holdEnded']}", fill now ${(numOf(m['holdFill']) * 100).toStringAsFixed(1)}%, at 0.5 s ${(numOf(m['holdAt500']) * 100).toStringAsFixed(1)}%, drained in ${m['holdDrainMs']} ms; haptics ${m['holdBuzzes']}; "${m['holdLabel']}"';
          if (await holdOpen('sidekick held, to dismiss it')) {
            // Pressed 0.6 s: read halfway through, while it is held; then after the let-go.
            // ("Drained" is under 3% at 0.5 s: the owner's spring, k 90 and c 19, takes about
            // 0.6 s to go from half to under 1%.)
            Map<String, Object?> m = await panel(
              'press',
              part: 'close.dismiss',
              holdMs: 600,
            );
            // (Where it should be while held: it shakes a little, but its place is the same.)
            final (bool placedHeld, String saidHeld) = pillOk(<String, Object?>{
              ...m,
              'holdLabel': 'Hold to dismiss',
            });
            t.check(
              holds[0],
              m['holdHeld'] == true &&
                  numOf(m['holdFill']) > 0.1 &&
                  m['holdLabel'] == 'Keep holding…' &&
                  placedHeld,
              'held ${m['holdHeld']}, fill ${(numOf(m['holdFill']) * 100).toStringAsFixed(0)}%, it says "${m['holdLabel']}"; $saidHeld',
            );
            await Robot.wait(1000);
            m = await where();
            t.check(
              holds[1],
              m['panelOpen'] == true &&
                  m['holdDone'] != true &&
                  m['sideGone'] != true &&
                  numOf(m['holdMost']) >= 0.4 &&
                  numOf(m['holdMost']) < 0.75 &&
                  m['holdEnded'] == 'let go' &&
                  numOf(m['holdAt500']) >= 0 &&
                  numOf(m['holdAt500']) <= 0.03 &&
                  numOf(m['holdFill']) == 0 &&
                  !'${m['holdBuzzes']}'.contains('heavy'),
              fillSaid(m),
            );
            // Held 0.8 s, then slid off sideways, toward the middle of the screen, and let go there.
            final bool pillRight =
                (m['pill'] is Map) &&
                (m['pill']! as Map<Object?, Object?>)['onRight'] == true;
            m = await panel(
              'holdSlide',
              part: 'close.dismiss',
              holdMs: 800,
              dx: pillRight ? -180 : 180,
              legMs: 120,
              settleMs: 1000,
            );
            t.check(
              holds[2],
              m['panelOpen'] == true &&
                  m['holdDone'] != true &&
                  m['sideGone'] != true &&
                  m['holdEnded'] == 'slid off' &&
                  numOf(m['holdMost']) >= 0.6 &&
                  numOf(m['holdMost']) < 0.9 &&
                  numOf(m['holdFill']) == 0,
              fillSaid(m),
            );
            m = await panel('tap', part: 'close.dismiss', settleMs: 900);
            t.check(
              holds[3],
              m['panelOpen'] == true &&
                  m['holdDone'] != true &&
                  m['sideGone'] != true &&
                  numOf(m['holdFill']) == 0 &&
                  m['holdLabel'] == 'Hold to dismiss',
              fillSaid(m),
            );
            // Held 1.3 s: read just after the lift, while the panel is still up with "Dismissed".
            m = await panel(
              'hold',
              part: 'close.dismiss',
              holdMs: 1300,
              settleMs: 30,
            );
            final List<String> buzzes = <String>[
              for (final Object? b
                  in (m['holdBuzzes'] as List<Object?>?) ?? const <Object?>[])
                '$b',
            ];
            t.check(
              holds[4],
              m['holdDone'] == true &&
                  m['holdLabel'] == 'Dismissed' &&
                  buzzes.join(', ') ==
                      'light at 25%, light at 50%, light at 75%, heavy at 100%',
              fillSaid(m),
            );
            await Robot.wait(1500);
            s = await where();
            t.check(
              holds[5],
              s['lens'] != true &&
                  s['panelOpen'] != true &&
                  s['sideGone'] == true &&
                  numOf(s['sidekickDismissals']) == was + 1,
              'shown ${s['lens']}, panel ${s['panelOpen']}, sent away ${s['sideGone']}, from its panel ${numOf(s['sidekickDismissals']).isNaN ? '?' : numOf(s['sidekickDismissals']).toInt() - was} time(s)',
            );
            await t.lens(<String, Object?>{'op': 'side', 'on': true});
            await Robot.wait(1200);
            s = await where();
            t.check(
              'sidekick: sent away from its panel, it comes back when brought back',
              s['lens'] == true && s['guest'] == true,
              'shown ${s['lens']}',
            );
          } else {
            skip(holds, 'its panel did not open');
          }
        }
        // An emptied Sidekick menu: one plus. Then the person's own menu, back as it was.
        final List<String>? back = sideWere;
        if (back != null) {
          await t.lens(<String, Object?>{
            'op': 'sidekick',
            'keys': List<String>.filled(_n, 'empty:'),
          });
          s = await where();
          t.check(
            'sidekick: with nothing in its menu, it holds one plus',
            s['blobs'] == 1 && '${s['sideKeys']}'.startsWith('empty:'),
            '${s['blobs']} blobs: ${s['sideKeys']}',
          );
          await t.lens(<String, Object?>{'op': 'sidekick', 'keys': back});
          await Robot.wait(600);
          s = await where();
          t.check(
            'sidekick: its own menu is back as it was before the test',
            stored(s).join(' ') == back.join(' '),
            'its menu ${stored(s).join(' ')} (was ${back.join(' ')})',
          );
        }
        t.check(
          'sidekick: Prism\'s menu is the same after all of it',
          keys().join(' ') == mainBefore.join(' '),
          'Prism ${keys().join(' ')} (was ${mainBefore.join(' ')})',
        );
        clean('after the Sidekick');

        // ------------------------------------------------ everything at once
        say('6 of 6, everything in a row');
        await memoryAt('part 6 of 6');
        await t.scene('a bit of everything, quickly', () async {
          await Robot.tap(_home, after: 300);
          await Robot.hold(seat(2), ms: _holdMs + 200, after: 300);
          await Robot.tap(beside, after: 300);
          await Robot.tap(_home, after: 300);
          await holdButton(extra: 150);
          await Robot.tap(_home, after: 300);
          await Robot.drag(
            <Offset>[_home, _home - const Offset(0, 320)],
            legMs: 110,
            flick: true,
            after: 500,
          );
          await Robot.tap(_home, after: 600);
        });
        await Robot.wait(900);
        clean('after everything in a row');
        signIs('after everything in a row, at rest, up', down: false);
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
      if (buttons) {
        // Past reports (183), in a folder of the test's own, so the owner's list is not touched:
        // one kept and read back as Prism would after a restart (a new reader, from storage),
        // byte for byte; then more than can be kept, and only the newest 20 are left.
        final Directory tmp = Directory(
          '${Directory.systemTemp.path}/prism_reports_test_${DateTime.now().microsecondsSinceEpoch}',
        );
        try {
          const String title = 'button test (Prism and the Sidekick)';
          const String sample =
              'Prism build 183  ·  button test\r\nCHECKS: 605 right, 12 wrong, of 617\n½ · “quotes” · 🙂\n\n';
          final DateTime at = DateTime(2026, 11, 16, 12, 33);
          PastReports(tmp).save(title, sample, at: at);
          final List<PastReport> back = PastReports(tmp).list();
          final String read = back.isEmpty ? '' : back.first.text();
          t.check(
            'past reports: one kept is read back after a restart, byte for byte',
            back.length == 1 &&
                _sameBytes(utf8.encode(read), utf8.encode(sample)) &&
                back.first.title == title &&
                back.first.name == 'Button test' &&
                back.first.when == at &&
                back.first.build(read) == '183' &&
                back.first.result(read) == '605 right, 12 wrong',
            back.isEmpty
                ? 'nothing read back'
                : '${utf8.encode(read).length} bytes back of ${utf8.encode(sample).length}; "${back.first.name}", build ${back.first.build(read)}, "${back.first.result(read)}", ${back.first.when}',
          );
          for (int k = 1; k <= PastReports.keep + 2; k++) {
            PastReports(tmp).save(
              'leak test',
              'Prism build 183  ·  leak test $k',
              at: at.add(Duration(minutes: k)),
            );
          }
          final List<PastReport> kept = PastReports(tmp).list();
          t.check(
            'past reports: only the newest 20 are kept, newest first',
            kept.length == PastReports.keep &&
                kept.first.text().endsWith(
                  'leak test ${PastReports.keep + 2}',
                ) &&
                kept.last.text().endsWith('leak test 3'),
            '${kept.length} kept, newest "${kept.isEmpty ? '' : kept.first.text()}", oldest "${kept.isEmpty ? '' : kept.last.text()}"',
          );
        } catch (e) {
          t.check(
            'past reports: one kept is read back after a restart, byte for byte',
            false,
            '$e',
          );
        } finally {
          try {
            tmp.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
      if (buttons) {
        signPath.clear();
        _signTaps.clear();
        _signTurn.addListener(signFrame);
      }
      roundsTook.start();
      for (int n = 1; n <= rounds; n++) {
        lap = rounds > 1 ? ', round $n of $rounds' : '';
        roundNow = n;
        try {
          t.roundStart();
          await (buttons ? buttonRound() : round());
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
      roundNow = rounds + 1;

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
                    for (final Rect c in cards.take(3)) _fingerFor(c.center),
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
      } else if (leak) {
        // ------------------------------------------------------------ the leak test
        // Native memory grew in steps, round after round, wherever the button test changed
        // Prism's settings panel, and none of the caches counted grew with it. Here each of a
        // few everyday steps is done twenty times over, with memory read before and after every
        // five: a step that keeps something each time shows a slope; one that doesn't, a flat line.
        Future<void> reading(String step, int done) async {
          final Map<String, Object?> m = await t.lens(<String, Object?>{
            'op': 'memory',
            'gc': true,
          });
          t.leakRows.add((
            step,
            done,
            <String, Object?>{
              if (m['ok'] != false) ...m,
              'rssKb': ProcessInfo.currentRss ~/ 1024,
              'frames': t.framesCounted,
            },
          ));
        }

        Future<void> ensureClosed() async {
          if (_drawerOpen) {
            _setDrawer(false);
            await Robot.wait(800);
          }
          if (_panelOpen && Robot.spot('floatClose') != null) {
            await closePanel();
          }
          if (_open) {
            _setOpen(false);
            await Robot.wait(700);
          }
        }

        // One step: [before] once, then [once] twenty times with a reading every five, then [after].
        final List<
          (
            String,
            Future<void> Function()?,
            Future<void> Function(),
            Future<void> Function()?,
          )
        >
        steps =
            <
              (
                String,
                Future<void> Function()?,
                Future<void> Function(),
                Future<void> Function()?,
              )
            >[];
        final Stopwatch leakClock = Stopwatch()..start();
        Future<void> run(int k, int of) async {
          final (
            String name,
            Future<void> Function()? before,
            Future<void> Function() once,
            Future<void> Function()? after,
          ) = steps[k];
          say('leak test, ${k + 1} of $of: $name');
          final int took = leakClock.elapsed.inSeconds;
          Diag.instance.progress.value = (
            'Leak test  ·  step ${k + 1} of $of  ·  ${k == 0 || took < 20 ? 'working out how long' : 'about ${math.max(1, (took * (of - k) / k / 60).ceil())} min left'}',
            k / of,
          );
          await ensureClosed();
          await before?.call();
          await Robot.wait(600);
          await reading(name, 0);
          for (int n = 1; n <= 20; n++) {
            await once();
            if (n % 5 == 0) {
              await reading(name, n);
            }
          }
          await after?.call();
          await ensureClosed();
        }

        Future<void> labels() async {
          final Offset? n = Robot.spot('names');
          if (n != null) {
            await Robot.tap(n + const Offset(88, 0), after: 500);
            await Robot.tap(
              (Robot.spot('names') ?? n) - const Offset(88, 0),
              after: 500,
            );
          }
        }

        Future<void> noSidekick() async {
          lensOf.setFloating(inPrism: false, overApps: false);
          await Robot.wait(800);
          await holdButton();
        }

        Future<void> sidekickBack() async {
          await closePanel();
          lensOf.setFloating(inPrism: true, overApps: true);
          await Robot.wait(800);
        }

        // A short text under the banner, drawn for 30 frames at a weight it was never drawn at
        // before ([old]: exactly as a moving weight was drawn before build 175), or in Prism's
        // steps of 10 (as now).
        int probed = 0;
        Future<void> probe(bool old) async {
          for (int f = 0; f < 30; f++) {
            probed++;
            Diag.instance.probe.value = (500 + (probed * 0.731) % 150, old);
            WidgetsBinding.instance.scheduleFrame();
            await Future.any(<Future<void>>[
              WidgetsBinding.instance.endOfFrame,
              Future<void>.delayed(const Duration(milliseconds: 100)),
            ]);
          }
          Diag.instance.probe.value = null;
          await Robot.wait(300);
        }

        // Open the settings with one part left out, and put it back once closed.
        Future<void> Function() without(void Function(bool) part) => () async {
          part(true);
          await Robot.wait(300);
          await holdButton();
        };
        Future<void> Function() back(void Function(bool) part) => () async {
          await closePanel();
          part(false);
          await Robot.wait(300);
        };
        void sends(bool off) => _leakNoSends = off;
        void looks(bool off) => setState(() => _leakNoLooks = off);
        void jump(bool on) => Segmented.testJump = on;

        steps.addAll(<
          (
            String,
            Future<void> Function()?,
            Future<void> Function(),
            Future<void> Function()?,
          )
        >[
          (
            'a. Prism\'s settings opened and closed',
            null,
            () async {
              await holdButton();
              await closePanel();
            },
            null,
          ),
          (
            'b. Labels Hide and Show, in the settings',
            holdButton,
            labels,
            closePanel,
          ),
          (
            'g. Home to Train and back, by the tab bar',
            null,
            () async {
              _go(1);
              await Robot.wait(700);
              _go(0);
              await Robot.wait(700);
            },
            null,
          ),
          (
            'h. a new weight 30 times, as before 175',
            null,
            () => probe(true),
            null,
          ),
          (
            'h, the same in steps of 10, as now',
            null,
            () => probe(false),
            null,
          ),
          (
            'i. Labels Hide and Show, the settings closed',
            null,
            () async {
              _setNames(!BlobSlots.instance.names);
              await Robot.wait(500);
              _setNames(!BlobSlots.instance.names);
              await Robot.wait(500);
            },
            null,
          ),
          (
            'ii. the settings rebuilt twice, nothing changed',
            holdButton,
            () async {
              _leakBump.value++;
              await Robot.wait(500);
              _leakBump.value++;
              await Robot.wait(500);
            },
            closePanel,
          ),
          (
            'iii. b, without Prism\'s messages to Android',
            without(sends),
            labels,
            back(sends),
          ),
          (
            'v. b, the six look previews as empty boxes',
            without(looks),
            labels,
            back(looks),
          ),
          (
            'vi. b, the pickers jumping instead of moving',
            without(jump),
            labels,
            back(jump),
          ),
          ('b, the Sidekick switched off', noSidekick, labels, sidekickBack),
        ]);
        for (int k = 0; k < steps.length; k++) {
          await run(k, steps.length);
        }
        Diag.instance.progress.value = ('Leak test  ·  done', 1);
      } else if (buttons) {
        _signTurn.removeListener(signFrame);
        if (BlobSign.of(Apps.instance.blobLook).turns || signPath.isNotEmpty) {
          // Every tap on Prism's button in the whole test: the triangle pointed down exactly when
          // the tap left nothing open.
          final List<(String, bool, bool)> off = <(String, bool, bool)>[
            for (final (String, bool, bool) x in _signTaps)
              if (x.$2 != x.$3) x,
          ];
          t.check(
            'triangle: at every tap on Prism\'s button in the test, it pointed down exactly when the tap left nothing open',
            _signTaps.isNotEmpty && off.isEmpty,
            '${_signTaps.length} taps${off.isEmpty ? '' : '; wrong: ${off.map(((String, bool, bool) x) => '${x.$1} (pointed ${x.$2 ? 'down' : 'up'}, ${x.$3 ? 'nothing' : 'something'} open after)').join(', ')}'}',
          );
          // Every frame of the whole test: never back, never past.
          final String? wrong = signWrong(signPath);
          t.check(
            'triangle: every frame of the test, it never turned back or past where it was going',
            wrong == null,
            wrong ?? '${signPath.length} frames',
          );
          // No single turn of more than a third of a turn: past that, it would show the way it
          // ends up pointing before it gets there.
          double most = 0;
          for (final List<(int, double, double)> st in stretches(signPath)) {
            for (int i = 1; i < st.length; i++) {
              most = math.max(most, st[i].$3 - st[i - 1].$3);
            }
          }
          t.check(
            'triangle: no single turn of more than 120°',
            most <= 120.1 * degree,
            'the largest turn ${(most / degree).toStringAsFixed(0)}°',
          );
          // How far one frame turned it at most (only a phone's frames mean anything).
          if (Platform.isAndroid) {
            double step = 0;
            for (final List<(int, double, double)> st in stretches(signPath)) {
              for (int i = 1; i < st.length; i++) {
                step = math.max(step, (st[i].$2 - st[i - 1].$2).abs());
              }
            }
            t.note(
              'the triangle turned at most ${(step / degree).toStringAsFixed(1)}° in one frame',
            );
          } else {
            t.skip(
              'triangle: the largest turn in one frame',
              'the preview draws a frame only every 120 to 150 ms, so it means nothing here',
            );
          }
        }
        // ---------------------------------------------------------- the glass, measured (184)
        // Colourful things scroll behind the bar at a steady pace, about 30 s for each level of
        // glass; then the magnifying glass alone, carried about at full quality. Today's styles
        // stand in for the three levels (no other way of drawing the bar exists yet):
        // Frosted ≈ "Event" (still glass, a tint over what is behind, nothing blurred),
        // Clear ≈ "Frosted" (a live blur at low quality: no bending, no edges),
        // Liquid ≈ "Original" (a live blur, bending at the edges, the rim).
        say('the glass, measured');
        final int modeWas = Diag.instance.glassMode.value;
        final GlassQuality qualityWas = settings.quality;
        if (_drawerOpen) {
          _setDrawer(false);
        }
        if (_open) {
          _setOpen(false);
        }
        _go(0);
        await Robot.wait(800);
        double num0(Map<String, Object?> m, String k) =>
            (m[k] as num?)?.toDouble() ?? double.nan;
        Future<void> measureGlass(
          String label,
          Future<void> Function() moving,
        ) async {
          await calm();
          final Map<String, Object?> s0 = await t.lens(<String, Object?>{
            'op': 'state',
          });
          final int at0 = t.clock.elapsedMilliseconds;
          await t.scene('glass level $label: moving', moving);
          final Map<String, Object?> s1 = await t.lens(<String, Object?>{
            'op': 'state',
          });
          final Map<String, Object?> mem = await t.lens(<String, Object?>{
            'op': 'memory',
          });
          t.glassLevels.add((
            label,
            <String, double>{
              'ms': (t.clock.elapsedMilliseconds - at0).toDouble(),
              'cpu': num0(s1, 'cpu') - num0(s0, 'cpu'),
              'graphics': num0(mem, 'mem_graphics') / 1024,
              'battery': num0(s0, 'level') - num0(s1, 'level'),
              'charge': (num0(s0, 'chargeUah') - num0(s1, 'chargeUah')) / 1000,
              'plugged': s0['plugged'] == true || s1['plugged'] == true ? 1 : 0,
            },
          ));
        }

        Future<void> scrollFor(int seconds) async {
          final Offset mid = Offset(sc.width / 2, sc.height * 0.5);
          final Stopwatch w = Stopwatch()..start();
          bool up = true;
          while (w.elapsed.inSeconds < seconds) {
            await Robot.drag(
              up
                  ? <Offset>[
                      mid + const Offset(0, 200),
                      mid - const Offset(0, 200),
                    ]
                  : <Offset>[
                      mid - const Offset(0, 200),
                      mid + const Offset(0, 200),
                    ],
              legMs: 1200,
              after: 50,
            );
            up = !up;
          }
        }

        for (final (String label, int mode) in <(String, int)>[
          ('Frosted (today\'s Event)', 3),
          ('Clear (today\'s Frosted)', 2),
          ('Liquid (today\'s Original)', 0),
        ]) {
          Diag.instance.glassMode.value = mode;
          settings.quality = GlassQuality.full;
          await Robot.wait(1500);
          await measureGlass(label, () => scrollFor(30));
        }
        // The magnifying glass alone, carried about, at full quality. (Today it follows the
        // glass quality setting: the owner's rule that it is always at full quality is not in
        // the code yet, so the test sets Full for it.)
        Diag.instance.glassMode.value = 0;
        settings.quality = GlassQuality.full;
        await Robot.wait(1000);
        await measureGlass(
          'the magnifying glass, carried, full quality',
          () => Robot.drag(
            <Offset>[
              _home,
              for (int k = 0; k < 12; k++)
                Offset(
                  sc.width * (k.isEven ? 0.25 : 0.75),
                  sc.height * (0.2 + 0.05 * k),
                ),
              Offset(sc.width / 2, top + 60),
            ],
            legMs: 1500,
            after: 1000,
          ),
        );
        if (_carrying || _parked) {
          _lensHome();
        }
        Diag.instance.glassMode.value = modeWas;
        settings.quality = qualityWas;
        await Robot.wait(1000);
        // A little while of nothing being touched, to see that the buttons leave nothing running.
        say('sitting still for a minute');
        await t.phase('Home, nothing open, after the button test', 60);
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
          '${Diag.build}  ·  $title${drain || leak ? '' : ', $rounds round${rounds == 1 ? '' : 's'}'}  ·  ${DateTime.now().toString().substring(0, 16)}${begun['model'] == null ? '' : '\n${begun['model']}  ·  chip ${begun['soc']}  ·  Android ${begun['android']}  ·  ${(begun['hz'] as num?)?.round() ?? '?'} Hz  ·  ${begun['ramGb']} GB memory  ·  battery about ${begun['battMah']} mAh when full'}\nscreen ${w.round()}x${h.round()} at ${dp}x  ·  navigation: ${begun['nav'] ?? last['nav'] ?? '?'}  ·  allowed over other apps: ${floats ? 'yes' : 'NO'}  ·  ${last['blobs']} blobs known to Android';
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
      // (The leak test's parts left out, all back; its text that changes weight, gone.)
      _leakNoSends = _leakNoLooks = false;
      Segmented.testJump = false;
      Diag.instance.probe.value = null;
      Diag.instance.typing.unfocus();
      Diag.instance.typingShown.value = false;
      lensOf.setPin(pinWas);
      _sendPin();
      final List<String>? sideBack = sideWere;
      if (sideBack != null) {
        await t.lens(<String, Object?>{'op': 'sidekick', 'keys': sideBack});
      }
      if (_tab != 0) {
        _go(0);
      }
      final Map<String, Object?> ended = await t.lens(<String, Object?>{
        'op': 'end',
      });
      Haptics.enabled = hapticsWere;
      t.close();
      Diag.instance.banner.value = null;
      Diag.instance.progress.value = null;
      _testing = false;
      final String text = t.report(<String>[
        ...build.split('\n'),
        ...settingsWere,
        if (adjusted.isNotEmpty)
          'SET FOR THE TEST, and put back afterwards: ${adjusted.join('  ·  ')}',
        if (stoppedAt != null)
          'STOPPED BY YOU while it was at: $stoppedAt (what follows is as far as it got)',
        // Which of Prism's engines ran the test, and where Android's line to Prism led. (There
        // should be one engine; build 171's phone run looked like two.)
        if (ended['engineHere'] != null) ...<String>[
          'PRISM\'S ENGINES: ${ended['enginesMade']} made since Prism started, ${ended['enginesAlive']} alive at the end; the test ran in #${ended['engineHere']}; Android\'s line to Prism led to #${ended['engineLine']} at the end',
          for (final Object? e
              in (ended['engineHistory'] as List<Object?>?) ??
                  const <Object?>[])
            '  $e',
        ],
      ]);
      // Kept among the past reports first of all: a crash from here on still leaves it.
      PastReports.instance.save(title, text);
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
                        // Kept with the note, so "Copy the last report" has it too, and
                        // the past report that was just kept.
                        TestRun.keep(text);
                        PastReports.instance.update(text);
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
      _ly.jumpTo(_ly.value + _lensRide);
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
    _ly.animateTo(at.dy - _lensRide);
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
      // (As little as the Sidekick allows: past this it is a movement, and never a hold.)
      if (travel.distance < 8) {
        return;
      }
      _moved = true;
      _movedAt = _held.elapsedMilliseconds;
      _holdTimer?.cancel();
      // (A flick, a carry or a nudge: not known yet. The sign waits for the finger to lift.)
      _signHeld = true;
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
              (!upward && travel.distance > 16) ||
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
      (e.position.dy - _lensRide).clamp(
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
    _buttonLet();
    // (The gesture is decided and done: the sign shows what a tap would do now.)
    if (_signHeld) {
      _signHeld = false;
      _signSync();
    }
  }

  void _buttonLet() {
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
      final TapOutcome o = _tapOutcome();
      final bool turns = BlobSign.of(Apps.instance.blobLook).turns;
      final bool down = _pointsDown(_signTurn.target);
      _setDrawer(false);
      if (turns && !_moved && !_lifted && _signTaps.length < 400) {
        _signTaps.add((o.name, down, _nothingOpen()));
      }
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
    } else if (!_lifted) {
      // A tap, or a small nudge that was neither a flick nor a carry: what [_tapOutcome] says.
      // (While the blobs are being changed, Prism's settings; with the magnifying glass put
      // down somewhere, it is called home; otherwise the blobs come out or go in.)
      final TapOutcome o = _tapOutcome();
      final bool turns = BlobSign.of(Apps.instance.blobLook).turns;
      final bool down = _pointsDown(_signTurn.target);
      _doTap(o);
      if (turns && _signTaps.length < 400) {
        _signTaps.add((o.name, down, _nothingOpen()));
      }
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
    // Up to change a blob: the button becomes that blob for as long as it is being chosen.
    // (The Sidekick's too, while choosing for it.)
    if (v && _editSlot != null && !_isSwipe(_editSlot!)) {
      _faceOf = _blobDisc(_editSlot!);
      _face.animateTo(1);
    } else {
      _face.animateTo(0);
    }
    // The drawer may have been up to choose what takes a blob's place.
    final bool choosing = !v && _editSlot != null;
    final bool swipe = choosing && _isSwipe(_editSlot!);
    // Up only to choose for the Sidekick: nothing of Prism's own menu is touched.
    final bool side = choosing && _editSlot == _sideSlot;
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
    if (choosing && !swipe && !side) {
      // (A place made for "Add" and left empty: the empty ones go last again.)
      _rearrange(_packed());
    }
    if (choosing) {
      final bool back = _pickBack;
      _pickBack = false;
      _sideAsk = null;
      if (back) {
        // Prism came forward only for this: back to the app you were in.
        const MethodChannel('lumen/device')
            .invokeMethod<void>('toBack')
            .catchError((Object _) {});
      } else if (swipe) {
        // A two-finger swipe was being set, from Prism's settings: back to them.
        _showFloating();
      } else if (!side) {
        // Chosen or not, the blobs come back out, showing what is there now. (Not after
        // choosing for the Sidekick: Prism's own blobs stay as they were, in.)
        _setOpen(true);
      }
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
      (at.dy - _lensRide).clamp(
        _lensSize / 2 + 30,
        screen.height - _lensSize / 2,
      ),
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
    _leakBump.dispose();
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
      _menuFor = null;
      _spaceAt = null;
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
        _gone[i].jumpTo(0);
        if (_floating(i)) {
          continue;
        }
        if (i == join) {
          // Just given something: it is already in its seat, where the plus was.
          _out[i].jumpTo(1);
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
    if (_isPhone(i)) {
      // Not an app, a sheet or a page: the side Blob comes out, or the notifications down.
      _setOpen(false);
      if (_isSide(i)) {
        _bringSide();
      } else {
        Haptics.settle();
        GestureSlots.shade();
      }
      return;
    }
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
                              // Never past the bar's own ends: grown or stretched, it would lie over
                              // the bar's rim there and bend it, which read as the rim breaking.
                              final double inset = 4;
                              final double lw = math.min(w, _barW - 2 * inset);
                              final Rect lens = Rect.fromCenter(
                                center: Offset(
                                  _lensX.value.clamp(
                                    inset + lw / 2,
                                    math.max(
                                      inset + lw / 2,
                                      _barW - inset - lw / 2,
                                    ),
                                  ),
                                  _barH / 2,
                                ),
                                width: lw,
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
                    // Held still on the empty space: its small menu (Edit Prism, Add Blob).
                    child: RawGestureDetector(
                      gestures: <Type, GestureRecognizerFactory>{
                        LongPressGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                              LongPressGestureRecognizer
                            >(
                              () => LongPressGestureRecognizer(
                                duration: Duration(milliseconds: _holdMs),
                              ),
                              (LongPressGestureRecognizer r) => r
                                ..onLongPressStart = (
                                  LongPressStartDetails d,
                                ) => _heldSpace(d.globalPosition),
                            ),
                      },
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
                    // Taking it away, from the same place it is changed.
                    onRemove:
                        _editSlot != null &&
                            (_isSwipe(_editSlot!)
                                ? GestureSlots.instance.keys[_editSlot! -
                                          100] !=
                                      'empty:'
                                : !_isEmpty(_editSlot!))
                        ? () {
                            final int i = _editSlot!;
                            if (i == _sideSlot) {
                              // The Sidekick's blob: Android takes it out of its menu.
                              Haptics.thud();
                              _sideChosen('empty:');
                            } else if (_isSwipe(i)) {
                              Haptics.thud();
                              Diag.instance.event(
                                'gesture ${GestureSlots.names[i - 100]} cleared',
                              );
                              GestureSlots.instance.put(i - 100, 'empty:');
                            } else {
                              _removeBlob(i);
                            }
                            _setDrawer(false);
                          }
                        : null,
                    pickTitle: _editSlot != null && _isSwipe(_editSlot!)
                        ? (
                            'Swipe ${GestureSlots.names[_editSlot! - 100]}',
                            'with two fingers',
                          )
                        : null,
                    choices: <(String, String, IconData, Color)>[
                      // The button test, first, while choosing for a blob: chosen, it runs and
                      // nothing is put in the place.
                      if (_editSlot != null &&
                          !_isSwipe(_editSlot!) &&
                          !_testing)
                        (
                          'test:buttons',
                          'Button test',
                          Icons.science_rounded,
                          const Color(0xFF2E3440),
                        ),
                      // A swipe can also pull the phone's notifications down.
                      if (_editSlot != null && _isSwipe(_editSlot!))
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
                      // Bringing out the side Blob: for a swipe, or for a place in the menu.
                      // (After Prism's own actions, which are used most.)
                      (
                        'phone:side',
                        'Sidekick',
                        Icons.bubble_chart_rounded,
                        const Color(0xFF5A6373),
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
                      if (empty && !(i == 0 && _allEmpty)) {
                        // An empty place is not shown: the others stand together in the middle.
                        return const SizedBox.shrink();
                      }
                      if (empty) {
                        // Nothing in the menu at all: one plus, in the middle, to add a blob.
                        if (p <= 0.001) {
                          return const SizedBox.shrink();
                        }
                        final Offset m = bc + (rest(i) - bc) * p;
                        return Positioned(
                          left: m.dx - _blob / 2 - 6,
                          top: m.dy - _blob / 2 - 6,
                          child: IgnorePointer(
                            ignoring: !_open,
                            child: Opacity(
                              opacity: (p * 12).clamp(0.0, 1.0) * 0.85,
                              child: GestureDetector(
                                key: Robot.key('plus$i'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _pickFor(i),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: _blobDisc(i),
                                ),
                              ),
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
                            opacity:
                                (p * 12).clamp(0.0, 1.0) *
                                (_menuFor != null && _menuFor != i ? 0.3 : 1),
                            // Held still: this blob is changed, straight away, after the same
                            // wait as on the Sidekick. Moved first, it is a drag and never a hold.
                            child: RawGestureDetector(
                              gestures: <Type, GestureRecognizerFactory>{
                                LongPressGestureRecognizer:
                                    GestureRecognizerFactoryWithHandlers<
                                      LongPressGestureRecognizer
                                    >(
                                      () => LongPressGestureRecognizer(
                                        duration: Duration(
                                          milliseconds: _holdMs,
                                        ),
                                      ),
                                      (LongPressGestureRecognizer r) => r
                                        ..onLongPressStart =
                                            (LongPressStartDetails d) {
                                              _holdFrom = d.globalPosition;
                                              _heldBlob(i);
                                            }
                                        // Held and then moved without letting go: the menu
                                        // goes, and the blob comes along, as on any drag.
                                        ..onLongPressMoveUpdate =
                                            (LongPressMoveUpdateDetails d) {
                                              if (_dragI != i) {
                                                if (_menuFor != i ||
                                                    (d.globalPosition -
                                                                _holdFrom)
                                                            .distance <
                                                        12) {
                                                  return;
                                                }
                                                _menuAway();
                                                grab(i, d.globalPosition);
                                              }
                                              _blobDrag(
                                                i,
                                                d.globalPosition - _dragGrab,
                                                bc,
                                              );
                                            }
                                        ..onLongPressEnd =
                                            (LongPressEndDetails d) {
                                              if (_dragI == i) {
                                                _blobDrop(
                                                  i,
                                                  bc,
                                                  d.velocity.pixelsPerSecond,
                                                );
                                              }
                                            },
                                    ),
                              },
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
                                // Dragged. While the blobs are being changed that only puts them
                                // in another order.
                                onPanStart: (DragStartDetails d) =>
                                    grab(i, d.globalPosition),
                                onPanUpdate: (DragUpdateDetails d) => _blobDrag(
                                  i,
                                  d.globalPosition - _dragGrab,
                                  bc,
                                ),
                                onPanEnd: (DragEndDetails d) => _blobDrop(
                                  i,
                                  bc,
                                  d.velocity.pixelsPerSecond,
                                ),
                                onPanCancel: () =>
                                    _blobDrop(i, bc, Offset.zero),
                                child: Column(
                                  children: <Widget>[
                                    const SizedBox(height: 8),
                                    Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.rotationZ(ang)
                                        ..scaleByDouble(
                                          s *
                                              back *
                                              (1 + st) *
                                              (held || _menuFor == i
                                                  ? 1.08
                                                  : 1),
                                          s *
                                              back *
                                              (1 - st * 0.5) *
                                              (held || _menuFor == i
                                                  ? 1.08
                                                  : 1),
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
                                                      icon:
                                                          Icons.remove_rounded,
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
                        ),
                      );
                    },
                  ),
                // The empty space held: its small menu, above the finger.
                if (_spaceAt != null && _open) ...<Widget>[
                  Positioned.fill(
                    child: GestureDetector(
                      key: Robot.key('spaceAway'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _spaceAway,
                    ),
                  ),
                  Builder(
                    builder: (BuildContext context) {
                      final int parts = 1 + (_room ? 1 : 0);
                      final double width = 30.0 + parts * 118;
                      return Positioned(
                        left: (_spaceAt!.dx - width / 2).clamp(
                          10.0,
                          screen.width - width - 10,
                        ),
                        top: (_spaceAt!.dy - 82).clamp(
                          safe.top + 10,
                          screen.height,
                        ),
                        width: width,
                        height: 50,
                        child: _PillMenu(
                          items: <(String, Color, VoidCallback, String)>[
                            (
                              'Edit Prism',
                              Colors.white,
                              _spaceEdit,
                              'spaceEdit',
                            ),
                            if (_room)
                              (
                                'Add Blob',
                                const Color(0xFF4CD48A),
                                _spaceAdd,
                                'spaceAdd',
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                // A held blob's small menu: Change and Remove, beside it. A tap anywhere else
                // puts it away and leaves the blobs out.
                if (_menuFor != null && _open) ...<Widget>[
                  Positioned.fill(
                    child: GestureDetector(
                      key: Robot.key('menuAway'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _menuAway,
                    ),
                  ),
                  Positioned(
                    left: (rest(_menuFor!).dx - (_room ? 150 : 104)).clamp(
                      10.0,
                      screen.width - (_room ? 310 : 218),
                    ),
                    top: rest(_menuFor!).dy - _blob / 2 - 66,
                    width: _room ? 300 : 208,
                    height: 50,
                    child: _BlobMenu(
                      onChange: _menuChange,
                      onRemove: _menuRemove,
                      onAdd: _room ? _menuAdd : null,
                    ),
                  ),
                ],
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
                        _signHeld = false;
                        // Held still while the blobs are out: the same as holding a blob.
                        _heldEdit = false;
                        _holdTimer?.cancel();
                        if (_panelOpen && !PanelWatch.instance.anyOpen) {
                          _panelOpen = false;
                          _signSync();
                        }
                        // Held still, closed or with the blobs out: Prism's settings. A finger
                        // that moves before the wait is over is the glass or a flick, never this.
                        if (!_drawerOpen &&
                            !_sheetOpen &&
                            !_parked &&
                            !_carrying &&
                            !_panelOpen) {
                          _holdTimer = Timer(
                            Duration(milliseconds: _holdMs),
                            () {
                              if (_downAt != null &&
                                  !_moved &&
                                  !_lifted &&
                                  !_drawerOpen &&
                                  !_panelOpen &&
                                  mounted) {
                                _heldEdit = true;
                                _liftTimer?.cancel();
                                _kick.animateTo(1);
                                _menuAway();
                                // (The blobs go in: the settings are for the button.)
                                _setOpen(false);
                                Haptics.settle();
                                _showFloating();
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
                          _face,
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
                                          blobs: _signBlobs,
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
                                            Opacity(
                                              opacity: (1 - _face.value * 1.6)
                                                  .clamp(0.0, 1.0),
                                              child: Transform.scale(
                                                scale:
                                                    1 -
                                                    0.45 *
                                                        _face.value.clamp(
                                                          0.0,
                                                          1.0,
                                                        ),
                                                child: CustomPaint(
                                                  size: const Size(38, 38),
                                                  painter: _ButtonSign(
                                                    blobs: _signBlobs,
                                                    turn: _signTurn.value,
                                                    shot: _signShot.value,
                                                    vivid:
                                                        Apps.instance.blobVivid,
                                                    dark: _dark.value,
                                                    cog: _cog.value,
                                                    look:
                                                        Apps.instance.blobLook,
                                                    hint: _cogHint.value,
                                                    rim: _button / 2 - 2,
                                                    glint: c.accent,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // The blob being changed, grown out of the sign.
                                            if (_face.value > 0.02 &&
                                                _faceOf != null)
                                              Opacity(
                                                opacity:
                                                    ((_face.value - 0.25) / 0.6)
                                                        .clamp(0.0, 1.0),
                                                child: Transform.scale(
                                                  scale:
                                                      0.45 + 0.55 * _face.value,
                                                  child: SizedBox(
                                                    width: 44,
                                                    height: 44,
                                                    child: FittedBox(
                                                      child: _faceOf,
                                                    ),
                                                  ),
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
                              // Always the full glass, whatever the glass quality setting or what
                              // Auto has stepped down to (the owner's rule, DESIGN §8). Android's
                              // "reduce transparency" still makes it solid (inside [Glass]).
                              quality: GlassQuality.full,
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
  // (In the preview only: opened already scrolled to one of its parts, by its test key, to
  // take its picture: PRISM_PANEL_SHOW=buildName.)
  final String? show = Platform.environment['PRISM_PANEL_SHOW'];
  if (show != null) {
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      final BuildContext? at = Robot.key(show).currentContext;
      if (at != null && at.mounted) {
        Scrollable.ensureVisible(at, alignment: 0.02);
      }
    });
  }
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
                builder: (BuildContext context, Widget? _) =>
                    SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'Prism',
                            style: LumenType.display(
                              26,
                              weight: 700,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Colour',
                            style: LumenType.label(color: c.inkMuted),
                          ),
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
                            onChanged: (int v) =>
                                Look.instance.choose(strength: v),
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
                          Text(
                            'Theme',
                            style: LumenType.label(color: c.inkMuted),
                          ),
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
                            onChanged: (bool v) =>
                                settings.reduceTransparency = v,
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
                                  onChanged: (bool _) =>
                                      RestBubble.instance.ask(),
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
                          // The Sidekick switched off everywhere has nowhere to be held, so its own
                          // settings can't be reached: only then, this one line brings it back.
                          // (Nothing else about the Sidekick is here: its settings are its own.)
                          ListenableBuilder(
                            listenable: Listenable.merge(<Listenable>[
                              RestBubble.instance.floatIn,
                              RestBubble.instance.floatOut,
                            ]),
                            builder: (BuildContext context, Widget? _) =>
                                RestBubble.instance.canFloat
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            'Bring back the Sidekick',
                                            style: LumenType.text(
                                              15,
                                              weight: 560,
                                              color: c.ink,
                                            ),
                                          ),
                                        ),
                                        Pressable(
                                          key: Robot.key('bringBack'),
                                          onTap: () {
                                            Haptics.tick();
                                            Diag.instance.event(
                                              'settings page: the Sidekick brought back',
                                            );
                                            RestBubble.instance.setFloating(
                                              inPrism: true,
                                              overApps: true,
                                            );
                                            RestBubble.instance.bringSide();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                            decoration: ShapeDecoration(
                                              color: c.accent,
                                              shape: const StadiumBorder(),
                                            ),
                                            child: Text(
                                              'Bring back',
                                              style: LumenType.text(
                                                14,
                                                weight: 650,
                                                color: c.onAccent,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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
                            labels: const <String>[
                              'Auto',
                              'Full',
                              'Medium',
                              'Low',
                            ],
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
                          _buildBadge(),
                          // The test this build asks for first, right under the badge; then the others.
                          // (Since 184 only these four: the owner had the short guided test, the
                          // 20-minute long test, the glass settings test and the chat-head battery
                          // test taken off. Their code stays, reachable from the preview only.)
                          for (final Widget w in _testList(context, c)) w,
                          if (TestRun.last()
                              case final String report?) ...<Widget>[
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
                          ..._pastReports(c),
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
            // (Barely there: close to the ground's own colour.)
            fill(ink, dark ? 0.09 : 0.07),
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
        if (dark > 0.001) {
          // Under the glass, the triangle is set in black: the glass's own darkness. It goes
          // with the glass, in the first moment it is lifted, and the triangle is left alone.
          // (Out almost to the glass's edge, and melting away there: no hard inner circle, and
          // no thick tinted band between it and the rim. Only the rim's own thin light is left.)
          final double full = rim > 0 ? rim : size.width / 2;
          canvas.drawCircle(
            mid,
            full,
            Paint()
              ..shader = ui.Gradient.radial(
                mid,
                full,
                <Color>[
                  Colors.black.withValues(alpha: 0.92 * dark),
                  Colors.black.withValues(alpha: 0.92 * dark),
                  Colors.black.withValues(alpha: 0),
                ],
                const <double>[0, 0.84, 1],
              ),
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
          // (No ground of its own: under the glass the black is the glass's, and lifted away
          // the blob is the shape alone, whatever the look.)
          ownGround: false,
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
          // (It grows out of the sign at the sign's own size, and back into it at that size:
          // the cog was the glass's size all the way, and the sign popped back smaller.)
          radius: (rim > 0 ? rim : size.width / 2) * (_blob + (1 - _blob) * c),
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
            // (Lightly tinted: what lies under the glass, the black most of all, shows through.)
            colors: <Color>[
              tone(0.42, 0.26),
              tone(0.2, 0.3),
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
                  .withValues(alpha: 0.22),
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

/// The small menu beside a held blob: Change, and Remove in red. Dark glass, as the panels are.
class _BlobMenu extends StatelessWidget {
  const _BlobMenu({required this.onChange, required this.onRemove, this.onAdd});

  final VoidCallback onChange, onRemove;

  /// A new blob right after this one. Null when the menu is full.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    Widget half(String label, Color ink, VoidCallback onTap, String key) =>
        Expanded(
          child: GestureDetector(
            key: Robot.key(key),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Haptics.tick();
              onTap();
            },
            child: Center(
              child: Text(
                label,
                textScaler: TextScaler.noScaling,
                style: LumenType.text(15.5, weight: 650, color: ink),
              ),
            ),
          ),
        );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.scale(
          scale: 0.9 + 0.1 * t,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: const Color(0xF2202228),
          shape: StadiumBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
          shadows: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            half('Change', Colors.white, onChange, 'menuChange'),
            Container(
              width: 1,
              height: 22,
              color: Colors.white.withValues(alpha: 0.16),
            ),
            half('Remove', const Color(0xFFFF6B6F), onRemove, 'menuRemove'),
            if (onAdd != null) ...<Widget>[
              Container(
                width: 1,
                height: 22,
                color: Colors.white.withValues(alpha: 0.16),
              ),
              half('Add', const Color(0xFF4CD48A), onAdd!, 'menuAdd'),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small dark-glass menu of a few words in a row, as a held blob's: each a tap.
class _PillMenu extends StatelessWidget {
  const _PillMenu({required this.items});

  final List<(String, Color, VoidCallback, String)> items;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.scale(
          scale: 0.9 + 0.1 * t,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: const Color(0xF2202228),
          shape: StadiumBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
          shadows: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            for (int k = 0; k < items.length; k++) ...<Widget>[
              if (k > 0)
                Container(
                  width: 1,
                  height: 22,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              Expanded(
                child: GestureDetector(
                  key: Robot.key(items[k].$4),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Haptics.tick();
                    items[k].$3();
                  },
                  child: Center(
                    child: Text(
                      items[k].$1,
                      textScaler: TextScaler.noScaling,
                      style: LumenType.text(
                        15.5,
                        weight: 650,
                        color: items[k].$2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A panel that grows out of the button and goes back into it exactly as the app list does:
/// its rectangle goes from the button's circle to its own, on the same spring (quick, with a
/// hint of give) and back on the same quick one, its contents fading in and out at the same
/// points. A tap beside it, on the button included, and back close it the same way.
class _SpringPanel extends StatefulWidget {
  const _SpringPanel({
    required this.from,
    required this.button,
    required this.above,
    required this.clear,
    required this.onReady,
    required this.child,
  });

  final Offset from;
  final double button, above;

  /// While a slider in it is held the shade goes, as the panel does.
  final ValueNotifier<String?> clear;
  final void Function(VoidCallback close) onReady;
  final Widget child;

  @override
  State<_SpringPanel> createState() => _SpringPanelState();
}

class _SpringPanelState extends State<_SpringPanel>
    with TickerProviderStateMixin {
  late final SpringValue _g = SpringValue(
    this,
    value: 0,
    spring: Motions.snappy,
  );
  final GlobalKey _box = GlobalKey();
  Rect? _end;
  bool _closing = false, _gone = false;

  @override
  void initState() {
    super.initState();
    widget.onReady(_close);
    _g
      ..addListener(_moved)
      ..animateTo(1, spring: Motions.snappy);
  }

  /// Where the panel is when fully open, read after each layout: it changes size with what is in it.
  void _measure(Duration _) {
    if (!mounted) {
      return;
    }
    final RenderObject? o = _box.currentContext?.findRenderObject();
    if (o is RenderBox && o.hasSize) {
      final Rect r = o.localToGlobal(Offset.zero) & o.size;
      if (r != _end) {
        setState(() => _end = r);
      }
    }
  }

  void _close() {
    if (_closing || _gone) {
      return;
    }
    _closing = true;
    _g.animateTo(0, spring: Motions.spatialFast);
  }

  void _moved() {
    if (_closing && !_gone && _g.value <= 0.004 && mounted) {
      _gone = true;
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _g.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) {
          _close();
        }
      },
      child: Stack(
        children: <Widget>[
          // A tap anywhere beside it, the button too, closes it.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          // (No shade from build 186: nothing dims the screen behind Prism's panels, as with the
          // Sidekick's. A tap anywhere beside the panel still closes it, above.)
          ListenableBuilder(
            listenable: _g,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: KeyedSubtree(key: _box, child: widget.child),
            ),
            builder: (BuildContext context, Widget? child) {
              final double g = _g.value;
              final Rect? end = _end;
              if (end == null || end.isEmpty) {
                return Opacity(opacity: 0, child: child);
              }
              final Rect start = Rect.fromCircle(
                center: widget.from,
                radius: widget.button / 2,
              );
              final Rect r = Rect.lerp(start, end, g)!;
              final Matrix4 m = Matrix4.identity()
                ..translateByDouble(r.left, r.top, 0, 1)
                ..scaleByDouble(
                  r.width / end.width,
                  r.height / end.height,
                  1,
                  1,
                )
                ..translateByDouble(-end.left, -end.top, 0, 1);
              return Opacity(
                // (The contents come in and go at the same points as the app list's.)
                opacity: ((g - 0.05) / 0.25).clamp(0.0, 1.0),
                child: Transform(transform: m, child: child),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---- The test area (183): the build being tested, the test it asks for, and the past reports.

// The colours of the mock-up the owner approved: gold for the build, green for the test it
// asks for. The badge keeps its own light text, so it reads the same in a light theme.
const Color _gold = Color(0xFFE3AD55);
const Color _go = Color(0xFF3FCF8E);
const Color _goInk = Color(0xFF06231A);

/// At the top of the test area: which build this is, big, its date and what it is for.
Widget _buildBadge() => Container(
  key: Robot.key('buildName'),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _gold, width: 1.5),
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF3A2C12), Color(0xFF2A2416)],
    ),
  ),
  child: Row(
    children: <Widget>[
      Text(
        '${Diag.buildNumber}',
        style: LumenType.display(26, color: _gold, height: 1),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              "You're testing build ${Diag.buildNumber}",
              style: LumenType.text(
                14.5,
                weight: 600,
                color: const Color(0xFFF1EEE8),
                height: 1.3,
              ),
            ),
            Text(
              '${Diag.buildDate}  ·  ${Diag.buildTitle}',
              style: LumenType.text(
                12.5,
                color: const Color(0xFFA19D95),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);

/// One of the test area's buttons. The one this build asks for ([Diag.askedTest]) is green,
/// with a "Test this one" tag; if it asks for none, none is.
/// The test area's tests, the one this build asks for ([Diag.askedTest]) first, each with one
/// short line of what it is.
List<Widget> _testList(BuildContext context, LumenColors c) {
  final List<(String, String, String, VoidCallback)> all =
      <(String, String, String, VoidCallback)>[
        (
          'leak',
          'Run the leak test',
          'About 9 min · unplugged, hands off',
          () => Diag.instance.leakTest?.call(),
        ),
        (
          'button',
          'Run the button test',
          'About 17 min · unplugged, hands off',
          () => Diag.instance.buttonTest?.call(),
        ),
        (
          'hour',
          'Run the hour-long test',
          'About an hour · unplugged, silent',
          () => Diag.instance.hourTest?.call(),
        ),
        (
          'stability',
          'Run the 2½-hour stability test',
          '2½ hours · unplugged, silent',
          () => Diag.instance.soakTest?.call(),
        ),
      ];
  final List<(String, String, String, VoidCallback)> ordered =
      <(String, String, String, VoidCallback)>[
        ...all.where(
          ((String, String, String, VoidCallback) x) => x.$1 == Diag.askedTest,
        ),
        ...all.where(
          ((String, String, String, VoidCallback) x) => x.$1 != Diag.askedTest,
        ),
      ];
  return <Widget>[
    for (final (String id, String label, String note, VoidCallback run)
        in ordered) ...<Widget>[
      const SizedBox(height: 10),
      _testButton(context, c, id, label, run, note: note),
    ],
  ];
}

Widget _testButton(
  BuildContext context,
  LumenColors c,
  String id,
  String label,
  VoidCallback run, {
  String note = '',
}) {
  final bool asked = Diag.askedTest == id;
  final Widget button = Pressable(
    key: Robot.key('test:$id'),
    onTap: () {
      Navigator.of(context).pop();
      Haptics.settle();
      run();
    },
    child: Container(
      constraints: const BoxConstraints(minHeight: 52),
      // (The asked-for test has a little more room at the top: its tag sits on its edge, and at a
      // large text size it would touch the label.)
      padding: EdgeInsets.fromLTRB(18, asked ? 13 : 8, 18, 8),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: asked ? _go : c.ink.withValues(alpha: 0.08),
        shape: const StadiumBorder(),
        shadows: asked
            ? <BoxShadow>[
                BoxShadow(color: _go.withValues(alpha: 0.25), spreadRadius: 3),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            textAlign: TextAlign.center,
            style: LumenType.text(
              15,
              weight: 700,
              color: asked ? _goInk : c.ink,
              height: 1.15,
            ),
          ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                note,
                textAlign: TextAlign.center,
                style: LumenType.text(
                  12.5,
                  color: asked ? _goInk.withValues(alpha: 0.75) : c.inkMuted,
                  height: 1.25,
                ),
              ),
            ),
        ],
      ),
    ),
  );
  if (!asked) {
    return button;
  }
  return Stack(
    clipBehavior: Clip.none,
    children: <Widget>[
      button,
      Positioned(
        top: -9,
        right: 14,
        child: IgnorePointer(
          child: Container(
            key: Robot.key('askedTag'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: const ShapeDecoration(
              color: Color(0xFFF1EEE8),
              shape: StadiumBorder(),
            ),
            child: Text(
              'TEST THIS ONE',
              style: LumenType.text(
                10.5,
                weight: 700,
                color: const Color(0xFF111111),
                height: 1.1,
                spacing: 0.6,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Under "Copy the last report": every finished test's report that is kept, newest first. A
/// tap copies it whole, as "Copy the last report" does.
List<Widget> _pastReports(LumenColors c) {
  final List<PastReport> all = PastReports.instance.list();
  if (all.isEmpty) {
    return const <Widget>[];
  }
  return <Widget>[
    const SizedBox(height: 16),
    Text(
      'Past reports',
      key: Robot.key('pastReports'),
      style: LumenType.label(color: c.inkMuted),
    ),
    const SizedBox(height: 2),
    for (final (int i, PastReport r) in all.indexed)
      Builder(
        builder: (BuildContext context) {
          String text;
          try {
            text = r.text();
          } catch (_) {
            text = '';
          }
          final String? build = r.build(text);
          final String result = r.result(text);
          return Pressable(
            onTap: () async {
              await Diag.instance.copy(text);
              Haptics.settle();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              decoration: i == 0
                  ? null
                  : BoxDecoration(
                      border: Border(
                        top: BorderSide(color: c.ink.withValues(alpha: 0.1)),
                      ),
                    ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          build == null ? r.name : '${r.name}  ·  build $build',
                          style: LumenType.text(
                            13.5,
                            weight: 600,
                            color: c.ink,
                            height: 1.3,
                          ),
                        ),
                        Text(
                          <String>[
                            PastReports.whenSaid(r.when),
                            if (result.isNotEmpty) result,
                          ].join('  ·  '),
                          style: LumenType.text(
                            12,
                            color: c.inkMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: c.ink.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: Text(
                      'Copy',
                      style: LumenType.text(
                        13,
                        weight: 600,
                        color: c.ink,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
  ];
}

/// Whether two byte lists are the same, byte for byte.
bool _sameBytes(List<int> a, List<int> b) {
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

/// What a tap on Prism's button would do (see `_ShellState._tapOutcome`).
enum TapOutcome {
  /// Nothing is open: the blobs come out.
  openBlobs,

  /// The blobs are out: they go in.
  closeBlobs,

  /// The blobs are being changed: Prism's settings (the blobs stay out under them).
  openSettings,

  /// The app list closes, and nothing comes back.
  closeDrawer,

  /// The app list was up to choose for a blob: it closes and the blobs come back out.
  closeDrawerToBlobs,

  /// The app list was up to choose a two-finger swipe: it closes and Prism's settings come back.
  closeDrawerToSettings,

  /// The app list was up to choose from another app: it closes and Prism goes back to that app.
  closeDrawerToBack,

  /// The magnifying glass is out, put down somewhere: it comes home.
  callGlassHome,

  /// Prism's settings close, and nothing is left open.
  closePanel,

  /// Prism's settings close, and the blobs are still out under them.
  closePanelToBlobs;

  /// Whether the tap leaves nothing of Prism's open: then the triangle points down.
  bool get closesAll => switch (this) {
    closeBlobs ||
    closeDrawer ||
    closeDrawerToBack ||
    callGlassHome ||
    closePanel => true,
    _ => false,
  };
}

/// How far the triangle turns, in degrees, when what a tap would do changes but it points the
/// same way as before (the owner's choice: 120, a third of a turn, so the change is seen; or 0).
const double sameMeaningTurn = 120;
