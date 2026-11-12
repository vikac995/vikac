import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/glass.dart';
import '../../core/shapes.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/room_header.dart';

class _CardSpec {
  const _CardSpec(
    this.name,
    this.kind,
    this.shape,
    this.bg,
    this.number,
    this.stats,
  );
  final String name;
  final double kind;
  final int shape;
  final List<Color> bg;
  final String number;
  final List<(String, int)> stats;
}

const List<_CardSpec> _cards = <_CardSpec>[
  _CardSpec(
    'Prism',
    0,
    2,
    <Color>[Color(0xFF2B1D5C), Color(0xFF0E1230)],
    '07 / 120',
    <(String, int)>[('Light', 92), ('Depth', 64), ('Calm', 40)],
  ),
  _CardSpec(
    'Starlight',
    1,
    5,
    <Color>[Color(0xFF0B1E3A), Color(0xFF050912)],
    '19 / 120',
    <(String, int)>[('Light', 71), ('Depth', 88), ('Calm', 77)],
  ),
  _CardSpec(
    'Mosaic',
    2,
    1,
    <Color>[Color(0xFF3D1630), Color(0xFF140812)],
    '42 / 120',
    <(String, int)>[('Light', 55), ('Depth', 49), ('Calm', 93)],
  ),
];

/// Room 07. Collectible cards with a holographic foil that answers to tilt,
/// by finger or by moving the phone.
class FoilRoom extends StatefulWidget {
  const FoilRoom({super.key});

  @override
  State<FoilRoom> createState() => _FoilRoomState();
}

class _FoilRoomState extends State<FoilRoom> with TickerProviderStateMixin {
  static const EventChannel _tiltChannel = EventChannel('lumen/tilt');

