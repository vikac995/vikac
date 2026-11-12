import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../core/haptics.dart';
import '../core/springs.dart';
import '../core/theme.dart';
import 'pressable.dart';

/// Round icon button on a solid surface.
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: Container(
          width: 48,
          height: 48,
          decoration: ShapeDecoration(
            color: c.surface,
            shape: CircleBorder(side: BorderSide(color: c.hairline)),
          ),
          child: Icon(icon, size: 22, color: c.ink),
        ),
      ),
    );
  }
}

/// Switch. The thumb travels on a spring with overshoot and stretches while
/// pressed; the haptic fires when it lands.
class LumenSwitch extends StatefulWidget {
  const LumenSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<LumenSwitch> createState() => _LumenSwitchState();
}

class _LumenSwitchState extends State<LumenSwitch>
    with TickerProviderStateMixin {
  late final SpringValue _pos = SpringValue(
    this,
    value: widget.value ? 1 : 0,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _press = SpringValue(
    this,
    spring: Motions.spatialFast,
  );

  @override
  void didUpdateWidget(LumenSwitch old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _pos.onSettle = Haptics.settle;
      _pos.animateTo(widget.value ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Semantics(
      toggled: widget.value,
      child: Listener(
        onPointerDown: (_) => _press.animateTo(1, velocity: 12),
        onPointerUp: (_) => _press.animateTo(0, spring: Motions.expressiveFast),
        onPointerCancel: (_) =>
            _press.animateTo(0, spring: Motions.expressiveFast),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onChanged(!widget.value),
          child: SizedBox(
            width: 60,
            height: 48,
            child: Center(
              child: ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[_pos, _press]),
                builder: (BuildContext context, Widget? _) {
                  final double t = _pos.value;
                  final double on = t.clamp(0.0, 1.0);
                  final double stretch = 6 * _press.value.clamp(0.0, 1.2);
                  const double w = 54, h = 32, pad = 4, thumb = 24;
                  final double travel = w - pad * 2 - thumb - stretch;
                  final double left = pad + travel * t;
                  return SizedBox(
                    width: w,
                    height: h,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: Color.lerp(
                                c.ink.withValues(alpha: 0.16),
                                c.accent,
                                on,
                              ),
                              shape: const StadiumBorder(),
                            ),
                          ),
                        ),
                        Positioned(
                          left: left,
                          top: pad,
                          width: thumb + stretch,
                          height: thumb,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: Color.lerp(
                                c.dark ? c.ink : c.surfaceHigh,
                                c.dark ? c.onAccent : Colors.white,
                                on,
                              ),
                              shape: const StadiumBorder(),
                              shadows: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
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
          ),
        ),
      ),
    );
  }
}

/// Segmented picker with a sprung indicator. [ink] lets it sit on glass.
class Segmented<T> extends StatefulWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.labels,
    required this.value,
    required this.onChanged,
    this.ink,
    this.onGlass = false,
  });
  final List<T> values;
  final List<String> labels;
  final T value;
  final ValueChanged<T> onChanged;
  final Color? ink;
  final bool onGlass;

  @override
  State<Segmented<T>> createState() => _SegmentedState<T>();
}

