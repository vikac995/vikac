import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/room_header.dart';
import '../../widgets/spring_box.dart';

enum _Mode { inline, big, mini }

/// Room 47. A demo video that lives inside a workout: a small loop beside
/// the exercise name, grown in place when you want to study it, and parked
/// as a floating bubble while you lift. The "video" is a drawn loop.
class VideoRoom extends StatefulWidget {
  const VideoRoom({super.key});

  @override
  State<VideoRoom> createState() => _VideoRoomState();
}

class _VideoRoomState extends State<VideoRoom>
    with SingleTickerProviderStateMixin {
  static const double _loop = 3.2; // seconds per repetition
  final GlobalKey _stack = GlobalKey(),
      _slot = GlobalKey(),
      _bigSlot = GlobalKey();
  _Mode _mode = _Mode.inline;
  Rect _slotRect = Rect.zero;
  double _bigTop = 0;
  int _corner = 3; // 0 TL, 1 TR, 2 BL, 3 BR
  Offset? _dragAt; // top-left of the bubble while a finger moves it
  final ValueNotifier<double> _t = ValueNotifier<double>(0);
  bool _playing = true, _slow = false, _scrubbing = false;
  Duration _last = Duration.zero;
  final List<bool> _done = <bool>[false, false, false];
  late final Ticker _ticker = createTicker((Duration e) {
    final double dt = (e - _last).inMicroseconds / 1e6;
    _last = e;
    if (_playing && !_scrubbing) {
      _t.value = (_t.value + dt / _loop * (_slow ? 0.5 : 1)) % 1;
    }
  })..start();

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  void _measure() {
    final RenderBox? stack =
        _stack.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? slot =
        _slot.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? big =
        _bigSlot.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || slot == null || big == null || !slot.hasSize) {
      return;
    }
    final Rect r = slot.localToGlobal(Offset.zero, ancestor: stack) & slot.size;
    final double top = big.localToGlobal(Offset.zero, ancestor: stack).dy;
    if (r != _slotRect || top != _bigTop) {
      setState(() {
        _slotRect = r;
        _bigTop = top;
      });
    }
  }

  void _set(_Mode m) {
    setState(() => _mode = m);
    Haptics.settle();
  }

  String get _cue {
    final double t = _t.value;
    return t < 0.45
        ? 'Lower slowly, two seconds'
        : (t < 0.55 ? 'Pause on the chest' : 'Press, elbows under the bar');
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Size screen = MediaQuery.sizeOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final double w = screen.width - 32;
    final double bigH = w * 0.58;
    const Size mini = Size(132, 96);
    Offset cornerPos(int i) => Offset(
      i.isEven ? 16 : screen.width - 16 - mini.width,
      i < 2 ? safe.top + 50 : screen.height - safe.bottom - 20 - mini.height,
    );
    final Rect rect = switch (_mode) {
      _Mode.inline => _slotRect,
      _Mode.big => Rect.fromLTWH(16, _bigTop, w, bigH),
      _Mode.mini => (_dragAt ?? cornerPos(_corner)) & mini,
    };

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        key: _stack,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const RoomHeader(number: 47, title: 'Demo video'),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'EXERCISE 2 OF 5',
                            style: LumenType.label(color: c.accent),
                          ),
                          Text(
                            'Bench press',
                            style: LumenType.display(
                              32,
                              weight: 720,
                              color: c.ink,
                              height: 1.1,
                            ),
                          ),
                          Text(switch (_mode) {
                            _Mode.inline => 'Tap the loop to study it',
                            _Mode.big => 'Finish a set and it steps aside',
                            _Mode.mini => 'Drag the bubble to any corner',
                          }, style: LumenType.text(13.5, color: c.inkMuted)),
                        ],
                      ),
                    ),
                    // Where the small loop lives. Collapses when the video is elsewhere.
                    AnimatedContainer(
                      key: _slot,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      width: _mode == _Mode.inline ? 104 : 0.01,
                      height: 76,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AnimatedContainer(
                  key: _bigSlot,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: _mode == _Mode.big ? bigH + 14 : 0,
                ),
                for (int i = 0; i < 3; i++)
                  Container(
                    height: 62,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.only(left: 18, right: 8),
                    decoration: ShapeDecoration(
                      color: _done[i]
                          ? const Color(0xFF2FA84F).withValues(alpha: 0.12)
                          : c.ink.withValues(alpha: 0.055),
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          '${i + 1}',
                          style: LumenType.text(15, weight: 700, color: c.ink),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Text(
                            '80 kg  ×  8',
                            style: LumenType.text(
                              16,
                              weight: 620,
                              color: c.ink,
                            ),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() => _done[i] = !_done[i]);
                            Haptics.settle();
                            // The video gets out of the way as soon as you are lifting.
                            if (_done[i] && _mode == _Mode.big) {
                              setState(() => _mode = _Mode.mini);
                            }
                          },
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 40,
                                height: 40,
                                decoration: ShapeDecoration(
                                  color: _done[i]
                                      ? const Color(0xFF2FA84F)
                                      : Colors.transparent,
                                  shape: CircleBorder(
                                    side: BorderSide(
                                      color: _done[i]
                                          ? const Color(0xFF2FA84F)
                                          : c.inkFaint,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 22,
                                  color: _done[i] ? Colors.white : c.inkFaint,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Pattern: the video is never a separate screen. It has three sizes and moves between them, so the sets are always one glance away. Sound is off unless asked for.',
                  style: LumenType.text(13.5, color: c.inkMuted, height: 1.4),
                ),
              ],
            ),
          ),
          if (_slotRect != Rect.zero)
            SpringPositioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              spring: _dragAt != null
                  ? Motions.effectsFast
                  : Motions.expressive,
              child: GestureDetector(
                onTap: () {
                  if (_mode == _Mode.big) {
                    setState(() => _playing = !_playing);
                    Haptics.tick();
                  } else {
                    _set(_Mode.big);
                  }
                },
                onPanStart: _mode != _Mode.mini
                    ? null
                    : (_) => setState(() => _dragAt = cornerPos(_corner)),
                onPanUpdate: _mode != _Mode.mini
                    ? null
                    : (DragUpdateDetails d) =>
                          setState(() => _dragAt = _dragAt! + d.delta),
                onPanEnd: _mode != _Mode.mini
                    ? null
                    : (DragEndDetails d) {
                        // Lands in the corner it is heading for.
                        final Offset p =
                            _dragAt! +
                            mini.center(Offset.zero) +
                            d.velocity.pixelsPerSecond * 0.15;
                        final int to =
                            (p.dx > screen.width / 2 ? 1 : 0) +
                            (p.dy > screen.height / 2 ? 2 : 0);
                        setState(() {
                          _corner = to;
                          _dragAt = null;
                        });
                        Haptics.tick();
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    color: const Color(0xFF14161C),
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(
                        _mode == _Mode.big ? 28 : 20,
                      ),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    shadows: _mode == _Mode.mini
                        ? <BoxShadow>[
                            BoxShadow(
                              color: c.shadow,
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ValueListenableBuilder<double>(
                        valueListenable: _t,
                        builder: (BuildContext context, double t, Widget? _) =>
                            CustomPaint(painter: _Lift(t, c.accent)),
                      ),
                      if (_mode == _Mode.inline)
                        const Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.open_in_full_rounded,
                              size: 15,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      if (_mode == _Mode.mini)
                        Align(
                          alignment: Alignment.topRight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _set(_Mode.inline),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      if (_mode == _Mode.big) ...<Widget>[
                        Positioned(
                          left: 14,
                          top: 12,
                          right: 100,
                          child: ValueListenableBuilder<double>(
                            valueListenable: _t,
                            builder:
                                (BuildContext context, double _, Widget? _) =>
                                    Text(
                                      _playing ? _cue : 'Paused',
                                      style: LumenType.text(
                                        14,
                                        weight: 650,
                                        color: Colors.white,
                                      ),
                                    ),
                          ),
                        ),
                        Positioned(
                          right: 6,
                          top: 4,
                          child: Row(
                            children: <Widget>[
                              _chip(
                                _slow ? '0.5×' : '1×',
                                () => setState(() => _slow = !_slow),
                              ),
                              _icon(
                                Icons.picture_in_picture_alt_rounded,
                                'Shrink to a bubble',
                                () => _set(_Mode.mini),
                              ),
                              _icon(
                                Icons.close_rounded,
                                'Close',
                                () => _set(_Mode.inline),
                              ),
                            ],
                          ),
                        ),
                        // Scrub bar: slide to step through the movement.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 40,
                          child: LayoutBuilder(
                            builder:
                                (BuildContext context, BoxConstraints box) {
                                  void seek(double x) => _t.value =
                                      ((x - 14) / (box.maxWidth - 28)).clamp(
                                        0.0,
                                        0.999,
                                      );
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragStart:
                                        (DragStartDetails d) {
                                          _scrubbing = true;
                                          seek(d.localPosition.dx);
                                        },
                                    onHorizontalDragUpdate: (
                                      DragUpdateDetails d,
                                    ) => seek(d.localPosition.dx),
                                    onHorizontalDragEnd: (_) =>
                                        _scrubbing = false,
                                    onHorizontalDragCancel: () =>
                                        _scrubbing = false,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        18,
                                        14,
                                        16,
                                      ),
                                      child: ValueListenableBuilder<double>(
                                        valueListenable: _t,
                                        builder:
                                            (
                                              BuildContext context,
                                              double t,
                                              Widget? _,
                                            ) => ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              child: Stack(
                                                children: <Widget>[
                                                  const Positioned.fill(
                                                    child: ColoredBox(
                                                      color: Color(0x40FFFFFF),
                                                    ),
                                                  ),
                                                  FractionallySizedBox(
                                                    widthFactor: t,
                                                    heightFactor: 1,
                                                    child: ColoredBox(
                                                      color: c.accent,
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
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      onTap();
      Haptics.tick();
    },
    child: SizedBox(
      width: 52,
      height: 44,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: const ShapeDecoration(
            color: Color(0x33FFFFFF),
            shape: StadiumBorder(),
          ),
          child: Text(
            label,
            textScaler: TextScaler.noScaling,
            style: LumenType.text(
              12.5,
              weight: 700,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _icon(IconData icon, String label, VoidCallback onTap) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    ),
  );
}

/// A drawn stand-in for a demo clip: a figure bench-pressing, side on.
class _Lift extends CustomPainter {
  const _Lift(this.t, this.accent);
  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF242833), Color(0xFF12141A)],
        ).createShader(Offset.zero & size),
    );
    // 0 = bar up, 1 = bar on the chest.
    final double down = t < 0.45
        ? Curves.easeInOut.transform(t / 0.45)
        : (t < 0.55 ? 1 : 1 - Curves.easeInOut.transform((t - 0.55) / 0.45));
    final double u = math.min(size.width / 200, size.height / 130);
    canvas.save();
    canvas.translate(size.width / 2 - 100 * u, size.height / 2 - 62 * u);
    canvas.scale(u);
    final Paint body = Paint()
      ..color = const Color(0xFFE9E6E0)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final Paint gear = Paint()
      ..color = const Color(0xFF596070)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    // Floor, bench.
    canvas.drawLine(
      const Offset(10, 118),
      const Offset(190, 118),
      Paint()
        ..color = const Color(0x22FFFFFF)
        ..strokeWidth = 2,
    );
    canvas.drawLine(const Offset(42, 86), const Offset(132, 86), gear);
    canvas.drawLine(const Offset(54, 86), const Offset(54, 118), gear);
    canvas.drawLine(const Offset(122, 86), const Offset(122, 118), gear);
    // Body: head, torso, legs.
    canvas.drawCircle(
      const Offset(52, 72),
      9,
      Paint()..color = const Color(0xFFE9E6E0),
    );
    canvas.drawLine(const Offset(66, 76), const Offset(124, 76), body);
    canvas.drawLine(const Offset(124, 76), const Offset(150, 84), body);
    canvas.drawLine(const Offset(150, 84), const Offset(156, 116), body);
    // Arms and bar.
    const Offset shoulder = Offset(74, 74);
    final Offset hand = Offset(78, 22 + 40 * down);
    final Offset elbow = Offset(
      74 + 26 * down,
      (shoulder.dy + hand.dy) / 2 + 12 * down,
    );
    canvas.drawLine(shoulder, elbow, body);
    canvas.drawLine(elbow, hand, body);
    canvas.drawCircle(hand, 16, Paint()..color = accent);
    canvas.drawCircle(hand, 5, Paint()..color = const Color(0xFF14161C));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Lift old) => old.t != t;
}
