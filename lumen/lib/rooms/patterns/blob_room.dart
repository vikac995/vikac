import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/panel.dart';
import '../../widgets/room_header.dart';

class _Action {
  const _Action(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

const List<_Action> _actions = <_Action>[
  _Action('Workout', Icons.fitness_center_rounded, Color(0xFF865AC9)),
  _Action('Log food', Icons.restaurant_rounded, Color(0xFFD16944)),
  _Action('Scan', Icons.qr_code_scanner_rounded, Color(0xFF2F978F)),
  _Action('Weigh-in', Icons.monitor_weight_outlined, Color(0xFF4E6CC4)),
  _Action('Timer', Icons.timer_outlined, Color(0xFFD0892D)),
];

/// Room 21. One button that splits into a few actions. Tap to open and tap
/// an action, or press, slide and release in one movement.
class BlobRoom extends StatefulWidget {
  const BlobRoom({super.key});

  @override
  State<BlobRoom> createState() => _BlobRoomState();
}

class _BlobRoomState extends State<BlobRoom> with TickerProviderStateMixin {
  static const double _radius = 156, _blob = 58, _button = 68;

  int _count = 5;
  bool _open = false;
  int? _hover;
  String? _picked;
  bool _moved = false;
  late final List<SpringValue> _out = <SpringValue>[
    for (int i = 0; i < 5; i++) SpringValue(this, spring: Motions.expressive),
  ];
  late final SpringValue _main = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _pickedIn = SpringValue(
    this,
    spring: Motions.expressive,
  );
  final List<Timer> _timers = <Timer>[];

  @override
  void dispose() {
    for (final Timer t in _timers) {
      t.cancel();
    }
    for (final SpringValue s in _out) {
      s.dispose();
    }
    _main.dispose();
    _pickedIn.dispose();
    super.dispose();
  }

  void _setOpen(bool open) {
    if (open == _open) {
      return;
    }
    setState(() {
      _open = open;
      _hover = null;
    });
    _main.animateTo(open ? 1 : 0);
    for (final Timer t in _timers) {
      t.cancel();
    }
    _timers.clear();
    for (int i = 0; i < _count; i++) {
      // Out: one after another from the left. In: all together, quickly.
      if (open) {
        _timers.add(
          Timer(
            Duration(milliseconds: 34 * i),
            () => _out[i].animateTo(1, spring: Motions.expressive),
          ),
        );
      } else {
        _out[i].animateTo(0, spring: Motions.spatialFast);
      }
    }
    Haptics.tick();
  }

  void _pick(int i) {
    setState(() => _picked = _actions[i].label);
    _pickedIn.jumpTo(0);
    _pickedIn.animateTo(1);
    Haptics.settle();
    _setOpen(false);
  }

  /// Where blob [i] rests, relative to the main button's centre.
  Offset _slot(int i) {
    final double a = math.pi + math.pi * (i + 0.5) / _count;
    return Offset(math.cos(a), math.sin(a)) * _radius;
  }

  int? _blobAt(Offset fromCentre) {
    for (int i = 0; i < _count; i++) {
      if ((fromCentre - _slot(i)).distance < _blob * 0.62) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 21,
          title: 'Blob menu',
          hint:
              'Pattern: one button for the few things people do most. Tap it, then tap an action. '
              'Or press it, slide to an action and let go, all in one movement.',
        ),
        const SizedBox(height: 16),
        Panel(
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 430,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                final Offset centre = Offset(box.maxWidth / 2, 430 - 64);
                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (PointerDownEvent e) {
                    _moved = false;
                    if ((e.localPosition - centre).distance < _button * 0.7) {
                      _setOpen(!_open);
                    } else if (_open &&
                        _blobAt(e.localPosition - centre) == null) {
                      _setOpen(false);
                    }
                  },
                  onPointerMove: (PointerMoveEvent e) {
                    if (!_open) {
                      return;
                    }
                    _moved = true;
                    final int? h = _blobAt(e.localPosition - centre);
                    if (h != _hover) {
                      setState(() => _hover = h);
                      if (h != null) {
                        Haptics.tick();
                      }
                    }
                  },
                  onPointerUp: (PointerUpEvent e) {
                    if (!_open) {
                      return;
                    }
                    final int? h = _blobAt(e.localPosition - centre);
                    if (h != null) {
                      _pick(h);
                    } else if (_moved &&
                        (e.localPosition - centre).distance > _button) {
                      _setOpen(false);
                    }
                    setState(() => _hover = null);
                  },
                  // Claims drags, so sliding to an action never scrolls the page.
                  child: GestureDetector(
                    onVerticalDragUpdate: (_) {},
                    onHorizontalDragUpdate: (_) {},
                    child: ListenableBuilder(
                      listenable: Listenable.merge(<Listenable>[
                        ..._out,
                        _main,
                        _pickedIn,
                      ]),
                      builder: (BuildContext context, Widget? _) {
                        final double m = _main.value;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            // The page behind dims while the menu is open.
                            Positioned.fill(
                              child: ColoredBox(
                                color: Colors.black.withValues(
                                  alpha: 0.28 * m.clamp(0.0, 1.0),
                                ),
                              ),
                            ),
                            if (_picked != null)
                              Positioned(
                                top: 22,
                                left: 0,
                                right: 0,
                                child: Opacity(
                                  opacity: _pickedIn.value.clamp(0.0, 1.0),
                                  child: Transform.translate(
                                    offset: Offset(
                                      0,
                                      10 * (1 - _pickedIn.value),
                                    ),
                                    child: Text(
                                      'Opened: $_picked',
                                      textAlign: TextAlign.center,
                                      style: LumenType.text(
                                        15,
                                        weight: 620,
                                        color: c.ink,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // The stretch between the button and each blob as it leaves.
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _Necks(
                                  centre,
                                  <Offset>[
                                    for (int i = 0; i < _count; i++)
                                      _slot(i) * _out[i].value,
                                  ],
                                  <double>[
                                    for (int i = 0; i < _count; i++)
                                      _out[i].value,
                                  ],
                                  <Color>[
                                    for (int i = 0; i < _count; i++)
                                      _actions[i].color,
                                  ],
                                ),
                              ),
                            ),
                            for (int i = 0; i < _count; i++)
                              _blobWidget(c, i, centre),
                            Positioned(
                              left: centre.dx - _button / 2,
                              top: centre.dy - _button / 2,
                              child: Transform.scale(
                                scale: 1 - 0.08 * m,
                                child: Container(
                                  width: _button,
                                  height: _button,
                                  decoration: ShapeDecoration(
                                    color: c.accent,
                                    shape: const CircleBorder(),
                                    shadows: <BoxShadow>[
                                      BoxShadow(
                                        color: c.shadow,
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Transform.rotate(
                                    angle: m * math.pi / 4,
                                    child: Icon(
                                      Icons.add_rounded,
                                      size: 34,
                                      color: c.onAccent,
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
              },
            ),
          ),
        ),
        const SectionLabel(
          'How many actions',
          detail: 'Five is the limit: more and the labels start to touch.',
        ),
        Segmented<int>(
          values: const <int>[3, 4, 5],
          labels: const <String>['Three', 'Four', 'Five'],
          value: _count,
          onChanged: (int v) {
            _setOpen(false);
            setState(() => _count = v);
          },
        ),
      ],
    );
  }

  Widget _blobWidget(LumenColors c, int i, Offset centre) {
    final double v = _out[i].value;
    if (v < 0.02) {
      return const SizedBox.shrink();
    }
    final Offset p = centre + _slot(i) * v;
    final bool hot = _hover == i;
    final double size =
        _blob * (0.45 + 0.55 * v.clamp(0.0, 1.15)) * (hot ? 1.16 : 1);
    return Positioned(
      left: p.dx - 38,
      top: p.dy - size / 2,
      width: 76,
      child: Column(
        children: <Widget>[
          Container(
            width: size,
            height: size,
            decoration: ShapeDecoration(
              color: _actions[i].color,
              shape: CircleBorder(
                side: BorderSide(
                  color: Colors.white.withValues(alpha: hot ? 0.9 : 0.18),
                  width: hot ? 2 : 1,
                ),
              ),
            ),
            child: Icon(
              _actions[i].icon,
              color: Colors.white,
              size: size * 0.44,
            ),
          ),
          const SizedBox(height: 6),
          Opacity(
            opacity: ((v - 0.6) * 2.5).clamp(0.0, 1.0),
            child: Text(
              _actions[i].label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: LumenType.text(
                12,
                weight: hot ? 700 : 600,
                color: c.ink,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Necks extends CustomPainter {
  const _Necks(this.centre, this.offsets, this.amounts, this.colors);
  final Offset centre;
  final List<Offset> offsets;
  final List<double> amounts;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < offsets.length; i++) {
      final double v = amounts[i];
      // Thick while close, thinning to nothing as the blob pulls away.
      final double w = 30 * (1 - v).clamp(0.0, 1.0) * (v > 0.02 ? 1 : 0);
      if (w < 0.5) {
        continue;
      }
      canvas.drawLine(
        centre,
        centre + offsets[i],
        Paint()
          ..color = colors[i]
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_Necks old) => true;
}