class _SegmentedState<T> extends State<Segmented<T>>
    with SingleTickerProviderStateMixin {
  late final SpringValue _pos = SpringValue(
    this,
    value: widget.values.indexOf(widget.value).toDouble(),
    spring: Motions.expressiveFast,
    settleDistance: 0.02,
    settleVelocity: 0.4,
  );

  @override
  void didUpdateWidget(Segmented<T> old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _pos.onSettle = Haptics.tick;
      _pos.animateTo(widget.values.indexOf(widget.value).toDouble());
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final Color ink = widget.ink ?? c.ink;
    final int n = widget.values.length;
    return SizedBox(
      height: 48,
      child: Center(
        child: Container(
          height: 40,
          decoration: ShapeDecoration(
            color: ink.withValues(alpha: widget.onGlass ? 0.12 : 0.07),
            shape: const StadiumBorder(),
          ),
          padding: const EdgeInsets.all(3),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final double seg = box.maxWidth / n;
              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  ListenableBuilder(
                    listenable: _pos,
                    builder: (BuildContext context, Widget? _) {
                      // Stretch a little while travelling.
                      final double stretch = (_pos.velocity.abs() * 0.9).clamp(
                        0.0,
                        10.0,
                      );
                      return Positioned(
                        left: seg * _pos.value - stretch / 2,
                        width: seg + stretch,
                        top: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: widget.onGlass
                                ? ink.withValues(alpha: 0.92)
                                : (c.dark ? c.surfaceHigh : Colors.white),
                            shape: StadiumBorder(
                              side: widget.onGlass
                                  ? BorderSide.none
                                  : BorderSide(color: c.hairline),
                            ),
                            shadows: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < n; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onChanged(widget.values[i]),
                            child: Center(
                              child: ListenableBuilder(
                                listenable: _pos,
                                builder: (BuildContext context, Widget? _) {
                                  final double sel =
                                      (1 - (_pos.value - i).abs()).clamp(
                                        0.0,
                                        1.0,
                                      );
                                  final Color selInk = widget.onGlass
                                      ? (c.dark
                                            ? const Color(0xFF14161B)
                                            : Colors.white)
                                      : ink;
                                  return Text(
                                    widget.labels[i],
                                    maxLines: 1,
                                    style: LumenType.text(
                                      13,
                                      weight: lerpDouble(500, 650, sel)!,
                                      color: Color.lerp(
                                        ink.withValues(alpha: 0.62),
                                        selInk,
                                        sel,
                                      ),
                                      height: 1.1,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Slider. Touch anywhere on the track: the thumb springs to the finger and
/// then follows it, growing slightly while held.
class LumenSlider extends StatefulWidget {
  const LumenSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.ink,
    this.fill,
  });
  final double value;
  final ValueChanged<double> onChanged;
  final Color? ink;
  final Color? fill;

  @override
  State<LumenSlider> createState() => _LumenSliderState();
}

class _LumenSliderState extends State<LumenSlider>
    with TickerProviderStateMixin {
  late final SpringValue _pos = SpringValue(
    this,
    value: widget.value,
    spring: Motions.follow,
  )..addListener(() => widget.onChanged(_pos.value.clamp(0.0, 1.0)));
  late final SpringValue _grab = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  double _width = 1;
  static const double _thumb = 26;

  double _toValue(double dx) =>
      ((dx - _thumb / 2) / (_width - _thumb)).clamp(0.0, 1.0);

  void _start(double dx) {
    _grab.animateTo(1, velocity: 10);
    _pos.animateTo(_toValue(dx));
  }

  void _end() {
    _grab.onSettle = Haptics.settle;
    _grab.animateTo(0);
  }

  @override
  void dispose() {
    _pos.dispose();
    _grab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final Color ink = widget.ink ?? c.ink;
    final Color fill = widget.fill ?? c.accent;
    return Semantics(
      slider: true,
      value: '${(widget.value * 100).round()}%',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          _width = box.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragDown: (DragDownDetails d) =>
                _start(d.localPosition.dx),
            onHorizontalDragUpdate: (DragUpdateDetails d) =>
                _pos.animateTo(_toValue(d.localPosition.dx)),
            onHorizontalDragEnd: (_) => _end(),
            onHorizontalDragCancel: _end,
            child: SizedBox(
              height: 48,
              child: ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[_pos, _grab]),
                builder: (BuildContext context, Widget? _) {
                  final double v = _pos.value.clamp(0.0, 1.0);
                  final double g = _grab.value;
                  final double x = _thumb / 2 + (_width - _thumb) * v;
                  final double size = _thumb + 6 * g;
                  final double trackH = 6 + 2 * g.clamp(0.0, 1.0);
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: <Widget>[
                      Container(
                        height: trackH,
                        decoration: ShapeDecoration(
                          color: ink.withValues(alpha: 0.18),
                          shape: const StadiumBorder(),
                        ),
                      ),
                      Container(
                        height: trackH,
                        width: x,
                        decoration: ShapeDecoration(
                          color: fill,
                          shape: const StadiumBorder(),
                        ),
                      ),
                      Positioned(
                        left: x - size / 2,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: const ShapeDecoration(
                            color: Colors.white,
                            shape: CircleBorder(),
                            shadows: <BoxShadow>[
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
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
    );
  }
}