  late final SpringValue _tx = SpringValue(this, spring: Motions.follow);
  late final SpringValue _ty = SpringValue(this, spring: Motions.follow);
  late final SpringValue _lift = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _pager = SpringValue(
    this,
    spring: Motions.spatialSlow,
  );
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (Duration e) => _time.value = e.inMicroseconds / 1e6,
  );
  int _index = 0;
  bool _usePhone = false;
  bool _noSensor = false;
  StreamSubscription<dynamic>? _sensor;
  List<double>? _g0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _sensor?.cancel();
    _ticker.dispose();
    for (final SpringValue s in <SpringValue>[_tx, _ty, _lift, _pager]) {
      s.dispose();
    }
    _time.dispose();
    super.dispose();
  }

  void _setPhone(bool on) {
    setState(() => _usePhone = on);
    _sensor?.cancel();
    _sensor = null;
    _g0 = null;
    if (!on) {
      _tx.animateTo(0, spring: Motions.expressive);
      _ty.animateTo(0, spring: Motions.expressive);
      return;
    }
    _sensor = _tiltChannel.receiveBroadcastStream().listen(
      (dynamic v) {
        final List<double> g = (v as List<dynamic>).cast<double>();
        // Tilt is measured from how the phone was held when this was switched on.
        _g0 ??= g;
        _tx.animateTo(((_g0![0] - g[0]) * 2.6).clamp(-1.0, 1.0));
        _ty.animateTo(((g[1] - _g0![1]) * 2.6).clamp(-1.0, 1.0));
      },
      onError: (Object _) => setState(() {
        _noSensor = true;
        _usePhone = false;
      }),
    );
  }

  void _drag(Offset local, Size card) {
    final Offset d = local - card.center(Offset.zero);
    _tx.animateTo((d.dx / (card.width / 2)).clamp(-1.0, 1.0));
    _ty.animateTo((d.dy / (card.height / 2)).clamp(-1.0, 1.0));
  }

  void _release() {
    _lift.animateTo(0);
    if (!_usePhone) {
      _tx.animateTo(0, spring: Motions.expressive);
      _ty.animateTo(0, spring: Motions.expressive);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Size screen = MediaQuery.sizeOf(context);
    final double cw = math.min(300, screen.width - 96);
    final Size card = Size(cw, cw * 1.4);
    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 32),
        children: <Widget>[
          const RoomHeader(
            number: 7,
            title: 'Foil',
            hint:
                'Trend: materials that respond to light and movement, borrowed from collectible cards. '
                'Touch and drag on the card to tilt it, or let the phone tilt it.',
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: card.height + 40,
            child: ListenableBuilder(
              listenable: _pager,
              builder: (BuildContext context, Widget? _) {
                final double p = _pager.value;
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    for (int i = 0; i < _cards.length; i++)
                      if ((i - p).abs() < 1.2)
                        Transform.translate(
                          key: ValueKey<int>(i),
                          offset: Offset((i - p) * (cw + 40), 0),
                          child: Opacity(
                            opacity: (1 - (i - p).abs() * 0.8).clamp(0.0, 1.0),
                            child: i == _index
                                ? Listener(
                                    onPointerDown: (PointerDownEvent e) {
                                      _lift.animateTo(1, velocity: 6);
                                      _drag(e.localPosition, card);
                                    },
                                    onPointerMove: (PointerMoveEvent e) =>
                                        _drag(e.localPosition, card),
                                    onPointerUp: (_) => _release(),
                                    onPointerCancel: (_) => _release(),
                                    // Claims drags in both directions, so the page
                                    // does not scroll while the card is being tilted.
                                    child: GestureDetector(
                                      onVerticalDragUpdate: (_) {},
                                      onHorizontalDragUpdate: (_) {},
                                      child: _TiltCard(
                                        spec: _cards[i],
                                        size: card,
                                        tx: _tx,
                                        ty: _ty,
                                        lift: _lift,
                                        time: _time,
                                      ),
                                    ),
                                  )
                                : _TiltCard(
                                    spec: _cards[i],
                                    size: card,
                                    time: _time,
                                  ),
                          ),
                        ),
                  ],
                );
              },
            ),
          ),
          Segmented<int>(
            values: const <int>[0, 1, 2],
            labels: _cards.map((_CardSpec s) => s.name).toList(),
            value: _index,
            onChanged: (int i) {
              setState(() => _index = i);
              _pager.animateTo(i.toDouble());
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
            decoration: ShapeDecoration(
              color: c.surface,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: c.hairline),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Tilt with the phone',
                        style: LumenType.text(15.5, weight: 580, color: c.ink),
                      ),
                      Text(
                        _noSensor ? 'No motion sensor found on this device.' : 'Uses the gravity sensor. Hold the phone how you like, then switch on.',
                        style: LumenType.text(13, color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
                LumenSwitch(
                  value: _usePhone,
                  onChanged: _noSensor ? (_) {} : _setPhone,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TiltCard extends StatelessWidget {
  const _TiltCard({
    required this.spec,
    required this.size,
    required this.time,
    this.tx,
    this.ty,
    this.lift,
  });
  final _CardSpec spec;
  final Size size;
  final ValueNotifier<double> time;
  final SpringValue? tx, ty, lift;

  @override
  Widget build(BuildContext context) {
    final Listenable motion = Listenable.merge(
      <Listenable?>[tx, ty, lift, time].whereType<Listenable>().toList(),
    );
    return ListenableBuilder(
      listenable: motion,
      builder: (BuildContext context, Widget? face) {
        final double x = tx?.value ?? 0,
            y = ty?.value ?? 0,
            l = lift?.value ?? 0;
        final Matrix4 m = Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..rotateX(y * 0.3)
          ..rotateY(-x * 0.3)
          ..scaleByDouble(1 + 0.04 * l, 1 + 0.04 * l, 1, 1);
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // Shadow moves against the tilt, as if the light is above.
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(-x * 14, 18 - y * 10 + 10 * l),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        shadows: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 30 + 12 * l,
                            spreadRadius: -6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Transform(
                  transform: m,
                  alignment: Alignment.center,
                  child: RepaintBoundary(
                    child: ClipRSuperellipse(
                      borderRadius: BorderRadius.circular(26),
                      child: CustomPaint(
                        foregroundPainter: _FoilPainter(
                          spec.kind,
                          Offset(x, y),
                          time.value,
                        ),
                        child: face,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: _CardFace(spec: spec, size: size),
    );
  }
}

class _FoilPainter extends CustomPainter {
  _FoilPainter(this.kind, this.tilt, this.time);
  final double kind;
  final Offset tilt;
  final double time;
  static ui.FragmentShader? _shader;

  @override
  void paint(Canvas canvas, Size size) {
    final ui.FragmentProgram? p = GlassShaders.holo;
    if (p == null) {
      return;
    }
    final ui.FragmentShader s = _shader ??= p.fragmentShader();
    s
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, tilt.dx)
      ..setFloat(3, tilt.dy)
      ..setFloat(4, time)
      ..setFloat(5, kind);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = s
        ..blendMode = BlendMode.screen,
    );
  }

  @override
  bool shouldRepaint(_FoilPainter old) =>
      old.kind != kind || old.tilt != tilt || old.time != time;
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.spec, required this.size});
  final _CardSpec spec;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: spec.bg,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                spec.name.toUpperCase(),
                style: LumenType.label(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Text(
                spec.number,
                style: LumenType.text(
                  11,
                  weight: 600,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SizedBox.square(
                dimension: size.width * 0.62,
                child: CustomPaint(painter: _Emblem(spec.shape)),
              ),
            ),
          ),
          Text(
            spec.name,
            style: LumenType.display(30, weight: 760, color: Colors.white),
          ),
          const SizedBox(height: 10),
          for (final (String label, int v) in spec.stats)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 52,
                    child: Text(
                      label,
                      style: LumenType.text(
                        12,
                        weight: 560,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 5,
                      alignment: Alignment.centerLeft,
                      decoration: ShapeDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: const StadiumBorder(),
                      ),
                      child: FractionallySizedBox(
                        heightFactor: 1,
                        widthFactor: v / 100,
                        child: const DecoratedBox(
                          decoration: ShapeDecoration(
                            color: Colors.white,
                            shape: StadiumBorder(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$v',
                    style: LumenType.text(12, weight: 640, color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Emblem extends CustomPainter {
  const _Emblem(this.shape);
  final int shape;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.shortestSide / 2;
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        c,
        r * (1 - i * 0.16),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.18 - i * 0.04),
      );
    }
    final Path p = ShapeLib.at(
      ShapeLib.gallery,
      shape.toDouble(),
      c,
      r * 0.62,
      0.2,
    );
    canvas.drawPath(
      p,
      Paint()
        ..shader = ui.Gradient.linear(
          c.translate(-r, -r),
          c.translate(r, r),
          <Color>[const Color(0xFFFFFFFF), const Color(0xFFB9C2E8)],
        ),
    );
  }

  @override
  bool shouldRepaint(_Emblem old) => old.shape != shape;
}
