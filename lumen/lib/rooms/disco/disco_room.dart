import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/glass.dart';
import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/room_header.dart';

/// Room 07, the bonus. Discomorphism: every surface is a mirror ball.
class DiscoRoom extends StatefulWidget {
  const DiscoRoom({super.key});

  @override
  State<DiscoRoom> createState() => _DiscoRoomState();
}

class _DiscoRoomState extends State<DiscoRoom> with TickerProviderStateMixin {
  static const int _cols = 5, _rows = 6;

  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((Duration e) {
    final double t = e.inMicroseconds / 1e6;
    final double dt = (t - _time.value).clamp(0.0, 0.1);
    _spin += dt * (Motion.reduced ? 0.12 : 0.25 + 0.55 * _party.value);
    _time.value = t;
  });
  double _spin = 0;
  late final SpringValue _party = SpringValue(
    this,
    value: 0.25,
    spring: Motions.effectsSlow,
  );
  late final SpringValue _beat = SpringValue(this, spring: Motions.effects);
  late final SpringValue _press = SpringValue(
    this,
    spring: Motions.spatialFast,
  );
  bool _on = false;
  bool _feel = true;
  Timer? _beatTimer;
  ui.FragmentShader? _shader;

  /// When each dance-floor tile was last lit, and in which colour.
  final List<double> _hit = List<double>.filled(_cols * _rows, -10);
  final List<double> _hue = List<double>.filled(_cols * _rows, 0);
  int _lastTile = -1;
  final math.Random _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _shader = GlassShaders.disco?.fragmentShader();
    _ticker.start();
  }

  @override
  void dispose() {
    _beatTimer?.cancel();
    _ticker.dispose();
    _time.dispose();
    _party.dispose();
    _beat.dispose();
    _press.dispose();
    _shader?.dispose();
    super.dispose();
  }

  void _toggleParty() {
    setState(() => _on = !_on);
    _party.animateTo(_on ? 1 : 0.25);
    _beatTimer?.cancel();
    if (_on) {
      Haptics.thud();
      // 120 beats per minute.
      _beatTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _onBeat(),
      );
    }
  }

  void _onBeat() {
    _beat.jumpTo(1);
    _beat.animateTo(0);
    if (_feel) {
      Haptics.tick();
    }
    final double now = _time.value;
    final double h = _rnd.nextDouble();
    for (int k = 0; k < 6; k++) {
      final int i = _rnd.nextInt(_hit.length);
      _hit[i] = now;
      _hue[i] = h + k * 0.08;
    }
  }

  void _touchFloor(Offset local, Size size) {
    final int cx = (local.dx / size.width * _cols).floor();
    final int cy = (local.dy / size.height * _rows).floor();
    if (cx < 0 || cy < 0 || cx >= _cols || cy >= _rows) {
      return;
    }
    final int i = cy * _cols + cx;
    _hit[i] = _time.value;
    _hue[i] = (_time.value * 0.15 + i * 0.07) % 1;
    if (i != _lastTile) {
      _lastTile = i;
      Haptics.tick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Size screen = MediaQuery.sizeOf(context);
    final Offset ball = Offset(screen.width / 2, safe.top + 250);
    final double radius = math.min(screen.width * 0.27, 118);
    const LumenColors c = LumenColors.night;

    return Theme(
      // The club is dark whatever the app's theme.
      data: lumenTheme(c),
      child: Scaffold(
        backgroundColor: const Color(0xFF06050B),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (_shader != null)
              RepaintBoundary(
                child: CustomPaint(
                  painter: _DiscoPainter(_shader!, this, ball, radius),
                ),
              ),
            Positioned(
              top: safe.top + 44,
              left: 16,
              right: 16,
              child: const RoomHeader(number: 7, title: 'Discomorphism'),
            ),
            Positioned(
              top: ball.dy + radius + 26,
              left: 16,
              right: 16,
              child: Column(
                children: <Widget>[
                  _ChromeTitle(time: _time),
                  const SizedBox(height: 6),
                  Text(
                    'The design trend nobody asked for. Every surface reflects.',
                    textAlign: TextAlign.center,
                    style: LumenType.text(14, color: const Color(0xFFB9B4CC)),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _MirrorButton(
                        on: _on,
                        time: _time,
                        press: _press,
                        onTap: _toggleParty,
                      ),
                      const SizedBox(width: 18),
                      Column(
                        children: <Widget>[
                          LumenSwitch(
                            value: _feel,
                            onChanged: (bool v) => setState(() => _feel = v),
                          ),
                          Text(
                            'Feel the beat',
                            style: LumenType.text(
                              12,
                              weight: 560,
                              color: const Color(0xFFB9B4CC),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // The dance floor, tipped back in perspective.
            Positioned(
              left: 0,
              right: 0,
              bottom: safe.bottom + 6,
              height: 230,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0016)
                  ..rotateX(0.95),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) {
                      final Size size = box.biggest;
                      return Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (PointerDownEvent e) =>
                            _touchFloor(e.localPosition, size),
                        onPointerMove: (PointerMoveEvent e) =>
                            _touchFloor(e.localPosition, size),
                        onPointerUp: (_) => _lastTile = -1,
                        child: CustomPaint(
                          size: size,
                          painter: _FloorPainter(this),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoPainter extends CustomPainter {
  _DiscoPainter(this.shader, this.room, this.ball, this.radius)
    : super(
        repaint: Listenable.merge(<Listenable>[
          room._time,
          room._party,
          room._beat,
        ]),
      );
  final ui.FragmentShader shader;
  final _DiscoRoomState room;
  final Offset ball;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, room._time.value)
      ..setFloat(3, ball.dx)
      ..setFloat(4, ball.dy)
      ..setFloat(5, radius)
      ..setFloat(6, room._party.value)
      ..setFloat(7, room._beat.value.clamp(0.0, 1.0))
      ..setFloat(8, room._spin);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_DiscoPainter old) =>
      old.ball != ball || old.radius != radius;
}

class _FloorPainter extends CustomPainter {
  _FloorPainter(this.room) : super(repaint: room._time);
  final _DiscoRoomState room;

  static Color _hue(double h, double v) =>
      HSVColor.fromAHSV(1, (h % 1) * 360, 0.75, v.clamp(0.0, 1.0)).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    const int cols = _DiscoRoomState._cols, rows = _DiscoRoomState._rows;
    final double w = size.width / cols, h = size.height / rows;
    final double now = room._time.value;
    final double party = room._party.value;
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final int i = y * cols + x;
        final double lit = math.exp(-(now - room._hit[i]) * 2.4);
        final double idle =
            0.08 +
            0.05 * party * (0.5 + 0.5 * math.sin(now * 2 + x * 0.9 + y * 1.3));
        final Rect r = Rect.fromLTWH(x * w + 3, y * h + 3, w - 6, h - 6);
        final RRect rr = RRect.fromRectAndRadius(r, const Radius.circular(6));
        canvas.drawRRect(
          rr,
          Paint()..color = _hue(room._hue[i], idle + 0.85 * lit),
        );
        if (lit > 0.05) {
          canvas.drawRRect(
            rr,
            Paint()
              ..color = _hue(room._hue[i], 1).withValues(alpha: 0.6 * lit)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * lit),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_FloorPainter old) => false;
}

/// Chrome lettering with a highlight that sweeps across it.
class _ChromeTitle extends StatelessWidget {
  const _ChromeTitle({required this.time});
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: time,
      builder: (BuildContext context, Widget? child) {
        final double t = time.value;
        final double sweep = (t * 0.35) % 1.6 - 0.3;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect r) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              const Color(0xFF8E8AA0),
              const Color(0xFFF4F2FF),
              const Color(0xFF6E6880),
              const Color(0xFFFFFFFF),
              HSVColor.fromAHSV(1, (t * 40) % 360, 0.5, 1).toColor(),
              const Color(0xFF7C7790),
            ],
            stops: <double>[
              0,
              (sweep - 0.12).clamp(0.01, 0.97),
              (sweep - 0.04).clamp(0.02, 0.98),
              sweep.clamp(0.03, 0.985),
              (sweep + 0.06).clamp(0.04, 0.99),
              1,
            ],
          ).createShader(r),
          child: child,
        );
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'Discomorphism',
          style: LumenType.display(
            44,
            weight: 800,
            width: 88,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// A button tiled with tiny mirrors that catch the light.
class _MirrorButton extends StatelessWidget {
  const _MirrorButton({
    required this.on,
    required this.time,
    required this.press,
    required this.onTap,
  });
  final bool on;
  final ValueNotifier<double> time;
  final SpringValue press;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      label: 'Party mode',
      child: Listener(
        onPointerDown: (_) => press.animateTo(1, velocity: 12),
        onPointerUp: (_) => press.animateTo(0, spring: Motions.expressiveFast),
        onPointerCancel: (_) =>
            press.animateTo(0, spring: Motions.expressiveFast),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[time, press]),
            builder: (BuildContext context, Widget? label) => Transform.scale(
              scale: 1 - 0.06 * press.value,
              child: CustomPaint(
                painter: _MirrorTiles(time.value, on),
                child: SizedBox(
                  width: 190,
                  height: 60,
                  child: Center(child: label),
                ),
              ),
            ),
            child: Text(
              on ? 'Party mode: ON' : 'Party mode',
              style: LumenType.text(16, weight: 760, color: Colors.white)
                  .copyWith(
                    shadows: const <Shadow>[
                      Shadow(color: Color(0xCC000000), blurRadius: 6),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MirrorTiles extends CustomPainter {
  const _MirrorTiles(this.t, this.on);
  final double t;
  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF2A2734),
    );
    const double tile = 9;
    int k = 0;
    for (double y = 0; y < size.height; y += tile) {
      for (double x = 0; x < size.width; x += tile) {
        k++;
        final double ph = (k * 12.9898).remainder(6.283);
        final double b =
            0.25 +
            0.75 *
                math
                    .pow(
                      0.5 + 0.5 * math.sin(t * (on ? 5 : 1.6) + ph + x * 0.03),
                      6,
                    )
                    .toDouble();
        final Color col = on
            ? HSVColor.fromAHSV(
                1,
                (x * 1.4 + t * 90 + y * 2) % 360,
                0.55,
                b,
              ).toColor()
            : Color.lerp(const Color(0xFF5A566A), Colors.white, b)!;
        canvas.drawRect(
          Rect.fromLTWH(x + 0.6, y + 0.6, tile - 1.2, tile - 1.2),
          Paint()..color = col,
        );
      }
    }
    canvas.restore();
    canvas.drawRRect(
      shape.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_MirrorTiles old) => old.t != t || old.on != on;
}
