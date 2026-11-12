import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';

/// Number whose digits roll to their new value, each on its own spring.
class Odometer extends StatefulWidget {
  const Odometer({
    super.key,
    required this.value,
    required this.style,
    this.digits = 4,
  });
  final int value;
  final TextStyle style;
  final int digits;

  @override
  State<Odometer> createState() => _OdometerState();
}

class _OdometerState extends State<Odometer> with TickerProviderStateMixin {
  late final List<SpringValue> _d = List<SpringValue>.generate(
    widget.digits,
    (int i) => SpringValue(
      this,
      value: _digit(widget.value, i).toDouble(),
      spring: Motions.expressiveFast,
    ),
  );

  int _digit(int v, int i) =>
      (v ~/ math.pow(10, widget.digits - 1 - i).toInt()) % 10;

  @override
  void didUpdateWidget(Odometer old) {
    super.didUpdateWidget(old);
    for (int i = 0; i < widget.digits; i++) {
      _d[i].animateTo(_digit(widget.value, i).toDouble());
    }
  }

  @override
  void dispose() {
    for (final SpringValue s in _d) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextPainter probe = TextPainter(
      text: TextSpan(text: '0', style: widget.style),
      textDirection: TextDirection.ltr,
    )..layout();
    final double h = probe.height, w = probe.width;
    probe.dispose();
    final int lead = widget.value.toString().length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < widget.digits; i++)
          if (widget.digits - i <= lead)
            ClipRect(
              child: SizedBox(
                width: w,
                height: h,
                child: ListenableBuilder(
                  listenable: _d[i],
                  builder: (BuildContext context, Widget? column) =>
                      Transform.translate(
                        offset: Offset(0, -_d[i].value * h),
                        child: column,
                      ),
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: h * 10,
                    child: Column(
                      children: <Widget>[
                        for (int k = 0; k < 10; k++)
                          Text('$k', style: widget.style),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class LikeButton extends StatefulWidget {
  const LikeButton({super.key});

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with TickerProviderStateMixin {
  bool _liked = false;
  int _count = 1287;
  late final SpringValue _pop = SpringValue(
    this,
    value: 1,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _burst = SpringValue(
    this,
    value: 1,
    spring: Motions.effectsSlow,
  );

  @override
  void dispose() {
    _pop.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _tap() {
    setState(() {
      _liked = !_liked;
      _count += _liked ? 1 : -1;
    });
    _pop.jumpTo(_liked ? 0.62 : 0.85);
    _pop.onSettle = _liked ? Haptics.settle : null;
    _pop.animateTo(1, velocity: _liked ? 9 : 3);
    if (_liked) {
      _burst.jumpTo(0);
      _burst.animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    const Color heart = Color(0xFFFF4D6D);
    return Semantics(
      button: true,
      toggled: _liked,
      label: 'Like, $_count',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.only(left: 8, right: 18),
          decoration: ShapeDecoration(
            color: c.surface,
            shape: StadiumBorder(side: BorderSide(color: c.hairline)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 44,
                height: 44,
                child: ListenableBuilder(
                  listenable: Listenable.merge(<Listenable>[_pop, _burst]),
                  builder: (BuildContext context, Widget? _) {
                    return CustomPaint(
                      painter: _BurstPainter(_burst.value, heart),
                      child: Transform.scale(
                        scale: _pop.value,
                        child: Icon(
                          _liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 26,
                          color: _liked ? heart : c.inkMuted,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 4),
              Odometer(
                value: _count,
                style: LumenType.text(
                  17,
                  weight: 620,
                  color: c.ink,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 0.999) {
      return;
    }
    final Offset c = size.center(Offset.zero);
    for (int i = 0; i < 10; i++) {
      final double a = i / 10 * math.pi * 2 + 0.3;
      final double d = 12 + 22 * t + (i.isEven ? 4 * t : 0);
      final double r = (i.isEven ? 3.2 : 2.2) * (1 - t);
      final Color col = i % 3 == 0 ? const Color(0xFFFFB23E) : color;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * d,
        r,
        Paint()..color = col.withValues(alpha: 1 - t),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

class CopyButton extends StatefulWidget {
  const CopyButton({super.key});

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> with TickerProviderStateMixin {
  late final SpringValue _done = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _done.dispose();
    super.dispose();
  }

  void _tap() {
    Clipboard.setData(
      const ClipboardData(text: 'Lumen: a showcase of interface craft.'),
    );
    _done.onSettle = Haptics.tick;
    _done.animateTo(1);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1600), () {
      _done.onSettle = null;
      _done.animateTo(0, spring: Motions.spatial);
    });
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final Color ok = c.dark ? const Color(0xFF3DDC97) : const Color(0xFF168A57);
    return Semantics(
      button: true,
      label: 'Copy text',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: ListenableBuilder(
          listenable: _done,
          builder: (BuildContext context, Widget? _) {
            final double d = _done.value;
            final double on = d.clamp(0.0, 1.0);
            final Color ink = Color.lerp(c.ink, ok, on)!;
            return Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: ShapeDecoration(
                color: Color.lerp(c.surface, ok.withValues(alpha: 0.14), on),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: Color.lerp(
                      c.hairline,
                      ok.withValues(alpha: 0.4),
                      on,
                    )!,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Opacity(
                          opacity: (1 - on * 2).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 1 - 0.5 * on,
                            child: Icon(
                              Icons.content_copy_rounded,
                              size: 20,
                              color: ink,
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: ((on - 0.3) * 2).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: d,
                            child: Icon(
                              Icons.check_rounded,
                              size: 22,
                              color: ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ClipRect(
                    child: SizedBox(
                      height: 22,
                      width: 62,
                      child: Stack(
                        children: <Widget>[
                          Transform.translate(
                            offset: Offset(0, -22 * on),
                            child: Text(
                              'Copy',
                              style: LumenType.text(
                                16,
                                weight: 600,
                                color: ink,
                                height: 1.35,
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(0, 22 * (1 - on)),
                            child: Text(
                              'Copied',
                              style: LumenType.text(
                                16,
                                weight: 600,
                                color: ink,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
