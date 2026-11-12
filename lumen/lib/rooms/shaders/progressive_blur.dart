import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/glass.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';

/// Blur that grows from nothing at the bottom edge of this box to [maxBlur]
/// at its top edge, over whatever scrolls underneath.
class ProgressiveBlur extends StatelessWidget {
  const ProgressiveBlur({super.key, this.maxBlur = 26});
  final double maxBlur;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, Widget? _) {
        final LumenColors c = LumenColors.of(context);
        final GlassQuality q = settings.effectiveQuality;
        if (settings.reduceTransparency) {
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[c.bg, c.bg.withValues(alpha: 0)],
              ),
            ),
          );
        }
        if (q == GlassQuality.low ||
            GlassShaders.pblur == null ||
            !ui.ImageFilter.isShaderFilterSupported) {
          return _SteppedBlur(maxBlur: maxBlur, tint: c.bg);
        }
        return _PBlurRender(
          maxBlur: maxBlur,
          taps: q == GlassQuality.full ? 56 : 28,
          tint: c.bg,
          dpr: MediaQuery.devicePixelRatioOf(context),
          motion: routeMotionOf(context),
        );
      },
    );
  }
}

/// Low tier: four bands of ordinary blur, stronger toward the top.
class _SteppedBlur extends StatelessWidget {
  const _SteppedBlur({required this.maxBlur, required this.tint});
  final double maxBlur;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    const int bands = 4;
    return Column(
      children: <Widget>[
        for (int i = 0; i < bands; i++)
          Expanded(
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: maxBlur * 0.5 * (1 - i / bands),
                  sigmaY: maxBlur * 0.5 * (1 - i / bands),
                ),
                child: ColoredBox(
                  color: tint.withValues(alpha: 0.4 * (1 - i / bands)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PBlurRender extends LeafRenderObjectWidget {
  const _PBlurRender({
    required this.maxBlur,
    required this.taps,
    required this.tint,
    required this.dpr,
    required this.motion,
  });
  final double maxBlur;
  final int taps;
  final Color tint;
  final double dpr;
  final Listenable? motion;

  @override
  _RenderPBlur createRenderObject(BuildContext context) => _RenderPBlur()
    ..maxBlur = maxBlur
    ..taps = taps
    ..tint = tint
    ..dpr = dpr
    ..motion = motion;

  @override
  void updateRenderObject(BuildContext context, _RenderPBlur r) {
    r
      ..maxBlur = maxBlur
      ..taps = taps
      ..tint = tint
      ..dpr = dpr
      ..motion = motion;
  }
}

class _RenderPBlur extends RenderBox {
  double maxBlur = 26;
  int taps = 56;
  Color tint = const Color(0xFF000000);
  double dpr = 1;
  Listenable? _motion;
  set motion(Listenable? v) {
    if (identical(v, _motion)) {
      return;
    }
    if (attached) {
      _motion?.removeListener(markNeedsPaint);
      v?.addListener(markNeedsPaint);
    }
    _motion = v;
  }

  ui.FragmentShader? _shader;
  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();
  final LayerHandle<BackdropFilterLayer> _layer =
      LayerHandle<BackdropFilterLayer>();

  @override
  bool get sizedByParent => true;
  @override
  bool get alwaysNeedsCompositing => true;
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _motion?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _motion?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    _layer.layer = null;
    _shader?.dispose();
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final ui.FragmentShader shader = _shader ??= GlassShaders.pblur!
        .fragmentShader();
    final Matrix4 m = getTransformTo(null);
    final double sy =
        dpr *
        math.sqrt(m.storage[4] * m.storage[4] + m.storage[5] * m.storage[5]);
    final Offset topLeft = MatrixUtils.transformPoint(m, Offset.zero) * dpr;
    final Offset bottom =
        MatrixUtils.transformPoint(m, Offset(0, size.height)) * dpr;
    final Size screen =
        (owner!.rootNode! as RenderView).flutterView.physicalSize;
    final Rect visible = visibleScreenRect(this, m);
    final Rect vis = Rect.fromLTRB(
      visible.left * dpr,
      visible.top * dpr,
      visible.right * dpr,
      visible.bottom * dpr,
    ).intersect(Offset.zero & screen);
    final double left = vis.left.floorToDouble(), top = vis.top.floorToDouble();
    shader
      ..setFloat(2, left)
      ..setFloat(3, top)
      ..setFloat(4, vis.right.ceilToDouble() - left)
      ..setFloat(5, vis.bottom.ceilToDouble() - top)
      ..setFloat(6, screen.width)
      ..setFloat(7, screen.height)
      ..setFloat(8, topLeft.dy)
      ..setFloat(9, bottom.dy)
      ..setFloat(10, maxBlur * sy)
      ..setFloat(11, taps.toDouble())
      ..setFloat(12, tint.r)
      ..setFloat(13, tint.g)
      ..setFloat(14, tint.b)
      ..setFloat(15, 0.5);
    _clip.layer = context.pushClipRect(true, offset, Offset.zero & size, (
      PaintingContext context,
      Offset offset,
    ) {
      final BackdropFilterLayer layer = _layer.layer ??= BackdropFilterLayer();
      layer.filter = ui.ImageFilter.shader(shader);
      context.pushLayer(
        layer,
        (PaintingContext context, Offset offset) {},
        offset,
      );
    }, oldLayer: _clip.layer);
  }
}
