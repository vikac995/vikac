import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/shapes.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/room_header.dart';
import '../shapes/shape_loader.dart';
import 'prompt_bar.dart';
import 'small_things.dart';

class _Msg {
  const _Msg(this.id, this.name, this.text, this.time, this.hue);
  final int id;
  final String name;
  final String text;
  final String time;
  final Color hue;
}

const List<_Msg> _initial = <_Msg>[
  _Msg(
    1,
    'Mira',
    'The prints came back. The blue one is even better on paper.',
    '9:41',
    Color(0xFF4FB8FF),
  ),
  _Msg(
    2,
    'Studio North',
    'Workshop moved to Thursday, same room.',
    '9:12',
    Color(0xFF2ED3B7),
  ),
  _Msg(
    3,
    'Jonas',
    'Did the spring presets feel right to you?',
    'Yesterday',
    Color(0xFFFFB23E),
  ),
  _Msg(
    4,
    'Ana',
    'Sending the type specimens tonight.',
    'Yesterday',
    Color(0xFFFF7AB6),
  ),
  _Msg(
    5,
    'Build bot',
    'Release build passed on all devices.',
    'Mon',
    Color(0xFF8E7CFF),
  ),
  _Msg(6, 'Leo', 'Coffee at ten?', 'Mon', Color(0xFFFF6B4A)),
];

const List<_Msg> _incoming = <_Msg>[
  _Msg(
    101,
    'Mira',
    'Also: the glass bar looks unreal in the dark.',
    'now',
    Color(0xFF4FB8FF),
  ),
  _Msg(
    102,
    'Jonas',
    'Back gesture is so smooth. How?',
    'now',
    Color(0xFFFFB23E),
  ),
  _Msg(
    103,
    'Studio North',
    'Room booked. Bring the phone.',
    'now',
    Color(0xFF2ED3B7),
  ),
  _Msg(
    104,
    'Ana',
    'Variable fonts are my new favourite thing.',
    'now',
    Color(0xFFFF7AB6),
  ),
];

enum _Refresh { idle, refreshing, done }

/// Room 06. Small things done carefully.
class DetailsRoom extends StatefulWidget {
  const DetailsRoom({super.key});

  @override
  State<DetailsRoom> createState() => _DetailsRoomState();
}

