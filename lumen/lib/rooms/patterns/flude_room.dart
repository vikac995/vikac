import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/settings.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';

enum _Kind { app, screen, quick }

class _Spot {
  const _Spot(this.label, this.icon, this.color, this.kind, [this.group = '']);
  final String label, group;
  final IconData icon;
  final Color color;
  final _Kind kind;
}

// Quick actions share their category's colour; the glyph says which one it is.
const Color _food = Color(0xFFE8703A),
    _body = Color(0xFF3F8CF0),
    _time = Color(0xFFE5A50A),
    _train = Color(0xFF8B5CF6);
const List<_Spot> _catalogue = <_Spot>[
  _Spot('Messages', Icons.chat_bubble_rounded, Color(0xFF25B45B), _Kind.app),
  _Spot('Camera', Icons.photo_camera_rounded, Color(0xFF5B6CFF), _Kind.app),
  _Spot('Music', Icons.music_note_rounded, Color(0xFFE0457B), _Kind.app),
  _Spot('Maps', Icons.map_rounded, Color(0xFF14A79B), _Kind.app),
  _Spot('Workout', Icons.fitness_center_rounded, _train, _Kind.screen),
  _Spot('Progress', Icons.show_chart_rounded, _train, _Kind.screen),
  _Spot('Exercises', Icons.sports_gymnastics_rounded, _train, _Kind.screen),
  _Spot('Log food', Icons.restaurant_rounded, _food, _Kind.quick, 'Food'),
  _Spot('Scan', Icons.qr_code_scanner_rounded, _food, _Kind.quick, 'Food'),
  _Spot('Quick log', Icons.keyboard_rounded, _food, _Kind.quick, 'Food'),
  _Spot('Photo', Icons.add_a_photo_rounded, _food, _Kind.quick, 'Food'),
  _Spot('Weigh-in', Icons.monitor_weight_outlined, _body, _Kind.quick, 'Body'),
  _Spot('Timer', Icons.timer_outlined, _time, _Kind.quick, 'Time'),
  _Spot(
    'Remind me',
    Icons.notifications_active_outlined,
    _time,
    _Kind.quick,
    'Time',
  ),
];
_Spot _find(String l) => _catalogue.firstWhere((_Spot s) => s.label == l);

// What the button offers by itself, by situation.
const Map<String, _Spot?> _suggest = <String, _Spot?>{
  'Off': null,
  'Morning': _Spot(
    'Weigh-in, before breakfast',
    Icons.monitor_weight_outlined,
    _body,
    _Kind.quick,
  ),
  'Workout': _Spot('Finish set 3', Icons.check_rounded, _train, _Kind.quick),
  'Lunch': _Spot('Log lunch', Icons.restaurant_rounded, _food, _Kind.quick),
};

/// Room 50. The button in the middle. One tap and it splits into up to five
/// glass blobs; press, slide and let go does it in one movement. Above it
/// sits one suggestion that changes with the moment. Everything is editable
/// in place.
class FludeRoom extends StatefulWidget {
  const FludeRoom({super.key});

  @override
  State<FludeRoom> createState() => _FludeRoomState();
}

