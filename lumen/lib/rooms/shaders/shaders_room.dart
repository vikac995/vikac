import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/frame_stats.dart';
import '../../core/glass.dart';
import '../../core/settings.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/room_header.dart';
import '../glass/feed.dart';
import 'progressive_blur.dart';

/// Room 05. Three full-screen exhibits, each a hand-written GPU shader.
class ShadersRoom extends StatefulWidget {
  const ShadersRoom({super.key});

  @override
  State<ShadersRoom> createState() => _ShadersRoomState();
}

class _ShadersRoomState extends State<ShadersRoom>
    with TickerProviderStateMixin {
  static const List<String> _names = <String>['Aurora', 'Ripple', 'Blur'];
  static const List<String> _captions = <String>[
    'Touch and drag. The light swirls around your finger.',
    'Tap, or drag a finger through it. The text bends like water.',
    'Scroll. The blur deepens toward the top edge, in one pass.',
  ];

  int _ex = 0;
  late final SpringValue _pager = SpringValue(
    this,
    spring: Motions.spatialSlow,
  );

  @override
  void initState() {
    super.initState();
    FrameStats.instance.governorEnabled = true;
  }

  @override
  void dispose() {
    FrameStats.instance.governorEnabled = false;
    _pager.dispose();
    super.dispose();
  }

  Widget _exhibit(int i) => switch (i) {
    0 => const _AuroraExhibit(),
    1 => const _RippleExhibit(),
    _ => const _BlurExhibit(),
  };

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ListenableBuilder(
            listenable: _pager,
            builder: (BuildContext context, Widget? _) {
              final double p = _pager.value;
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  for (int i = 0; i < _names.length; i++)
                    if ((i - p).abs() < 1)
                      Transform.translate(
                        key: ValueKey<int>(i),
                        offset: Offset((i - p) * w, 0),
                        child: _exhibit(i),
                      ),
                ],
              );
            },
          ),
          Positioned(
            top: safe.top + 44,
            left: 16,
            right: 16,
            child: const RoomHeader(number: 5, title: 'Shaders'),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: safe.bottom + 16 + 60 + 14,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: const ShapeDecoration(
                    color: Color(0xCC0B0D12),
                    shape: StadiumBorder(),
                  ),
                  child: Text(
                    _captions[_ex],
                    textAlign: TextAlign.center,
                    style: LumenType.text(
                      13,
                      weight: 540,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: safe.bottom + 16,
            child: Center(
              child: SizedBox(
                width: 300,
                height: 60,
                child: Glass(
                  radius: 30,
                  style: GlassStyle(
                    blur: 14,
                    tint: 0.34,
                    refraction: 24,
                    bevel: 16,
                    fallbackColor: c.surfaceHigh,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Segmented<int>(
                      values: const <int>[0, 1, 2],
                      labels: _names,
                      value: _ex,
                      ink: c.glassInk,
                      onGlass: true,
                      onChanged: (int i) {
                        setState(() => _ex = i);
                        _pager.animateTo(i.toDouble());
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int _octaves() => switch (settings.effectiveQuality) {
  GlassQuality.full || GlassQuality.auto => 6,
  GlassQuality.medium => 4,
  GlassQuality.low => 2,
};

// ---------------------------------------------------------------- Aurora

class _AuroraExhibit extends StatefulWidget {
  const _AuroraExhibit();

  @override
  State<_AuroraExhibit> createState() => _AuroraExhibitState();
}

class _AuroraExhibitState extends State<_AuroraExhibit>
    with TickerProviderStateMixin {
  late final Ticker _ticker = createTicker(
    (Duration e) => _time.value = e.inMicroseconds / 1e6,
  );
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  late final SpringValue _x = SpringValue(
    this,
    value: 200,
    spring: Motions.follow,
  );
  late final SpringValue _y = SpringValue(
    this,
    value: 400,
    spring: Motions.follow,
  );
  late final SpringValue _press = SpringValue(
    this,
    spring: Motions.expressiveSlow,
  );
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _shader = GlassShaders.aurora?.fragmentShader();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _x.dispose();
    _y.dispose();
    _press.dispose();
    _shader?.dispose();
    super.dispose();
  }

  void _to(Offset p, {bool jump = false}) {
    if (jump) {
      _x.jumpTo(p.dx);
      _y.jumpTo(p.dy);
    } else {
      _x.animateTo(p.dx);
      _y.animateTo(p.dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final ui.FragmentShader? shader = _shader;
    if (shader == null) {
      return ColoredBox(color: c.bg);
    }
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (PointerDownEvent e) {
        _to(e.localPosition, jump: _press.value < 0.05);
        _press.animateTo(1);
      },
      onPointerMove: (PointerMoveEvent e) => _to(e.localPosition),
      onPointerUp: (_) => _press.animateTo(0),
      onPointerCancel: (_) => _press.animateTo(0),
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _AuroraPainter(shader, _time, _x, _y, _press, c),
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.shader, this.time, this.x, this.y, this.press, this.c)
    : super(repaint: Listenable.merge(<Listenable>[time, x, y, press]));
  final ui.FragmentShader shader;
  final ValueNotifier<double> time;
  final SpringValue x, y, press;
  final LumenColors c;

  static const List<Color> _night = <Color>[
    Color(0xFF05060C),
    Color(0xFF1E3A9A),
    Color(0xFF19C9B0),
    Color(0xFFFF6B4A),
  ];
  static const List<Color> _day = <Color>[
    Color(0xFFF4F0E8),
    Color(0xFFFFB49A),
    Color(0xFF8FD3FF),
    Color(0xFFC3A8FF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final List<Color> pal = c.dark ? _night : _day;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time.value)
      ..setFloat(3, x.value)
      ..setFloat(4, y.value)
      ..setFloat(5, press.value.clamp(0.0, 1.3))
      ..setFloat(6, _octaves().toDouble());
    for (int i = 0; i < 4; i++) {
      shader
        ..setFloat(7 + i * 3, pal[i].r)
        ..setFloat(8 + i * 3, pal[i].g)
        ..setFloat(9 + i * 3, pal[i].b);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.c != c || old.shader != shader;
}

// ---------------------------------------------------------------- Ripple

class _Ripple {
  _Ripple(this.pos, this.born, this.amp);
  final Offset pos;
  final double born;
  final double amp;
}

class _RippleExhibit extends StatefulWidget {
  const _RippleExhibit();

  @override
  State<_RippleExhibit> createState() => _RippleExhibitState();
}

class _RippleExhibitState extends State<_RippleExhibit>
    with SingleTickerProviderStateMixin {
  static const int _slots = 6;
  static const double _life = 2.8;
  late final Ticker _ticker = createTicker(_tick);
  final List<_Ripple> _ripples = <_Ripple>[];
  double _now = 0;
  double _lastAdd = -1;
  Offset _lastPos = Offset.zero;
  ui.FragmentShader? _shader;

  void _tick(Duration e) {
    setState(() {
      _now = e.inMicroseconds / 1e6;
      _ripples.removeWhere((_Ripple r) => _now - r.born > _life);
      if (_ripples.isEmpty) {
        _ticker.stop();
      }
    });
  }

  double get _clock {
    if (!_ticker.isActive) {
      _now = 0;
      _ticker.start();
    }
    return _now;
  }

  void _add(Offset p, double amp) {
    final double t = _clock;
    _ripples.add(_Ripple(p, t, amp));
    if (_ripples.length > _slots) {
      _ripples.removeAt(0);
    }
    _lastAdd = t;
    _lastPos = p;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final bool active =
        _ripples.isNotEmpty &&
        GlassShaders.ripple != null &&
        ui.ImageFilter.isShaderFilterSupported;
    ui.ImageFilter? filter;
    if (active) {
      // A fresh shader object per frame, so the filter is seen as changed.
      _shader?.dispose();
      final ui.FragmentShader s = _shader = GlassShaders.ripple!
          .fragmentShader();
      for (int i = 0; i < _slots; i++) {
        final _Ripple? r = i < _ripples.length ? _ripples[i] : null;
        s
          ..setFloat(2 + i * 4, (r?.pos.dx ?? 0) * dpr)
          ..setFloat(3 + i * 4, (r?.pos.dy ?? 0) * dpr)
          ..setFloat(4 + i * 4, r == null ? 0 : _now - r.born)
          ..setFloat(5 + i * 4, r?.amp ?? 0);
      }
      s.setFloat(2 + _slots * 4, dpr);
      filter = ui.ImageFilter.shader(s);
    }
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (PointerDownEvent e) => _add(e.localPosition, 1),
      onPointerMove: (PointerMoveEvent e) {
        if (_clock - _lastAdd > 0.08 &&
            (e.localPosition - _lastPos).distance > 26) {
          _add(e.localPosition, 0.6);
        }
      },
      child: ImageFiltered(
        imageFilter:
            filter ?? ui.ImageFilter.matrix(Matrix4.identity().storage),
        enabled: active,
        child: RepaintBoundary(child: _RippleContent(colors: c)),
      ),
    );
  }
}

class _RippleContent extends StatelessWidget {
  const _RippleContent({required this.colors});
  final LumenColors colors;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = colors;
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        CustomPaint(painter: _TilePainter(c)),
        Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            safe.top + 150,
            24,
            safe.bottom + 150,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Still\nwater\nruns',
                style: LumenType.display(
                  84,
                  weight: 800,
                  width: 90,
                  color: c.ink,
                  height: 0.9,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 290,
                child: Text(
                  'Every pixel on this screen is live: text, tiles and colour are drawn normally, then bent by a shader as the waves pass.',
                  style: LumenType.text(15.5, color: c.inkMuted, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TilePainter extends CustomPainter {
  const _TilePainter(this.c);
  final LumenColors c;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = c.bg);
    const List<Color> hues = <Color>[
      Color(0xFF19C9B0),
      Color(0xFF2E7BFF),
      Color(0xFFFF6B4A),
      Color(0xFFFFB23E),
      Color(0xFF8E7CFF),
    ];
    const double cell = 46;
    final math.Random rnd = math.Random(4);
    for (double y = 0; y < s.height + cell; y += cell) {
      for (double x = 0; x < s.width + cell; x += cell) {
        final double v = rnd.nextDouble();
        if (v < 0.42) {
          continue;
        }
        final Color h = hues[rnd.nextInt(hues.length)].withValues(
          alpha: c.dark ? 0.55 : 0.45,
        );
        final Rect r = Rect.fromLTWH(x + 5, y + 5, cell - 10, cell - 10);
        if (v < 0.7) {
          canvas.drawCircle(r.center, r.width / 2, Paint()..color = h);
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(10)),
            Paint()..color = h,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TilePainter old) => old.c != c;
}

// ---------------------------------------------------------------- Blur

class _BlurExhibit extends StatelessWidget {
  const _BlurExhibit();

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double band = safe.top + 210;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(
          color: c.bg,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(16, band - 40, 16, safe.bottom + 160),
            itemCount: 24,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int i) => RepaintBoundary(
              child: ClipRSuperellipse(
                borderRadius: BorderRadius.circular(28),
                child: SizedBox(
                  height: i.isEven ? 240 : 170,
                  child: CustomPaint(painter: PosterPainter(feeds[i % 3], i)),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: band,
          child: const ProgressiveBlur(maxBlur: 28),
        ),
      ],
    );
  }
}
