import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Where the carried lens is, and everything on screen it can explain.
class LensBus {
  LensBus._();
  static final LensBus instance = LensBus._();

  /// Centre of the lens in screen coordinates, or null while it is a button.
  final ValueNotifier<Offset?> pos = ValueNotifier<Offset?>(null);
  final Set<LensTargetState> targets = <LensTargetState>{};

  /// The thing the lens is properly over on [page], if any.
  LensTargetState? over(String page) {
    final Offset? p = pos.value;
    if (p == null) {
      return null;
    }
    LensTargetState? best;
    double bestNear = 0.86;
    for (final LensTargetState t in targets) {
      if (t.widget.page != page) {
        continue;
      }
      final double n = t.near(p);
      if (n > bestNear) {
        bestNear = n;
        best = t;
      }
    }
    return best;
  }
}

/// Marks a piece of a page as something the lens can explain. It swells as
/// the lens approaches. With [actions], the lens turns into a pill offering
/// them; without, the lens only explains.
class LensTarget extends StatefulWidget {
  const LensTarget({
    super.key,
    required this.page,
    required this.title,
    required this.explain,
    required this.color,
    this.actions = const <(String, VoidCallback)>[],
    required this.child,
  });
  final String page, title, explain;
  final Color color;
  final List<(String, VoidCallback)> actions;
  final Widget child;

  @override
  State<LensTarget> createState() => LensTargetState();
}

class LensTargetState extends State<LensTarget> {
  @override
  void initState() {
    super.initState();
    LensBus.instance.targets.add(this);
  }

  @override
  void dispose() {
    LensBus.instance.targets.remove(this);
    super.dispose();
  }

  Rect? get rect {
    final RenderObject? r = context.findRenderObject();
    if (r is! RenderBox || !r.attached || !r.hasSize) {
      return null;
    }
    return r.localToGlobal(Offset.zero) & r.size;
  }

  /// 0 when the lens is far away, 1 when it is on this.
  double near(Offset p) {
    final Rect? r = rect;
    if (r == null) {
      return 0;
    }
    final double dx = math.max(0, math.max(r.left - p.dx, p.dx - r.right));
    final double dy = math.max(0, math.max(r.top - p.dy, p.dy - r.bottom));
    final double t = (1 - math.sqrt(dx * dx + dy * dy) / 64).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset?>(
      valueListenable: LensBus.instance.pos,
      child: widget.child,
      builder: (BuildContext context, Offset? p, Widget? child) {
        final double n = p == null ? 0 : near(p);
        if (n <= 0.001) {
          return child!;
        }
        // Scaling is done without a layout change, so the measured rectangle stays put.
        return Transform.scale(
          scale: 1 + 0.035 * n,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.7 * n),
                  width: 2 * n,
                ),
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