class _FludeRoomState extends State<FludeRoom> with TickerProviderStateMixin {
  static const double _blob = 60, _button = 68;
  final List<_Spot> _blobs = <_Spot>[
    _find('Workout'),
    _find('Log food'),
    _find('Scan'),
    _find('Messages'),
    _find('Timer'),
  ];
  String _context = 'Workout';
  bool _open = false, _edit = false, _slid = false;
  int? _hover;
  int? _picking; // slot being set in the picker; _blobs.length means "new"
  _Spot? _launched;
  Offset _launchFrom = Offset.zero;
  Size _stage = Size.zero;
  double _bottomInset = 0;
  // Fast and nearly without bounce: this is used all day.
  late final SpringValue _t = SpringValue(this, spring: Motions.spatialFast);
  // One spring per blob, so each has its own speed, overshoot and stretch.
  late final List<SpringValue> _out = <SpringValue>[
    for (int i = 0; i < 5; i++) SpringValue(this),
  ];
  // How much each blob has swollen under the thumb; neighbours lean away from it.
  late final List<SpringValue> _grow = <SpringValue>[
    for (int i = 0; i < 5; i++)
      SpringValue(this, spring: Motions.expressiveFast),
  ];
  // The button recoils when it fires.
  late final SpringValue _kick = SpringValue(
    this,
    value: 1,
    spring: Motions.expressiveFast,
  );
  late final Listenable _all = Listenable.merge(<Listenable>[
    _t,
    _kick,
    ..._out,
    ..._grow,
  ]);
  final List<Timer> _fuses = <Timer>[];
  String _feel = 'Balanced';
  SpringDescription get _shoot => switch (_feel) {
    'Snappy' => SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 1500,
      ratio: 0.92,
    ),
    'Bouncy' => SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 520,
      ratio: 0.45,
    ),
    _ => SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 950,
      ratio: 0.62,
    ),
  };
  late final SpringValue _launch = SpringValue(this, spring: Motions.spatial);
  late final SpringValue _sheet = SpringValue(this, spring: Motions.spatial);
  late final SpringValue _picker = SpringValue(this, spring: Motions.spatial);
  Timer? _back;

  @override
  void dispose() {
    _back?.cancel();
    for (final Timer t in _fuses) {
      t.cancel();
    }
    for (final SpringValue s in <SpringValue>[
      _t,
      _launch,
      _sheet,
      _picker,
      _kick,
      ..._out,
      ..._grow,
    ]) {
      s.dispose();
    }
    super.dispose();
  }

  Offset get _centre =>
      Offset(_stage.width / 2, _stage.height - _bottomInset - 52);
  int get _slots => _blobs.length + (_edit && _blobs.length < 5 ? 1 : 0);

  /// Where blob [i] of [n] rests: a shallow arch over the button.
  Offset _rest(int i, int n) {
    final double gap = math.min(
      72.0,
      (_stage.width - 28 - _blob) / math.max(1, n - 1),
    );
    final double k = i - (n - 1) / 2;
    return _centre +
        Offset(
          k * gap,
          -124 - 24 * math.cos((k / 2.6).clamp(-1.0, 1.0) * math.pi / 2),
        );
  }

  /// How far blob [i] has travelled. Goes a little past 1 when the spring overshoots.
  double _p(int i, int n) => _out[i].value;

  /// Where blob [i] is right now: on its way out, and leaning away from a swollen neighbour.
  Offset _at(int i, int n) {
    double push = 0;
    for (int j = 0; j < n; j++) {
      if (j != i) {
        push += (i - j).sign * 9 * _grow[j].value / (i - j).abs();
      }
    }
    final Offset b = _centre;
    return b + (_rest(i, n) - b) * _p(i, n) + Offset(push, 0);
  }

  /// Stretch along the line of flight, from the blob's speed.
  double _stretch(int i) => (_out[i].velocity.abs() * 0.028).clamp(0.0, 0.34);

  void _fire() {
    final int n = _slots;
    for (final Timer t in _fuses) {
      t.cancel();
    }
    _fuses.clear();
    for (int i = 0; i < n; i++) {
      // The middle leaves first; each step outward waits 14 ms.
      final int wait = ((i - (n - 1) / 2).abs() * 14).round();
      _fuses.add(
        Timer(
          Duration(milliseconds: wait),
          () => _out[i].animateTo(1, spring: _shoot),
        ),
      );
    }
  }

  void _setOpen(bool v) {
    if (v == _open) {
      return;
    }
    setState(() {
      _open = v;
      _hover = null;
    });
    _t.animateTo(v ? 1 : 0);
    if (v) {
      _fire();
      _kick.jumpTo(0.84);
      _kick.animateTo(1);
    } else {
      for (final Timer t in _fuses) {
        t.cancel();
      }
      // Leaving is quick and does not bounce.
      for (final SpringValue o in _out) {
        o.animateTo(0, spring: Motions.spatialFast);
      }
      for (final SpringValue g in _grow) {
        g.animateTo(0);
      }
    }
    Haptics.tick();
  }

  void _setHover(int? h) {
    if (h == _hover) {
      return;
    }
    setState(() => _hover = h);
    for (int i = 0; i < 5; i++) {
      _grow[i].animateTo(i == h ? 1 : 0);
    }
    if (h != null) {
      Haptics.tick();
    }
  }

  void _run(_Spot s, Offset from) {
    _setOpen(false);
    Haptics.settle();
    setState(() {
      _launched = s;
      _launchFrom = from;
    });
    if (s.kind == _Kind.quick) {
      // Quick actions open over the home screen; you never leave it.
      _sheet.animateTo(1);
    } else {
      _launch.jumpTo(0);
      _launch.animateTo(1);
      _back?.cancel();
      _back = Timer(
        const Duration(milliseconds: 1300),
        () => _launch.animateTo(0),
      );
    }
  }

  int? _blobAt(Offset p) {
    for (int i = 0; i < _blobs.length; i++) {
      if ((_rest(i, _slots) - p).distance < _blob / 2 + 10) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    _bottomInset = safe.bottom;
    final _Spot? tip = _edit ? null : _suggest[_context];
    return Scaffold(
      backgroundColor: c.bg,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          _stage = box.biggest;
          final int n = _slots;
          return Stack(
            children: <Widget>[
              // A stand-in home screen, so the glass has something behind it.
              Positioned.fill(child: CustomPaint(painter: _Home(c.dark))),
              Positioned(
                left: 16,
                right: 16,
                top: safe.top + 44,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const RoomHeader(number: 50, title: 'The button'),
                    const SizedBox(height: 14),
                    Text(
                      'SITUATION',
                      style: LumenType.label(color: c.inkMuted),
                    ),
                    const SizedBox(height: 6),
                    Segmented<String>(
                      values: const <String>[
                        'Off',
                        'Morning',
                        'Workout',
                        'Lunch',
                      ],
                      labels: const <String>[
                        'Off',
                        'Morning',
                        'Workout',
                        'Lunch',
                      ],
                      value: _context,
                      onChanged: (String v) => setState(() => _context = v),
                    ),
                    const SizedBox(height: 12),
                    Text('MOTION', style: LumenType.label(color: c.inkMuted)),
                    const SizedBox(height: 6),
                    Segmented<String>(
                      values: const <String>['Snappy', 'Balanced', 'Bouncy'],
                      labels: const <String>['Snappy', 'Balanced', 'Bouncy'],
                      value: _feel,
                      onChanged: (String v) => setState(() => _feel = v),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _edit
                          ? 'Editing. Tap a blob to change it, the minus to remove it, the plus to add one. Five at most.'
                          : 'Tap the button, or press it, slide to a blob and let go. Hold it to edit.',
                      style: LumenType.text(14, color: c.inkMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
              // Dim, and a tap anywhere closes.
              ListenableBuilder(
                listenable: _t,
                builder: (BuildContext context, Widget? _) => IgnorePointer(
                  ignoring: !_open,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _setOpen(false),
                    child: ColoredBox(
                      color: Colors.black.withValues(
                        alpha: 0.34 * _t.value.clamp(0.0, 1.0),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              // Bottom bar: two spots each side of the button.
              Positioned(
                left: 16,
                right: 16,
                bottom: safe.bottom + 20,
                height: 64,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: c.surfaceHigh.withValues(alpha: 0.86),
                    shape: StadiumBorder(side: BorderSide(color: c.hairline)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Icon(Icons.phone_rounded, color: c.inkMuted),
                      Icon(Icons.chat_bubble_rounded, color: c.inkMuted),
                      const SizedBox(width: _button),
                      Icon(Icons.photo_camera_rounded, color: c.inkMuted),
                      Icon(Icons.apps_rounded, color: c.inkMuted),
                    ],
                  ),
                ),
              ),
              // The glass: one blurred layer cut to the shape of the button, the blobs and the necks between them.
              ListenableBuilder(
                listenable: _all,
                builder: (BuildContext context, Widget? _) {
                  final Path shape = Path()..fillType = PathFillType.nonZero;
                  final Offset b = _centre;
                  for (int i = 0; i < n; i++) {
                    final double p = _p(i, n);
                    if (p <= 0) {
                      continue;
                    }
                    final Offset at = _at(i, n);
                    final double r =
                        _blob /
                        2 *
                        (0.55 + 0.45 * p) *
                        (1 + 0.16 * _grow[i].value);
                    final double st = _stretch(i);
                    final Offset dir = _rest(i, n) - b;
                    shape.addPath(
                      Path()..addOval(
                        Rect.fromCenter(
                          center: Offset.zero,
                          width: r * 2 * (1 + st),
                          height: r * 2 * (1 - st * 0.5),
                        ),
                      ),
                      at,
                      matrix4: Matrix4.rotationZ(math.atan2(dir.dy, dir.dx))
                          .storage,
                    );
                    // The neck: thick while they are still one drop, gone once apart.
                    final double w = r * 1.5 * (1 - p * 1.7).clamp(0.0, 1.0);
                    if (w > 1) {
                      final Offset d = at - b,
                          nrm =
                              Offset(-d.dy, d.dx) /
                              math.max(1, d.distance) *
                              w /
                              2;
                      shape.addPolygon(<Offset>[
                        b + nrm,
                        at + nrm,
                        at - nrm,
                        b - nrm,
                      ], true);
                    }
                  }
                  if (tip != null && _t.value > 0) {
                    shape.addRRect(
                      _tipRect(
                        tip,
                      ).shift(Offset(0, (1 - _t.value.clamp(0.0, 1.0)) * 30)),
                    );
                  }
                  return IgnorePointer(
                    child: ClipPath(
                      clipper: _PathClip(shape),
                      child: settings.reduceTransparency
                          ? ColoredBox(
                              color: c.surfaceHigh,
                              child: const SizedBox.expand(),
                            )
                          : BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                sigmaX: 16,
                                sigmaY: 16,
                              ),
                              child: ColoredBox(
                                color: (c.dark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.10),
                                child: const SizedBox.expand(),
                              ),
                            ),
                    ),
                  );
                },
              ),
              // Blob faces. They can be hit from the first frame.
              for (int i = 0; i < n; i++)
                ListenableBuilder(
                  listenable: _all,
                  builder: (BuildContext context, Widget? _) {
                    final double p = _p(i, n);
                    final Offset at = _at(i, n);
                    final bool empty = i >= _blobs.length;
                    final double scale =
                        (0.55 + 0.45 * p) * (1 + 0.16 * _grow[i].value);
                    final double st = _stretch(i);
                    final Offset dir = _rest(i, n) - _centre;
                    final double ang = math.atan2(dir.dy, dir.dx);
                    return Positioned(
                      left: at.dx - _blob / 2,
                      top: at.dy - _blob / 2,
                      child: IgnorePointer(
                        ignoring: !_open,
                        child: Opacity(
                          opacity: (p * 2.2).clamp(0.0, 1.0),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (_edit) {
                                setState(() => _picking = i);
                                _picker.animateTo(1);
                                Haptics.tick();
                              } else {
                                _run(_blobs[i], _rest(i, n));
                              }
                            },
                            child: SizedBox(
                              width: _blob,
                              height: _blob + 22,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: <Widget>[
                                  Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.rotationZ(ang)
                                      ..scaleByDouble(
                                        scale * (1 + st),
                                        scale * (1 - st * 0.5),
                                        1,
                                        1,
                                      )
                                      ..rotateZ(-ang),
                                    child: _Face(
                                      spot: empty ? null : _blobs[i],
                                      size: _blob,
                                      dark: c.dark,
                                    ),
                                  ),
                                  Positioned(
                                    left: -14,
                                    right: -14,
                                    top: _blob + 5,
                                    child: Text(
                                      empty ? 'Add' : _blobs[i].label,
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                      textAlign: TextAlign.center,
                                      textScaler: TextScaler.noScaling,
                                      style: LumenType.text(
                                        11.5,
                                        weight: i == _hover ? 720 : 620,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  if (_edit && !empty)
                                    Positioned(
                                      right: -12,
                                      top: -12,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          setState(() => _blobs.removeAt(i));
                                          Haptics.tick();
                                        },
                                        child: const SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: Center(
                                            child: _Badge(
                                              Icons.remove_rounded,
                                              Color(0xFFE5484D),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_edit && !empty)
                                    const Positioned(
                                      right: -4,
                                      top: _blob - 20,
                                      child: IgnorePointer(
                                        child: _Badge(
                                          Icons.edit_rounded,
                                          Color(0xFF2E7BFF),
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
              // The suggestion: the largest target, nearest the thumb.
              if (tip != null)
                ListenableBuilder(
                  listenable: _t,
                  builder: (BuildContext context, Widget? child) {
                    final double t = _t.value.clamp(0.0, 1.0);
                    final RRect r = _tipRect(tip);
                    return Positioned(
                      left: r.left,
                      top: r.top + (1 - t) * 30,
                      width: r.width,
                      height: r.height,
                      child: IgnorePointer(
                        ignoring: !_open,
                        child: Opacity(opacity: t, child: child),
                      ),
                    );
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _run(tip, _centre + const Offset(0, -62)),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: tip.color.withValues(alpha: 0.62),
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.38),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(tip.icon, size: 18, color: Colors.white),
                          const SizedBox(width: 7),
                          Text(
                            tip.label,
                            textScaler: TextScaler.noScaling,
                            style: LumenType.text(
                              14,
                              weight: 700,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // The button itself.
              Positioned(
                left: _centre.dx - _button / 2,
                top: _centre.dy - _button / 2,
                child: GestureDetector(
                  onTap: () => _setOpen(!_open),
                  onLongPress: () {
                    setState(() => _edit = !_edit);
                    Haptics.thud();
                    _setOpen(_edit);
                    if (_edit) {
                      _fire();
                    }
                  },
                  onPanStart: (_) {
                    _slid = false;
                    if (!_edit) {
                      _setOpen(true);
                    }
                  },
                  onPanUpdate: (DragUpdateDetails d) {
                    if (_edit) {
                      return;
                    }
                    final RenderBox rb =
                        context.findRenderObject()! as RenderBox;
                    final int? h = _blobAt(rb.globalToLocal(d.globalPosition));
                    _slid = true;
                    _setHover(h);
                  },
                  onPanEnd: (_) {
                    if (_hover != null) {
                      _run(_blobs[_hover!], _rest(_hover!, n));
                    } else if (_slid) {
                      _setOpen(false);
                    }
                  },
                  child: ListenableBuilder(
                    listenable: _all,
                    builder: (BuildContext context, Widget? _) =>
                        Transform.scale(
                          scale: _kick.value,
                          child: SizedBox.square(
                            dimension: _button,
                            child: CustomPaint(
                              painter: _ButtonFace(
                                open: _t.value,
                                accent: c.accent,
                                on: c.onAccent,
                                ring: _context == 'Workout' && !_edit
                                    ? 0.62
                                    : 0,
                              ),
                              child: _edit && !_open
                                  ? const Align(
                                      alignment: Alignment(1.25, -1.25),
                                      child: _Badge(
                                        Icons.edit_rounded,
                                        Color(0xFF2E7BFF),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                  ),
                ),
              ),
              if (_edit)
                Positioned(
                  right: 16,
                  top: safe.top + 50,
                  child: Pressable(
                    onTap: () {
                      setState(() => _edit = false);
                      _setOpen(false);
                    },
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: c.accent,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'Done',
                        style: LumenType.text(
                          14.5,
                          weight: 700,
                          color: c.onAccent,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              // An app opening: its colour grows out of the blob.
              ListenableBuilder(
                listenable: _launch,
                builder: (BuildContext context, Widget? _) {
                  final double t = _launch.value.clamp(0.0, 1.0);
                  final _Spot? s = _launched;
                  if (t <= 0.001 || s == null || s.kind == _Kind.quick) {
                    return const SizedBox.shrink();
                  }
                  return IgnorePointer(
                    child: ClipPath(
                      clipper: _PathClip(
                        Path()..addOval(
                          Rect.fromCircle(
                            center: _launchFrom,
                            radius: 30 + t * _stage.longestSide * 1.1,
                          ),
                        ),
                      ),
                      child: ColoredBox(
                        color: Color.lerp(s.color, Colors.black, 0.25)!,
                        child: Center(
                          child: Opacity(
                            opacity: t,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(s.icon, size: 64, color: Colors.white),
                                const SizedBox(height: 12),
                                Text(
                                  s.label,
                                  style: LumenType.display(
                                    30,
                                    weight: 700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  s.kind == _Kind.app
                                      ? 'Another app opens'
                                      : 'Straight to this screen',
                                  style: LumenType.text(
                                    14,
                                    color: Colors.white70,
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
              // A quick action: a small window over the home screen.
              _rise(
                _sheet,
                c,
                safe,
                child: _launched == null
                    ? const SizedBox.shrink()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                width: 44,
                                height: 44,
                                decoration: ShapeDecoration(
                                  color: _launched!.color,
                                  shape: const CircleBorder(),
                                ),
                                child: Icon(
                                  _launched!.icon,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _launched!.label,
                                  style: LumenType.display(
                                    24,
                                    weight: 700,
                                    color: c.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'A quick action opens as a small window like this one. The home screen stays behind it and nothing navigates away.',
                            style: LumenType.text(
                              14.5,
                              color: c.inkMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Pressable(
                            onTap: () => _sheet.animateTo(0),
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              decoration: ShapeDecoration(
                                color: c.accent,
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                'Done',
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
                onDismiss: () => _sheet.animateTo(0),
              ),
              // Choosing what a blob does.
              _rise(
                _picker,
                c,
                safe,
                onDismiss: () => _picker.animateTo(0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'What should it do?',
                      style: LumenType.display(24, weight: 700, color: c.ink),
                    ),
                    for (final (String title, _Kind kind)
                        in const <(String, _Kind)>[
                          ('Quick actions', _Kind.quick),
                          ('Gym Buddy screens', _Kind.screen),
                          ('Apps', _Kind.app),
                        ]) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        title.toUpperCase(),
                        style: LumenType.label(color: c.inkMuted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final _Spot s in _catalogue.where(
                            (_Spot s) => s.kind == kind,
                          ))
                            Pressable(
                              onTap: () {
                                final int i = _picking ?? _blobs.length;
                                setState(
                                  () => i < _blobs.length
                                      ? _blobs[i] = s
                                      : _blobs.add(s),
                                );
                                _picker.animateTo(0);
                                Haptics.settle();
                              },
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.only(
                                  left: 6,
                                  right: 14,
                                ),
                                decoration: ShapeDecoration(
                                  color: s.color.withValues(alpha: 0.16),
                                  shape: StadiumBorder(
                                    side: BorderSide(
                                      color: s.color.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: ShapeDecoration(
                                        color: s.color,
                                        shape: const CircleBorder(),
                                      ),
                                      child: Icon(
                                        s.icon,
                                        size: 17,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      s.label,
                                      style: LumenType.text(
                                        14,
                                        weight: 620,
                                        color: c.ink,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  RRect _tipRect(_Spot tip) {
    final double w = math.min(
      _stage.width - 120,
      60.0 + tip.label.length * 8.4,
    );
    return RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: _centre + const Offset(0, -64),
        width: w,
        height: 44,
      ),
      const Radius.circular(22),
    );
  }

  Widget _rise(
    SpringValue v,
    LumenColors c,
    EdgeInsets safe, {
    required Widget child,
    required VoidCallback onDismiss,
  }) => ListenableBuilder(
    listenable: v,
    builder: (BuildContext context, Widget? sheet) {
      final double t = v.value;
      if (t <= 0.001) {
        return const SizedBox.shrink();
      }
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45 * t.clamp(0.0, 1.0)),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: safe.bottom + 10 - (1 - t) * 520,
            child: sheet!,
          ),
        ],
      );
    },
    child: Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: ShapeDecoration(
          color: c.surface,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(34),
            side: BorderSide(color: c.hairline),
          ),
        ),
        child: child,
      ),
    ),
  );
}

class _PathClip extends CustomClipper<Path> {
  const _PathClip(this.path);
  final Path path;
  @override
  Path getClip(Size size) => path;
  @override
  bool shouldReclip(_PathClip old) => true;
}

/// What is inside a blob. An app keeps its own icon, set a little way behind
/// the glass, and lends the glass its colour. A quick action is the glass.
class _Face extends StatelessWidget {
  const _Face({required this.spot, required this.size, required this.dark});
  final _Spot? spot;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final _Spot? s = spot;
    final Color tint = s?.color ?? Colors.white;
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: s == null
              ? <Color>[
                  Colors.white.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0.06),
                ]
              : <Color>[
                  Color.lerp(
                    tint,
                    Colors.white,
                    0.28,
                  )!.withValues(alpha: s.kind == _Kind.app ? 0.34 : 0.78),
                  tint.withValues(alpha: s.kind == _Kind.app ? 0.22 : 0.66),
                ],
        ),
        shape: CircleBorder(
          side: BorderSide(
            color: Colors.white.withValues(alpha: s == null ? 0.5 : 0.42),
            width: 1.2,
          ),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (s == null)
            const Icon(Icons.add_rounded, color: Colors.white, size: 26)
          else if (s.kind == _Kind.app)
            Container(
              width: size * 0.6,
              height: size * 0.6,
              decoration: ShapeDecoration(
                color: s.color,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(size * 0.17),
                ),
                shadows: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(s.icon, size: size * 0.34, color: Colors.white),
            )
          else
            Icon(s.icon, size: size * 0.42, color: Colors.white),
          // The light on top of the glass.
          Positioned(
            top: 3,
            child: Container(
              width: size * 0.62,
              height: size * 0.3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.34),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.color);
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: ShapeDecoration(
      color: color,
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white, width: 1.5),
      ),
    ),
    child: Icon(icon, size: 13, color: Colors.white),
  );
}

class _ButtonFace extends CustomPainter {
  const _ButtonFace({
    required this.open,
    required this.accent,
    required this.on,
    required this.ring,
  });
  final double open, ring;
  final Color accent, on;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;
    canvas.drawCircle(
      c + const Offset(0, 5),
      r - 2,
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, c.dy - r),
          Offset(0, c.dy + r),
          <Color>[Color.lerp(accent, Colors.white, 0.22)!, accent],
        ),
    );
    canvas.drawCircle(
      c,
      r - 0.6,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // A running rest timer shows on the button itself, so it can be read without opening anything.
    if (ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r + 5),
        -math.pi / 2,
        math.pi * 2 * ring,
        false,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    // Plus turns into a cross.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(open.clamp(0.0, 1.2) * math.pi / 4);
    final Paint p = Paint()
      ..color = on
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-11, 0), const Offset(11, 0), p);
    canvas.drawLine(const Offset(0, -11), const Offset(0, 11), p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ButtonFace old) =>
      old.open != open || old.ring != ring || old.accent != accent;
}

class _Home extends CustomPainter {
  const _Home(this.dark);
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          dark
              ? const <Color>[
                  Color(0xFF14101F),
                  Color(0xFF0B1220),
                  Color(0xFF101A16),
                ]
              : const <Color>[
                  Color(0xFFF3ECE4),
                  Color(0xFFE6EEF6),
                  Color(0xFFE9F3EC),
                ],
          const <double>[0, 0.55, 1],
        ),
    );
    // A few widgets low on the screen, where the menu opens over them.
    final double w = size.width - 32, top = size.height * 0.5;
    void tile(Rect r, Color col) => canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(26)),
      Paint()..color = col.withValues(alpha: dark ? 0.78 : 0.9),
    );
    tile(Rect.fromLTWH(16, top, w, 96), const Color(0xFFB8532F));
    tile(Rect.fromLTWH(16, top + 108, w / 2 - 6, 150), const Color(0xFF3B57B5));
    tile(
      Rect.fromLTWH(22 + w / 2, top + 108, w / 2 - 6, 69),
      const Color(0xFF1F7F78),
    );
    tile(
      Rect.fromLTWH(22 + w / 2, top + 189, w / 2 - 6, 69),
      const Color(0xFFB07A1E),
    );
  }

  @override
  bool shouldRepaint(_Home old) => old.dark != dark;
}