class _DetailsRoomState extends State<DetailsRoom>
    with TickerProviderStateMixin {
  static const double _threshold = 92;
  static const double _holdHeight = 78;

  final ScrollController _scroll = ScrollController();
  late final SpringValue _vel = SpringValue(this, spring: Motions.expressive);
  late final SpringValue _hold = SpringValue(this, spring: Motions.spatial);
  late final SpringValue _armPop = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _check = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  final ValueNotifier<double> _pull = ValueNotifier<double>(0);
  final List<_Msg> _msgs = List<_Msg>.of(_initial);
  final Set<int> _fresh = <int>{};
  _Refresh _state = _Refresh.idle;
  bool _armed = false;
  int _nextIncoming = 0;
  double _lastPixels = 0;
  Duration _lastStamp = Duration.zero;
  final Stopwatch _clock = Stopwatch()..start();
  final List<Timer> _timers = <Timer>[];

  @override
  void dispose() {
    for (final Timer t in _timers) {
      t.cancel();
    }
    _scroll.dispose();
    _pull.dispose();
    for (final SpringValue s in <SpringValue>[_vel, _hold, _armPop, _check]) {
      s.dispose();
    }
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) {
      return false;
    }
    final double px = n.metrics.pixels;
    _pull.value = math.max(0, -px);

    // Scroll velocity for the headline, smoothed by a spring.
    final Duration now = _clock.elapsed;
    final double dt = (now - _lastStamp).inMicroseconds / 1e6;
    if (n is ScrollUpdateNotification && dt > 0 && dt < 0.1) {
      _vel.animateTo(
        ((px - _lastPixels) / dt).clamp(-4000.0, 4000.0),
        spring: Motions.follow,
      );
    }
    if (n is ScrollEndNotification) {
      _vel.animateTo(0, spring: Motions.expressive);
    }
    _lastPixels = px;
    _lastStamp = now;

    if (_state == _Refresh.idle &&
        n is ScrollUpdateNotification &&
        n.dragDetails != null) {
      final bool armed = _pull.value >= _threshold;
      if (armed != _armed) {
        _armed = armed;
        _armPop.animateTo(armed ? 1 : 0);
        if (armed) {
          Haptics.tick();
        }
      }
    }
    return false;
  }

  void _pointerUp() {
    if (!_armed || _state != _Refresh.idle) {
      _armed = false;
      _armPop.animateTo(0);
      return;
    }
    _armed = false;
    // Let the drag finish first, then take over from where the list is.
    scheduleMicrotask(() {
      if (!mounted) {
        return;
      }
      final double pulled = _pull.value;
      setState(() => _state = _Refresh.refreshing);
      _hold.jumpTo(pulled);
      _scroll.jumpTo(0);
      _hold.animateTo(_holdHeight);
      _timers.add(Timer(const Duration(milliseconds: 1700), _finish));
    });
  }

  void _finish() {
    if (!mounted) {
      return;
    }
    final _Msg m = _incoming[_nextIncoming++ % _incoming.length];
    final _Msg msg = _Msg(
      m.id * 1000 + _nextIncoming,
      m.name,
      m.text,
      m.time,
      m.hue,
    );
    setState(() {
      _state = _Refresh.done;
      _msgs.insert(0, msg);
      _fresh.add(msg.id);
    });
    _check.jumpTo(0);
    _check.onSettle = Haptics.settle;
    _check.animateTo(1);
    _timers.add(
      Timer(const Duration(milliseconds: 650), () {
        if (!mounted) {
          return;
        }
        _armPop.animateTo(0);
        _hold.onSettle = () {
          if (mounted) {
            setState(() => _state = _Refresh.idle);
          }
        };
        _hold.animateTo(0, spring: Motions.expressive);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double top = safe.top + 44;
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          Listener(
            onPointerUp: (_) => _pointerUp(),
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: CustomScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: <Widget>[
                  SliverToBoxAdapter(child: SizedBox(height: top)),
                  SliverToBoxAdapter(
                    child: ListenableBuilder(
                      listenable: _hold,
                      builder: (BuildContext context, Widget? _) =>
                          SizedBox(height: math.max(0, _hold.value)),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, safe.bottom + 40),
                    sliver: SliverList.list(
                      children: <Widget>[
                        const RoomHeader(
                          number: 6,
                          title: 'Details',
                          hint: 'Pull down to refresh. Scroll fast and watch the type. Ask the prompt bar anything.',
                        ),
                        const SizedBox(height: 22),
                        _FluidHeadline(scroll: _scroll, velocity: _vel),
                        const SizedBox(height: 26),
                        _label(c, 'Prompt'),
                        const PromptBar(),
                        const SizedBox(height: 28),
                        _label(c, 'Small things'),
                        const Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[LikeButton(), CopyButton()],
                        ),
                        const SizedBox(height: 28),
                        _label(c, 'Inbox'),
                        for (final _Msg m in _msgs)
                          _Entering(
                            key: ValueKey<int>(m.id),
                            enter: _fresh.contains(m.id),
                            child: _MsgRow(
                              msg: m,
                              fresh: _fresh.contains(m.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Pull-to-refresh indicator, in the gap the pull opens above the content.
          Positioned(
            top: top,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[
                  _pull,
                  _hold,
                  _armPop,
                  _check,
                ]),
                builder: (BuildContext context, Widget? _) {
                  final double gap = _pull.value + math.max(0, _hold.value);
                  if (gap < 2) {
                    return const SizedBox.shrink();
                  }
                  return SizedBox(
                    height: gap,
                    child: Center(child: _indicator(c, gap)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicator(LumenColors c, double gap) {
    final double size = (gap * 0.5).clamp(0.0, 40.0);
    switch (_state) {
      case _Refresh.refreshing:
        return ShapeLoader(size: 38, color: c.accent);
      case _Refresh.done:
        return Transform.scale(
          scale: _check.value,
          child: Container(
            width: 40,
            height: 40,
            decoration: ShapeDecoration(
              color: c.accent,
              shape: const CircleBorder(),
            ),
            child: Icon(Icons.check_rounded, size: 24, color: c.onAccent),
          ),
        );
      case _Refresh.idle:
        final double progress = (_pull.value / _threshold).clamp(0.0, 1.0);
        final double arm = _armPop.value;
        return SizedBox.square(
          dimension: 44,
          child: CustomPaint(
            painter: _PullShape(
              progress: progress,
              arm: arm,
              size: size * (1 + 0.15 * arm),
              rotation: _pull.value * 0.018,
              color: Color.lerp(c.inkFaint, c.accent, arm.clamp(0.0, 1.0))!,
            ),
          ),
        );
    }
  }

  Widget _label(LumenColors c, String s) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(s.toUpperCase(), style: LumenType.label(color: c.inkFaint)),
  );
}

/// The pull indicator: a dot that grows into a shape as you pull, and
/// becomes a full cookie once the pull is far enough to refresh.
class _PullShape extends CustomPainter {
  const _PullShape({
    required this.progress,
    required this.arm,
    required this.size,
    required this.rotation,
    required this.color,
  });
  final double progress;
  final double arm;
  final double size;
  final double rotation;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    if (size < 1) {
      return;
    }
    final Path p = ShapeLib.at(
      ShapeLib.gallery,
      arm.clamp(0.0, 1.2),
      s.center(Offset.zero),
      size / 2,
      rotation,
    );
    if (arm < 0.5) {
      // Before it is armed, draw a ring that fills up with the pull.
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color.withValues(alpha: 0.35),
      );
      final Rect bounds = p.getBounds();
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          bounds.left - 2,
          bounds.bottom - bounds.height * progress,
          bounds.right + 2,
          bounds.bottom + 2,
        ),
      );
      canvas.drawPath(p, Paint()..color = color);
      canvas.restore();
    } else {
      canvas.drawPath(p, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_PullShape old) =>
      old.progress != progress ||
      old.arm != arm ||
      old.size != size ||
      old.rotation != rotation ||
      old.color != color;
}

/// Headline drawn letter by letter. Weight thins as you scroll down the page;
/// scroll speed condenses the width and sends a wave of weight through the
/// letters, which wobbles out on a spring when you stop.
class _FluidHeadline extends StatelessWidget {
  const _FluidHeadline({required this.scroll, required this.velocity});
  final ScrollController scroll;
  final SpringValue velocity;

  static const String _text = 'Fluid type';

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return SizedBox(
      height: 76,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[scroll, velocity]),
        builder: (BuildContext context, Widget? _) {
          final double off = scroll.hasClients ? math.max(0, scroll.offset) : 0;
          final double settle = (off / 320).clamp(0.0, 1.0);
          final double v = (velocity.value / 2600).clamp(-1.3, 1.3);
          final double width = (100 - 24 * v.abs()).clamp(75.0, 100.0);
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                for (int i = 0; i < _text.length; i++)
                  Text(
                    _text[i],
                    style: LumenType.display(
                      66,
                      weight:
                          (ui.lerpDouble(800, 300, settle)! +
                                  380 * v * math.sin(i * 0.85 + 0.6))
                              .clamp(200.0, 800.0),
                      width: width,
                      color: Color.lerp(
                        c.ink,
                        c.accent,
                        (v.abs() * 0.8).clamp(0.0, 1.0) *
                            (0.5 + 0.5 * math.sin(i * 0.85)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// New rows open up space for themselves, then fade in.
class _Entering extends StatefulWidget {
  const _Entering({super.key, required this.enter, required this.child});
  final bool enter;
  final Widget child;

  @override
  State<_Entering> createState() => _EnteringState();
}

class _EnteringState extends State<_Entering> with TickerProviderStateMixin {
  late final SpringValue _size = SpringValue(
    this,
    value: widget.enter ? 0 : 1,
    spring: Motions.spatial,
  );
  late final SpringValue _fade = SpringValue(
    this,
    value: widget.enter ? 0 : 1,
    spring: Motions.effectsSlow,
  );

  @override
  void initState() {
    super.initState();
    if (widget.enter) {
      _size.animateTo(1);
      Future<void>.delayed(const Duration(milliseconds: 90), () {
        if (mounted) {
          _fade.animateTo(1);
        }
      });
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_size, _fade]),
      builder: (BuildContext context, Widget? child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: _size.value.clamp(0.0, 1.0),
          child: Opacity(
            opacity: _fade.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - _fade.value)),
              child: child,
            ),
          ),
        ),
      ),
      child: widget.child,
    );
  }
}

class _MsgRow extends StatelessWidget {
  const _MsgRow({required this.msg, required this.fresh});
  final _Msg msg;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        decoration: ShapeDecoration(
          color: c.surface,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: c.hairline),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: msg.hue.withValues(alpha: 0.22),
                shape: const CircleBorder(),
              ),
              child: Text(
                msg.name[0],
                style: LumenType.display(19, weight: 700, color: msg.hue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          msg.name,
                          style: LumenType.text(15, weight: 620, color: c.ink),
                        ),
                      ),
                      if (fresh)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: c.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(
                        msg.time,
                        style: LumenType.text(12.5, color: c.inkFaint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    msg.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LumenType.text(14, color: c.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
