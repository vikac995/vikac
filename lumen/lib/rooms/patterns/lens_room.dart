import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/glass.dart';
import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';

/// Something on the screen the lens can explain.
class _Thing {
  const _Thing(this.title, this.explain, this.color, {this.icon, this.value});
  final String title, explain;
  final Color color;
  final IconData? icon;
  final String? value;
}

const List<_Thing> _blobs = <_Thing>[
  _Thing(
    'Workout',
    'Starts today\'s workout: push day, five exercises.',
    Color(0xFF865AC9),
    icon: Icons.fitness_center_rounded,
  ),
  _Thing(
    'Log food',
    'Search, or pick something you ate recently.',
    Color(0xFFD16944),
    icon: Icons.restaurant_rounded,
  ),
  _Thing(
    'Scan',
    'Point the camera at a barcode to log that food.',
    Color(0xFF2F978F),
    icon: Icons.qr_code_scanner_rounded,
  ),
  _Thing(
    'Weigh-in',
    'Log this morning\'s weight in one step.',
    Color(0xFF4E6CC4),
    icon: Icons.monitor_weight_outlined,
  ),
  _Thing(
    'Timer',
    'Count down, count up, or run intervals.',
    Color(0xFFD0892D),
    icon: Icons.timer_outlined,
  ),
];
const List<_Thing> _tiles = <_Thing>[
  _Thing(
    'Kcal left',
    'What you can still eat today. It goes down as you log food.',
    Color(0xFFB8532F),
    value: '1,160',
  ),
  _Thing(
    'Weight',
    'Your trend over seven days, smoothed so one heavy dinner does not show as a setback.',
    Color(0xFF3B57B5),
    value: '81.8 kg',
  ),
  _Thing(
    'Weigh-in',
    'A shortcut: one tap logs today\'s weight.',
    Color(0xFF1F7F78),
    value: 'Tue',
  ),
  _Thing(
    'Protein shake',
    'A saved food. One tap adds 160 kcal to today.',
    Color(0xFFB07A1E),
    value: '160 kcal',
  ),
  _Thing(
    'Today\'s list',
    'Habits and tasks for today. Cross them off, or skip them.',
    Color(0xFF6B45B0),
    value: '0 / 2',
  ),
];
const List<_Thing> _spots = <_Thing>[
  _Thing(
    'Phone',
    'A spot on the bar. This one opens the phone app; you choose what each spot does.',
    Color(0xFF6C7689),
    icon: Icons.phone_rounded,
  ),
  _Thing(
    'Messages',
    'A spot on the bar. This one opens your messages.',
    Color(0xFF6C7689),
    icon: Icons.chat_bubble_rounded,
  ),
  _Thing(
    'Camera',
    'A spot on the bar. This one opens the camera.',
    Color(0xFF6C7689),
    icon: Icons.photo_camera_rounded,
  ),
  _Thing(
    'Apps',
    'Every app on the phone, and Gym Buddy\'s own screens.',
    Color(0xFF6C7689),
    icon: Icons.apps_rounded,
  ),
];

/// Room 51. One button, two jobs. Tap it and it stays a plain coloured
/// button that splits into five blobs. Drag it and it lifts off the bar as
/// a magnifying glass: things swell as it approaches and explain themselves
/// while it is over them.
class LensRoom extends StatefulWidget {
  const LensRoom({super.key});

  @override
  State<LensRoom> createState() => _LensRoomState();
}

class _LensRoomState extends State<LensRoom> with TickerProviderStateMixin {
  static const double _button = 68, _blob = 62, _reach = 186, _lensSize = 96;
  final GlobalKey _stageKey = GlobalKey();
  Size _stage = Size.zero;
  double _bottom = 0;
  bool _open = false, _carrying = false, _moved = false;
  Offset? _downAt;
  int _target = -1; // index into the list returned by _things(), or -1
  _Thing? _launched;

