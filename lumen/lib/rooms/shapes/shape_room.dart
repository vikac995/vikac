import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/shapes.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/room_header.dart';
import 'shape_loader.dart';

/// Room 03. Shapes that change on purpose: a morphing hero shape you can tap
/// or scrub, toggles that square up when selected, a button that becomes a
/// loader and then a tick, and a loading indicator.
class ShapeRoom extends StatefulWidget {
  const ShapeRoom({super.key});

  @override
  State<ShapeRoom> createState() => _ShapeRoomState();
}

class _ShapeRoomState extends State<ShapeRoom> with TickerProviderStateMixin {
  static const double _pxPerShape = 120;
  static const double _turn = math.pi / 5;

  late final SpringValue _idx = SpringValue(
    this,
    spring: Motions.expressive,
    settleDistance: 0.012,
    settleVelocity: 0.25,
  );
  late final SpringValue _press = SpringValue(
    this,
    spring: Motions.spatialFast,
  );
  double _dragFrom = 0;
  double _dragDx = 0;

  @override
  void dispose() {
    _idx.dispose();
    _press.dispose();
    super.dispose();
  }

  void _settleTo(double target, {double? velocity}) {
    _idx.onSettle = Haptics.tick;
    _idx.animateTo(target, velocity: velocity);
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final int n = ShapeLib.gallery.length;
    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 32),
        children: <Widget>[
          const RoomHeader(
            number: 3,
            title: 'Shape morph',
            hint: 'Tap the shape to step, or drag sideways to scrub through them. Everything here changes shape to say what state it is in.',
          ),
          const SizedBox(height: 18),
          // Stage.
          Listener(
            onPointerDown: (_) => _press.animateTo(1, velocity: 10),
            onPointerUp: (_) =>
                _press.animateTo(0, spring: Motions.expressiveFast),
            onPointerCancel: (_) =>
                _press.animateTo(0, spring: Motions.expressiveFast),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _settleTo(_idx.target.roundToDouble() + 1),
              onHorizontalDragStart: (_) {
                _idx.jumpTo(_idx.value);
                _dragFrom = _idx.value;
                _dragDx = 0;
              },
              onHorizontalDragUpdate: (DragUpdateDetails d) {
                _dragDx += d.delta.dx;
                _idx.jumpTo(_dragFrom - _dragDx / _pxPerShape);
              },
              onHorizontalDragEnd: (DragEndDetails d) {
                final double v = -d.velocity.pixelsPerSecond.dx / _pxPerShape;
                final double target = (_idx.value + v * 0.12).roundToDouble();
                _settleTo(target, velocity: v);
              },
              child: Container(
                height: 340,
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: c.surface,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(32),
                    side: BorderSide(color: c.hairline),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _HeroPainter(_idx, _press, c),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 18,
                      child: ListenableBuilder(
                        listenable: _idx,
                        builder: (BuildContext context, Widget? _) {
                          final double v = _idx.value;
                          final int near = v.round() % n;
                          return Column(
                            children: <Widget>[
                              Text(
                                ShapeLib.gallery[near].name,
                                style: LumenType.text(
                                  14,
                                  weight: 600,
                                  color: c.ink,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  for (int i = 0; i < n; i++)
                                    Builder(
                                      builder: (BuildContext context) {
                                        double d = (v - i) % n;
                                        d = math.min(d, n - d);
                                        final double on = (1 - d).clamp(
                                          0.0,
                                          1.0,
                                        );
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          width: 6 + 14 * on,
                                          height: 6,
                                          decoration: ShapeDecoration(
                                            color: Color.lerp(
                                              c.ink.withValues(alpha: 0.18),
                                              c.accent,
                                              on,
                                            ),
                                            shape: const StadiumBorder(),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _label(
            c,
            'Toggles',
            'Round when off, square when on. Press to squeeze.',
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _MorphToggle(
                icon: Icons.wifi_rounded,
                label: 'Wi-Fi',
                initial: true,
              ),
              _MorphToggle(
                icon: Icons.bluetooth_rounded,
                label: 'Bluetooth',
                initial: false,
              ),
              _MorphToggle(
                icon: Icons.dark_mode_rounded,
                label: 'Night',
                initial: false,
              ),
            ],
          ),
          const SizedBox(height: 30),
          _label(
            c,
            'Button',
            'Tap Send. It becomes the progress, then the result.',
          ),
          const SizedBox(height: 14),
          const Center(child: _SendButton()),
          const SizedBox(height: 30),
          _label(c, 'Loading', 'Never the same shape twice in a row.'),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              ShapeLoader(size: 64, color: c.accent),
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: c.accent.withValues(alpha: c.dark ? 0.18 : 0.14),
                  shape: const CircleBorder(),
                ),
                child: ShapeLoader(size: 50, color: c.accent),
              ),
              ShapeLoader(size: 36, color: c.ink),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(LumenColors c, String title, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title.toUpperCase(), style: LumenType.label(color: c.inkFaint)),
          const SizedBox(height: 4),
          Text(detail, style: LumenType.text(14, color: c.inkMuted)),
        ],
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  _HeroPainter(this.idx, this.press, this.colors)
    : super(repaint: Listenable.merge(<Listenable>[idx, press]));
  final SpringValue idx;
  final SpringValue press;
  final LumenColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final double v = idx.value;
    final Offset center = Offset(size.width / 2, size.height / 2 - 26);
    final double scale =
        math.min(size.width, size.height) * 0.30 * (1 - 0.07 * press.value);
    final double rot = v * _ShapeRoomState._turn;
    final Path path = ShapeLib.at(ShapeLib.gallery, v, center, scale, rot);

    canvas.drawShadow(path.shift(const Offset(0, 6)), colors.shadow, 16, false);
    final Offset dir = Offset(math.cos(rot - 0.8), math.sin(rot - 0.8)) * scale;
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          center - dir,
          center + dir,
          <Color>[
            const Color(0xFFFFA14A),
            colors.accent,
            const Color(0xFF8E7CFF),
          ],
          <double>[0, 0.45, 1],
        ),
    );
    // A soft highlight that stays put while the shape turns: reads as light.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawCircle(
      center.translate(-scale * 0.45, -scale * 0.55),
      scale * 0.75,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.35),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.colors != colors;
}

class _MorphToggle extends StatefulWidget {
  const _MorphToggle({
    required this.icon,
    required this.label,
    required this.initial,
  });
  final IconData icon;
  final String label;
  final bool initial;

  @override
  State<_MorphToggle> createState() => _MorphToggleState();
}

class _MorphToggleState extends State<_MorphToggle>
    with TickerProviderStateMixin {
  late bool _on = widget.initial;
  late final SpringValue _sel = SpringValue(
    this,
    value: _on ? 1 : 0,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _press = SpringValue(
    this,
    spring: Motions.spatialFast,
  );

  @override
  void dispose() {
    _sel.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Semantics(
      toggled: _on,
      label: widget.label,
      child: Listener(
        onPointerDown: (_) => _press.animateTo(1, velocity: 12),
        onPointerUp: (_) => _press.animateTo(0, spring: Motions.expressiveFast),
        onPointerCancel: (_) =>
            _press.animateTo(0, spring: Motions.expressiveFast),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => _on = !_on);
            _sel.onSettle = Haptics.settle;
            _sel.animateTo(_on ? 1 : 0);
          },
          child: Column(
            children: <Widget>[
              ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[_sel, _press]),
                builder: (BuildContext context, Widget? _) {
                  final double s = _sel.value;
                  final double p = _press.value;
                  final double on = s.clamp(0.0, 1.0);
                  final double radius = (ui.lerpDouble(38, 22, s)! - 12 * p)
                      .clamp(6.0, 38.0);
                  return Transform.scale(
                    scale: 1 - 0.05 * p,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: ShapeDecoration(
                        color: Color.lerp(c.surfaceHigh, c.accent, on),
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(radius),
                          side: BorderSide(
                            color: c.hairline.withValues(
                              alpha: c.hairline.a * (1 - on),
                            ),
                          ),
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 28,
                        color: Color.lerp(c.ink, c.onAccent, on),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: LumenType.text(12.5, weight: 520, color: c.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SendState { idle, sending, done }

class _SendButton extends StatefulWidget {
  const _SendButton();

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
    with TickerProviderStateMixin {
  _SendState _state = _SendState.idle;
  late final SpringValue _collapse = SpringValue(
    this,
    spring: Motions.expressive,
  );
  late final SpringValue _done = SpringValue(this, spring: Motions.effects);
  late final SpringValue _check = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _press = SpringValue(
    this,
    spring: Motions.spatialFast,
  );
  final List<Timer> _timers = <Timer>[];

  @override
  void dispose() {
    for (final Timer t in _timers) {
      t.cancel();
    }
    _collapse.dispose();
    _done.dispose();
    _check.dispose();
    _press.dispose();
    super.dispose();
  }

  void _send() {
    if (_state != _SendState.idle) {
      return;
    }
    setState(() => _state = _SendState.sending);
    _collapse.onSettle = null;
    _collapse.animateTo(1);
    _timers.add(
      Timer(const Duration(milliseconds: 2400), () {
        setState(() => _state = _SendState.done);
        _done.animateTo(1);
        _check.onSettle = Haptics.settle;
        _check.animateTo(1);
      }),
    );
    _timers.add(
      Timer(const Duration(milliseconds: 4400), () {
        setState(() => _state = _SendState.idle);
        _check.onSettle = null;
        _check.animateTo(0, spring: Motions.spatialFast);
        _done.animateTo(0);
        _collapse.animateTo(0);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final Color success = c.dark
        ? const Color(0xFF3DDC97)
        : const Color(0xFF168A57);
    return Semantics(
      button: true,
      label: switch (_state) {
        _SendState.idle => 'Send',
        _SendState.sending => 'Sending',
        _SendState.done => 'Sent',
      },
      child: Listener(
        onPointerDown: (_) {
          if (_state == _SendState.idle) {
            _press.animateTo(1, velocity: 12);
          }
        },
        onPointerUp: (_) => _press.animateTo(0, spring: Motions.expressiveFast),
        onPointerCancel: (_) =>
            _press.animateTo(0, spring: Motions.expressiveFast),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _send,
          child: SizedBox(
            width: 230,
            height: 68,
            child: Center(
              child: ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[
                  _collapse,
                  _done,
                  _check,
                  _press,
                ]),
                builder: (BuildContext context, Widget? _) {
                  final double k = _collapse.value;
                  final double d = _done.value.clamp(0.0, 1.0);
                  final double p = _press.value;
                  final double width = ui.lerpDouble(220, 64, k)!;
                  final Color fill = Color.lerp(c.accent, success, d)!;
                  final Color ink = Color.lerp(
                    c.onAccent,
                    c.dark ? const Color(0xFF052114) : Colors.white,
                    d,
                  )!;
                  final double labelA = (1 - k * 2.4).clamp(0.0, 1.0);
                  final double loaderA =
                      ((k - 0.35) * 2.2).clamp(0.0, 1.0) * (1 - d);
                  return Transform.scale(
                    scale: 1 - 0.04 * p,
                    child: Container(
                      width: width,
                      height: 64,
                      decoration: ShapeDecoration(
                        color: fill,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(32 - 8 * p),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          if (labelA > 0)
                            Opacity(
                              opacity: labelA,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'Send',
                                    style: LumenType.text(
                                      17,
                                      weight: 640,
                                      color: ink,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 20,
                                    color: ink,
                                  ),
                                ],
                              ),
                            ),
                          if (_state == _SendState.sending || loaderA > 0)
                            Opacity(
                              opacity: loaderA,
                              child: ShapeLoader(size: 30, color: ink),
                            ),
                          if (_check.value > 0.01)
                            Transform.scale(
                              scale: _check.value,
                              child: Icon(
                                Icons.check_rounded,
                                size: 30,
                                color: ink,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
