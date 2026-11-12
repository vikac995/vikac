import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/room_header.dart';
import '../../widgets/pressable.dart';

enum _Act { timer, music, call }

const Color _orange = Color(0xFFFF9F0A);
const Color _green = Color(0xFF30D158);
const Color _red = Color(0xFFFF453A);

/// Room 10. A status pill that grows into whatever is happening: a timer,
/// music, a call, a notification. Glanceable when small, useful when open.
class PillRoom extends StatefulWidget {
  const PillRoom({super.key});

  @override
  State<PillRoom> createState() => _PillRoomState();
}

class _PillRoomState extends State<PillRoom> with TickerProviderStateMixin {
  final Set<_Act> _active = <_Act>{};
  bool _expanded = false;
  String? _ping;
  Timer? _pingTimer;
  int _timerLeft = 300;
  Timer? _countdown;
  int _callSecs = 0;
  bool _callRinging = false;

  // Pill geometry, each on its own spring.
  late final SpringValue _w = SpringValue(
    this,
    value: 112,
    spring: Motions.expressive,
  );
  late final SpringValue _h = SpringValue(
    this,
    value: 34,
    spring: Motions.expressive,
  );
  late final SpringValue _content = SpringValue(
    this,
    value: 1,
    spring: Motions.effects,
  );
  late final SpringValue _bubble = SpringValue(
    this,
    spring: Motions.expressive,
  );
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (Duration e) => _time.value = e.inMicroseconds / 1e6,
  );

  _Act? get _main {
    if (_active.contains(_Act.call)) {
      return _Act.call;
    }
    if (_active.contains(_Act.music)) {
      return _Act.music;
    }
    if (_active.contains(_Act.timer)) {
      return _Act.timer;
    }
    return null;
  }

  _Act? get _second {
    final List<_Act> rest = _active.where((_Act a) => a != _main).toList();
    if (rest.isEmpty) {
      return null;
    }
    return rest.contains(_Act.timer) ? _Act.timer : rest.first;
  }

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _countdown?.cancel();
    _ticker.dispose();
    for (final SpringValue s in <SpringValue>[_w, _h, _content, _bubble]) {
      s.dispose();
    }
    _time.dispose();
    super.dispose();
  }

  Size _targetSize() {
    if (_ping != null) {
      return const Size(290, 64);
    }
    final _Act? m = _main;
    if (m == null) {
      return const Size(112, 34);
    }
    if (_expanded) {
      return switch (m) {
        _Act.music => const Size(336, 176),
        _Act.timer => const Size(336, 104),
        _Act.call => const Size(336, 112),
      };
    }
    return switch (m) {
      _Act.call => const Size(250, 34),
      _ => const Size(206, 34),
    };
  }

  void _relayout({bool haptic = true}) {
    final Size t = _targetSize();
    _w.animateTo(t.width);
    _h.animateTo(t.height);
    // Old content goes at once; new content fades in as the shape arrives.
    _content.jumpTo(0);
    Future<void>.delayed(const Duration(milliseconds: 110), () {
      if (mounted) {
        _content.animateTo(1);
      }
    });
    _bubble.animateTo(_second != null && _ping == null && !_expanded ? 1 : 0);
    if (haptic) {
      _w.onSettle = Haptics.settle;
    }
  }

  void _toggle(_Act a) {
    setState(() {
      if (_active.contains(a)) {
        _active.remove(a);
        if (a == _Act.timer) {
          _countdown?.cancel();
        }
      } else {
        _active.add(a);
        if (a == _Act.timer) {
          _timerLeft = 300;
          _countdown?.cancel();
          _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
            setState(() => _timerLeft = math.max(0, _timerLeft - 1));
          });
        }
        if (a == _Act.call) {
          _callRinging = true;
          _callSecs = 0;
          _expanded = true;
        }
      }
      if (_main == null) {
        _expanded = false;
      }
    });
    _relayout();
  }

  void _doPing() {
    _pingTimer?.cancel();
    setState(() => _ping = 'Headphones connected');
    Haptics.tick();
    _relayout(haptic: false);
    _pingTimer = Timer(const Duration(milliseconds: 1800), () {
      setState(() => _ping = null);
      _relayout(haptic: false);
    });
  }

  void _tapPill() {
    if (_main == null || _ping != null) {
      return;
    }
    setState(() => _expanded = !_expanded);
    _relayout();
  }

  void _answer(bool accept) {
    setState(() {
      _callRinging = false;
      if (!accept) {
        _active.remove(_Act.call);
      }
      _expanded = false;
    });
    if (accept) {
      Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (!mounted || !_active.contains(_Act.call)) {
          t.cancel();
          return;
        }
        setState(() => _callSecs++);
      });
    }
    _relayout();
  }

  String _mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 32),
        children: <Widget>[
          const RoomHeader(
            number: 10,
            title: 'Live pill',
            hint:
                'Trend: live activities. Ongoing things (a timer, music, a call) live in a small pill '
                'you can read at a glance, and open into controls when you need them. Start a few below; tap the pill.',
          ),
          const SizedBox(height: 18),
          _stage(c),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _chip(
                c,
                Icons.timer_outlined,
                'Timer',
                _active.contains(_Act.timer),
                () => _toggle(_Act.timer),
              ),
              _chip(
                c,
                Icons.music_note_rounded,
                'Music',
                _active.contains(_Act.music),
                () => _toggle(_Act.music),
              ),
              _chip(
                c,
                Icons.call_rounded,
                'Call',
                _active.contains(_Act.call),
                () => _toggle(_Act.call),
              ),
              _chip(
                c,
                Icons.notifications_none_rounded,
                'Notify',
                false,
                _doPing,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(
    LumenColors c,
    IconData icon,
    String label,
    bool on,
    VoidCallback onTap,
  ) {
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: ShapeDecoration(
          color: on ? c.accent : c.surface,
          shape: StadiumBorder(
            side: BorderSide(color: on ? c.accent : c.hairline),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 20, color: on ? c.onAccent : c.ink),
            const SizedBox(width: 8),
            Text(
              label,
              style: LumenType.text(
                15,
                weight: 600,
                color: on ? c.onAccent : c.ink,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stage(LumenColors c) {
    final DateTime now = DateTime.now();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_expanded && !_callRinging) {
          setState(() => _expanded = false);
          _relayout();
        }
      },
      child: Container(
        height: 400,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF3B2B6E),
              Color(0xFF0F3A5A),
              Color(0xFF0A1424),
            ],
          ),
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(40),
            side: BorderSide(color: c.hairline),
          ),
        ),
        child: Stack(
          children: <Widget>[
            // A lock screen, for context.
            Positioned(
              left: 0,
              right: 0,
              top: 96,
              child: Column(
                children: <Widget>[
                  Text(
                    '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
                    style: LumenType.display(
                      76,
                      weight: 640,
                      width: 92,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  Text(
                    'Thursday, 12 November',
                    style: LumenType.text(
                      15,
                      weight: 520,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[
                  _w,
                  _h,
                  _content,
                  _bubble,
                  _time,
                ]),
                builder: (BuildContext context, Widget? _) => _pill(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill() {
    final double w = _w.value, h = _h.value;
    final double b = _bubble.value;
    final double radius = math.min(h / 2, 40);
    final double gap = 8 * b;
    final double bubbleSize = 34 * b.clamp(0.0, 1.2);
    // The pill shifts left to make room as the bubble splits off.
    final double shift = (bubbleSize + gap) / 2;
    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: <Widget>[
          Transform.translate(
            offset: Offset(-shift, 0),
            child: GestureDetector(
              onTap: _tapPill,
              child: Container(
                width: w,
                height: h,
                decoration: ShapeDecoration(
                  color: Colors.black,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  shadows: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Opacity(
                  opacity: _content.value.clamp(0.0, 1.0),
                  child: _pillContent(w, h),
                ),
              ),
            ),
          ),
          if (b > 0.01)
            Transform.translate(
              offset: Offset(
                w / 2 - shift + gap + bubbleSize / 2 - (1 - b) * 20,
                0,
              ),
              child: Container(
                width: bubbleSize,
                height: bubbleSize,
                decoration: const ShapeDecoration(
                  color: Colors.black,
                  shape: CircleBorder(),
                ),
                child: Opacity(
                  opacity: ((b - 0.5) * 2).clamp(0.0, 1.0),
                  child: Center(child: _bubbleContent()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bubbleContent() {
    return switch (_second) {
      _Act.timer => SizedBox.square(
        dimension: 20,
        child: CustomPaint(painter: _Ring(_timerLeft / 300, _orange)),
      ),
      _Act.music => const Icon(
        Icons.music_note_rounded,
        size: 16,
        color: Colors.white,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _pillContent(double w, double h) {
    const TextStyle white = TextStyle(color: Colors.white);
    if (_ping != null) {
      return Row(
        children: <Widget>[
          const SizedBox(width: 14),
          Container(
            width: 36,
            height: 36,
            decoration: const ShapeDecoration(
              color: Color(0xFF2C2C2E),
              shape: CircleBorder(),
            ),
            child: const Icon(
              Icons.headphones_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _ping!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LumenType.text(14.5, weight: 600).merge(white),
            ),
          ),
          const Icon(Icons.battery_5_bar_rounded, color: _green, size: 20),
          const SizedBox(width: 16),
        ],
      );
    }
    final _Act? m = _main;
    if (m == null) {
      return const SizedBox.shrink();
    }
    final bool big = h > 60;
    switch (m) {
      case _Act.timer:
        if (!big) {
          return _compact(
            SizedBox.square(
              dimension: 18,
              child: CustomPaint(painter: _Ring(_timerLeft / 300, _orange)),
            ),
            Text(
              _mmss(_timerLeft),
              style: LumenType.text(14, weight: 650, color: _orange, height: 1),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: <Widget>[
              _circleButton(
                Icons.pause_rounded,
                _orange.withValues(alpha: 0.25),
                _orange,
                () {},
              ),
              const SizedBox(width: 10),
              _circleButton(
                Icons.close_rounded,
                const Color(0xFF3A3A3C),
                Colors.white,
                () => _toggle(_Act.timer),
              ),
              const Spacer(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    'Timer',
                    style: LumenType.text(13, weight: 560, color: _orange),
                  ),
                  Text(
                    _mmss(_timerLeft),
                    style: LumenType.display(
                      40,
                      weight: 600,
                      color: _orange,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case _Act.music:
        if (!big) {
          return _compact(_art(22), _Bars(time: _time.value, height: 14));
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  _art(54),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Low Tide',
                          style: LumenType.text(16, weight: 650).merge(white),
                        ),
                        Text(
                          'The Flats',
                          style: LumenType.text(14, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  _Bars(time: _time.value, height: 22),
                ],
              ),
              const Spacer(),
              Row(
                children: <Widget>[
                  Text(
                    '1:12',
                    style: LumenType.text(11.5, color: Colors.white54),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 5,
                      alignment: Alignment.centerLeft,
                      decoration: const ShapeDecoration(
                        color: Color(0xFF3A3A3C),
                        shape: StadiumBorder(),
                      ),
                      child: FractionallySizedBox(
                        heightFactor: 1,
                        widthFactor: 0.38 + (_time.value % 60) / 60 * 0.2,
                        child: const DecoratedBox(
                          decoration: ShapeDecoration(
                            color: Colors.white,
                            shape: StadiumBorder(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '-2:01',
                    style: LumenType.text(11.5, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Icon(
                    Icons.skip_previous_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                  Icon(Icons.pause_rounded, color: Colors.white, size: 36),
                  Icon(Icons.skip_next_rounded, color: Colors.white, size: 30),
                ],
              ),
            ],
          ),
        );
      case _Act.call:
        if (!big) {
          return _compact(
            const Icon(Icons.call_rounded, color: _green, size: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _Bars(time: _time.value, height: 12, color: _green),
                const SizedBox(width: 8),
                Text(
                  _mmss(_callSecs),
                  style: LumenType.text(
                    14,
                    weight: 650,
                    color: _green,
                    height: 1,
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const ShapeDecoration(
                  color: Color(0xFF5E5CE6),
                  shape: CircleBorder(),
                ),
                child: Text(
                  'M',
                  style: LumenType.display(
                    24,
                    weight: 700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _callRinging ? 'Incoming call' : 'On call',
                      style: LumenType.text(12.5, color: Colors.white60),
                    ),
                    Text(
                      'Mira',
                      style: LumenType.text(18, weight: 650).merge(white),
                    ),
                  ],
                ),
              ),
              if (_callRinging) ...<Widget>[
                _circleButton(
                  Icons.call_end_rounded,
                  _red,
                  Colors.white,
                  () => _answer(false),
                ),
                const SizedBox(width: 12),
                _circleButton(
                  Icons.call_rounded,
                  _green,
                  Colors.white,
                  () => _answer(true),
                ),
              ] else
                _circleButton(
                  Icons.call_end_rounded,
                  _red,
                  Colors.white,
                  () => _toggle(_Act.call),
                ),
            ],
          ),
        );
    }
  }

  Widget _compact(Widget left, Widget right) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: <Widget>[left, const Spacer(), right]),
    );
  }

  Widget _art(double s) {
    return Container(
      width: s,
      height: s,
      decoration: ShapeDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF3F8FB5), Color(0xFFFFE3A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(s * 0.24),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: 48,
        height: 48,
        decoration: ShapeDecoration(color: bg, shape: const CircleBorder()),
        child: Icon(icon, color: fg, size: 24),
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({
    required this.time,
    required this.height,
    this.color = const Color(0xFF8E7CFF),
  });
  final double time;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          for (int i = 0; i < 5; i++)
            Container(
              width: 3,
              height:
                  height *
                  (0.3 +
                      0.7 *
                          (0.5 + 0.5 * math.sin(time * (5 + i * 1.3) + i * 1.9))
                              .abs()),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: ShapeDecoration(
                color: color,
                shape: const StadiumBorder(),
              ),
            ),
        ],
      ),
    );
  }
}

class _Ring extends CustomPainter {
  const _Ring(this.v, this.color);
  final double v;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = (Offset.zero & size).deflate(1.5);
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      p..color = color.withValues(alpha: 0.25),
    );
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, p..color = color);
  }

  @override
  bool shouldRepaint(_Ring old) => old.v != v || old.color != color;
}