  late final SpringValue _t = SpringValue(this, spring: Motions.spatialFast);
  late final List<SpringValue> _out = <SpringValue>[
    for (int i = 0; i < 5; i++) SpringValue(this),
  ];
  late final SpringValue _kick = SpringValue(
    this,
    value: 1,
    spring: Motions.expressiveFast,
  );
  // The lens: how far it has turned from button into glass, and where it is.
  late final SpringValue _glass = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _lx = SpringValue(this, spring: Motions.follow);
  late final SpringValue _ly = SpringValue(this, spring: Motions.follow);
  late final SpringValue _say = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _sheet = SpringValue(this, spring: Motions.spatial);
  late final Listenable _all = Listenable.merge(<Listenable>[
    _t,
    _kick,
    _glass,
    _lx,
    _ly,
    _say,
    ..._out,
  ]);
  final List<Timer> _fuses = <Timer>[];
  static final SpringDescription _shoot = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 950,
    ratio: 0.62,
  );

  @override
  void dispose() {
    for (final Timer t in _fuses) {
      t.cancel();
    }
    for (final SpringValue s in <SpringValue>[
      _t,
      _kick,
      _glass,
      _lx,
      _ly,
      _say,
      _sheet,
      ..._out,
    ]) {
      s.dispose();
    }
    super.dispose();
  }

  // Geometry, in stage coordinates.
  Offset get _c => Offset(_stage.width / 2, _stage.height - _bottom - 52);
  Offset _blobRest(int i) {
    final double a = math.pi * (0.19 + 0.62 * i / 4);
    return _c + Offset(-math.cos(a), -math.sin(a)) * _reach;
  }

  Offset _blobAt(int i) => _c + (_blobRest(i) - _c) * _out[i].value;
  List<Rect> get _tileRects {
    final double w = _stage.width - 32, top = _stage.height * 0.30;
    return <Rect>[
      Rect.fromLTWH(16, top, w, 92),
      Rect.fromLTWH(16, top + 104, w / 2 - 6, 150),
      Rect.fromLTWH(22 + w / 2, top + 104, w / 2 - 6, 69),
      Rect.fromLTWH(22 + w / 2, top + 185, w / 2 - 6, 69),
      Rect.fromLTWH(16, top + 266, w, 70),
    ];
  }

  List<Rect> get _spotRects {
    final double w = (_stage.width - 32 - _button) / 4;
    return <Rect>[
      for (int i = 0; i < 4; i++)
        Rect.fromCenter(
          center: Offset(16 + w * (i + 0.5) + (i > 1 ? _button : 0), _c.dy),
          width: 52,
          height: 52,
        ),
    ];
  }

  /// Everything the lens can explain right now, with where it is.
  List<(_Thing, Rect)> _things() => <(_Thing, Rect)>[
    for (int i = 0; i < 5; i++) (_tiles[i], _tileRects[i]),
    for (int i = 0; i < 4; i++) (_spots[i], _spotRects[i]),
    if (_open)
      for (int i = 0; i < 5; i++)
        (_blobs[i], Rect.fromCircle(center: _blobRest(i), radius: _blob / 2)),
  ];

  Offset get _lens => Offset(_lx.value, _ly.value);

  /// How strongly a thing reacts to the lens: 0 far away, 1 when the lens is on it.
  double _near(Rect r) {
    if (_glass.value < 0.05) {
      return 0;
    }
    final Offset p = _lens;
    final double dx = math.max(0, math.max(r.left - p.dx, p.dx - r.right));
    final double dy = math.max(0, math.max(r.top - p.dy, p.dy - r.bottom));
    final double t = (1 - math.sqrt(dx * dx + dy * dy) / 64).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t) * _glass.value.clamp(0.0, 1.0);
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
        // The middle blob leaves first; each step outward waits 14 ms.
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

  Offset _local(Offset global) =>
      (_stageKey.currentContext!.findRenderObject()! as RenderBox)
          .globalToLocal(global);

  void _down(PointerDownEvent e) {
    _downAt = _local(e.position);
    _moved = false;
    _kick.animateTo(0.92);
  }

  void _move(PointerMoveEvent e) {
    if (_downAt == null) {
      return;
    }
    final Offset p = _local(e.position);
    if (!_moved) {
      if ((p - _downAt!).distance < 10) {
        return;
      }
      // The button lifts off: from here on it is a lens.
      _moved = true;
      setState(() => _carrying = true);
      _lx.jumpTo(_c.dx);
      _ly.jumpTo(_c.dy);
      _glass.animateTo(1);
      _kick.animateTo(1);
      Haptics.settle();
    }
    // The glass rides above the thumb so the thumb does not cover it.
    _lx.animateTo(p.dx.clamp(_lensSize / 2, _stage.width - _lensSize / 2));
    _ly.animateTo(
      (p.dy - 62).clamp(_lensSize / 2 + 30, _stage.height - _lensSize / 2),
    );
  }

  void _up(PointerEvent e) {
    _kick.animateTo(1);
    if (_downAt == null) {
      return;
    }
    _downAt = null;
    if (_moved) {
      // Back to the bar, and back to being a button.
      setState(() => _carrying = false);
      _lx.animateTo(_c.dx, spring: Motions.expressive);
      _ly.animateTo(_c.dy, spring: Motions.expressive);
      _glass.animateTo(0);
      _retarget(-1);
      Haptics.tick();
    } else {
      _setOpen(!_open);
    }
  }

  void _retarget(int i) {
    if (i == _target) {
      return;
    }
    // Called while building, so the change waits for the frame to finish.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || i == _target) {
        return;
      }
      setState(() => _target = i);
      if (i >= 0) {
        _say.jumpTo(0.6);
        _say.animateTo(1);
        Haptics.tick();
      } else {
        _say.animateTo(0, spring: Motions.spatialFast);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    _bottom = safe.bottom;
    return Scaffold(
      backgroundColor: c.bg,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          _stage = box.biggest;
          return ListenableBuilder(
            listenable: _all,
            builder: (BuildContext context, Widget? _) {
              final List<(_Thing, Rect)> things = _things();
              // Which thing is the lens on? The nearest one it is properly over.
              int best = -1;
              double bestNear = 0.86;
              for (int i = 0; i < things.length; i++) {
                final double n = _near(things[i].$2);
                if (n > bestNear) {
                  bestNear = n;
                  best = i;
                }
              }
              if (_carrying) {
                _retarget(best);
              }
              final double g = _glass.value.clamp(0.0, 1.0);
              final double size =
                  ui.lerpDouble(_button, _lensSize, _glass.value)! *
                  _kick.value;
              final Offset at = _carrying || g > 0.01 ? _lens : _c;
              final Rect lens = Rect.fromCenter(
                center: at,
                width: size,
                height: size,
              );
              final List<Rect> tr = _tileRects, sr = _spotRects;
              return Stack(
                key: _stageKey,
                children: <Widget>[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: c.dark
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
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: safe.top + 44,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const RoomHeader(number: 51, title: 'Button and lens'),
                        const SizedBox(height: 10),
                        Text(
                          'Tap the button for your five actions. Drag it anywhere and it becomes a magnifying glass that explains what it is over.',
                          style: LumenType.text(
                            14,
                            color: c.inkMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The home screen's widgets. Each one swells as the lens comes near.
                  for (int i = 0; i < 5; i++)
                    Positioned.fromRect(
                      rect: tr[i],
                      child: _Tile(
                        _tiles[i],
                        near: _near(tr[i]),
                        graph: i == 1,
                        dark: c.dark,
                      ),
                    ),
                  // Dim behind the blobs; a tap closes.
                  IgnorePointer(
                    ignoring: !_open,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _setOpen(false),
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: 0.42 * _t.value.clamp(0.0, 1.0),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  // The bar and its four spots.
                  Positioned(
                    left: 16,
                    right: 16,
                    top: _c.dy - 32,
                    height: 64,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: c.surfaceHigh.withValues(alpha: 0.92),
                        shape: StadiumBorder(
                          side: BorderSide(color: c.hairline),
                        ),
                      ),
                    ),
                  ),
                  for (int i = 0; i < 4; i++)
                    Positioned.fromRect(
                      rect: sr[i],
                      child: Transform.scale(
                        scale: 1 + 0.28 * _near(sr[i]),
                        child: Icon(
                          _spots[i].icon,
                          color: Color.lerp(c.inkMuted, c.ink, _near(sr[i])),
                        ),
                      ),
                    ),
                  // Where the button lives while it is away.
                  Positioned.fromRect(
                    rect: Rect.fromCircle(center: _c, radius: _button / 2 - 4),
                    child: Opacity(
                      opacity: g,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: CircleBorder(
                            side: BorderSide(color: c.inkFaint, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The blobs.
                  for (int i = 0; i < 5; i++)
                    Builder(
                      builder: (BuildContext context) {
                        final double p = _out[i].value;
                        final Offset b = _blobAt(i);
                        final double near = _near(
                          Rect.fromCircle(
                            center: _blobRest(i),
                            radius: _blob / 2,
                          ),
                        );
                        // Stretch along the line of flight, from the blob's speed.
                        final double st = (_out[i].velocity.abs() * 0.028)
                            .clamp(0.0, 0.34);
                        final Offset dir = _blobRest(i) - _c;
                        final double ang = math.atan2(dir.dy, dir.dx);
                        final double s = (0.5 + 0.5 * p) * (1 + 0.2 * near);
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
                                onTap: () {
                                  setState(() => _launched = _blobs[i]);
                                  _setOpen(false);
                                  _sheet.animateTo(1);
                                  Haptics.settle();
                                },
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
                                                _blobs[i].color,
                                                Colors.white,
                                                0.12,
                                              )!,
                                              _blobs[i].color,
                                            ],
                                          ),
                                          shape: CircleBorder(
                                            side: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.18 + 0.6 * near,
                                              ),
                                              width: 1 + near,
                                            ),
                                          ),
                                        ),
                                        child: Icon(
                                          _blobs[i].icon,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      _blobs[i].title,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.visible,
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
                  // The button. A plain coloured disc until it is carried; then real glass.
                  Positioned.fromRect(
                    rect: lens,
                    child: IgnorePointer(
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          if (g > 0.02)
                            Glass(
                              radius: size / 2,
                              style: GlassStyle(
                                blur: 0.8,
                                tint: 0.05,
                                refraction: 19,
                                bevel: 13,
                                dispersion: 0.16,
                                magnify: 1.2,
                                light: 0.95,
                                saturation: 1.35,
                                adapt: 0.3,
                                shadow: 0.9,
                                fallbackColor: c.accent,
                              ),
                            ),

                          if (g < 0.98)
                            Opacity(
                              opacity: 1 - g,
                              child: CustomPaint(
                                painter: _Solid(
                                  open: _t.value,
                                  accent: c.accent,
                                  on: c.onAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // What the lens says about the thing under it.
                  if (_target >= 0 && _target < things.length)
                    Builder(
                      builder: (BuildContext context) {
                        final _Thing th = things[_target].$1;
                        const double w = 268;
                        // Above the glass, unless there is no room; then below the thumb.
                        final bool above = lens.top > safe.top + 150;
                        return Positioned(
                          left: (at.dx - w / 2).clamp(
                            12.0,
                            _stage.width - w - 12,
                          ),
                          top: above ? null : lens.bottom + 96,
                          bottom: above ? _stage.height - lens.top + 12 : null,
                          width: w,
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
                                        color: th.color.withValues(alpha: 0.7),
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
                                      Row(
                                        children: <Widget>[
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: ShapeDecoration(
                                              color: th.color,
                                              shape: const CircleBorder(),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              th.title,
                                              style: LumenType.text(
                                                15.5,
                                                weight: 700,
                                                color: c.ink,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        th.explain,
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
                        );
                      },
                    ),
                  // The button's touch target, always at its home on the bar.
                  Positioned(
                    left: _c.dx - 44,
                    top: _c.dy - 44,
                    width: 88,
                    height: 88,
                    child: Semantics(
                      button: true,
                      label: 'Actions. Drag to explain what is on screen.',
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _down,
                        onPointerMove: _move,
                        onPointerUp: _up,
                        onPointerCancel: _up,
                      ),
                    ),
                  ),
                  // A blob's action opens as a small window over the home screen.
                  ListenableBuilder(
                    listenable: _sheet,
                    builder: (BuildContext context, Widget? _) {
                      final double t = _sheet.value;
                      final _Thing? s = _launched;
                      if (t <= 0.001 || s == null) {
                        return const SizedBox.shrink();
                      }
                      return Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () => _sheet.animateTo(0),
                              child: ColoredBox(
                                color: Colors.black.withValues(
                                  alpha: 0.45 * t.clamp(0.0, 1.0),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: safe.bottom + 10 - (1 - t) * 320,
                            child: Material(
                              type: MaterialType.transparency,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: ShapeDecoration(
                                  color: c.surface,
                                  shape: RoundedSuperellipseBorder(
                                    borderRadius: BorderRadius.circular(34),
                                    side: BorderSide(color: c.hairline),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: ShapeDecoration(
                                            color: s.color,
                                            shape: const CircleBorder(),
                                          ),
                                          child: Icon(
                                            s.icon,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            s.title,
                                            style: LumenType.display(
                                              24,
                                              weight: 700,
                                              color: c.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      s.explain,
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
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// A widget on the stand-in home screen.
class _Tile extends StatelessWidget {
  const _Tile(
    this.t, {
    required this.near,
    required this.graph,
    required this.dark,
  });
  final _Thing t;
  final double near;
  final bool graph, dark;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: 1 + 0.045 * near,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: ShapeDecoration(
        color: Color.lerp(
          t.color,
          Colors.white,
          0.10 * near,
        )!.withValues(alpha: dark ? 0.9 : 0.96),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.75 * near),
            width: 2 * near,
          ),
        ),
        shadows: near > 0.05
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35 * near),
                  blurRadius: 24 * near,
                  offset: Offset(0, 10 * near),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: LumenType.text(
                  13,
                  weight: 600,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              Text(
                t.value ?? '',
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: LumenType.display(
                  24,
                  weight: 720,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
            ],
          ),
          if (graph)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 4,
              height: 62,
              child: CustomPaint(painter: _Graph()),
            ),
        ],
      ),
    ),
  );
}

class _Graph extends CustomPainter {
  const _Graph();

  @override
  void paint(Canvas canvas, Size size) {
    const List<double> v = <double>[0.2, 0.5, 0.35, 0.6, 0.45, 0.4, 0.75, 0.9];
    final Path p = Path();
    for (int i = 0; i < v.length; i++) {
      final Offset o = Offset(
        size.width * i / (v.length - 1),
        size.height * v[i],
      );
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Graph old) => false;
}

/// The button at rest: one flat colour, a plus that turns into a cross.
class _Solid extends CustomPainter {
  const _Solid({required this.open, required this.accent, required this.on});
  final double open;
  final Color accent, on;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;
    canvas.drawCircle(
      c + const Offset(0, 5),
      r - 3,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(c, r, Paint()..color = accent);
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
  bool shouldRepaint(_Solid old) => old.open != open || old.accent != accent;
}
