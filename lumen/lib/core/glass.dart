import 'dart:math' as math;
import 'dart:ui' as ui;

import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import 'expand_route.dart';
import 'settings.dart';
import 'theme.dart';

/// The part of [box] that survives every ancestor clip, in logical screen
/// coordinates. The engine crops a backdrop to this.
Rect visibleScreenRect(RenderBox box, Matrix4 toScreen) {
  Rect r = MatrixUtils.transformRect(toScreen, Offset.zero & box.size);
  RenderObject child = box;
  RenderObject? p = box.parent;
  while (p != null) {
    final Rect? clip = p.describeApproximatePaintClip(child);
    if (clip != null) {
      r = r.intersect(MatrixUtils.transformRect(p.getTransformTo(null), clip));
    }
    child = p;
    p = p.parent;
  }
  return r;
}

/// The listenable that moves the screen [context] is on, if any.
Listenable? routeMotionOf(BuildContext context) =>
    switch (ModalRoute.of(context)) {
      final ExpandRoute<dynamic> r => r.motion,
      final ModalRoute<dynamic> r => r.animation,
      null => null,
    };

/// Loads the glass shader once, before the first frame, so there is no pop.
abstract final class GlassShaders {
  static ui.FragmentProgram? _program;
  static ui.FragmentProgram? aurora;
  static ui.FragmentProgram? ripple;
  static ui.FragmentProgram? pblur;
  static ui.FragmentProgram? disco;
  static ui.FragmentProgram? holo;

  static Future<ui.FragmentProgram?> _try(String asset) async {
    try {
      return await ui.FragmentProgram.fromAsset(asset);
    } catch (_) {
      return null;
    }
  }

  static Future<void> load() async {
    final List<ui.FragmentProgram?> p = await Future.wait(
      <Future<ui.FragmentProgram?>>[
        _try('shaders/glass.frag'),
        _try('shaders/aurora.frag'),
        _try('shaders/ripple.frag'),
        _try('shaders/pblur.frag'),
        _try('shaders/disco.frag'),
        _try('shaders/holo.frag'),
      ],
    );
    _program = p[0];
    aurora = p[1];
    ripple = p[2];
    pblur = p[3];
    disco = p[4];
    holo = p[5];
    await _prewarm();
  }

  /// Draws every shader once, off screen, so the GPU prepares them before
  /// they are first needed instead of during a room's opening animation.
  static Future<void> _prewarm() async {
    try {
      final ui.PictureRecorder rec = ui.PictureRecorder();
      final Canvas canvas = Canvas(rec);
      const Rect r = Rect.fromLTWH(0, 0, 8, 8);
      for (final ui.FragmentProgram? p in <ui.FragmentProgram?>[
        aurora,
        disco,
        holo,
      ]) {
        if (p != null) {
          canvas.drawRect(r, Paint()..shader = p.fragmentShader());
          canvas.drawRect(
            r,
            Paint()
              ..shader = p.fragmentShader()
              ..blendMode = BlendMode.screen,
          );
        }
      }
      if (ui.ImageFilter.isShaderFilterSupported) {
        for (final ui.FragmentProgram? p in <ui.FragmentProgram?>[
          _program,
          pblur,
          ripple,
        ]) {
          if (p != null) {
            canvas.saveLayer(
              r,
              Paint()..imageFilter = ui.ImageFilter.shader(p.fragmentShader()),
            );
            canvas.drawRect(r, Paint()..color = const Color(0xFF808080));
            canvas.restore();
          }
        }
      }
      final ui.Image img = await rec.endRecording().toImage(8, 8);
      img.dispose();
    } catch (_) {
      // Warming up is an optimisation; a failure here changes nothing else.
    }
  }

  static bool get available =>
      _program != null && ui.ImageFilter.isShaderFilterSupported;
}

/// How a piece of glass looks. Distances are logical pixels.
@immutable
class GlassStyle {
  const GlassStyle({
    this.blur = 14,
    this.refraction = 26,
    this.bevel = 18,
    this.dispersion = 0.22,
    this.magnify = 1,
    this.tint = 0.30,
    this.tintColor,
    this.light = 0.55,
    this.saturation = 1.3,
    this.adapt = 0.38,
    this.shadow = 1,
    this.fallbackColor,
  });

  final double blur;
  final double refraction;
  final double bevel;
  final double dispersion;
  final double magnify;

  /// 0 is clear, 1 is fully tinted.
  final double tint;
  final Color? tintColor;
  final double light;
  final double saturation;
  final double adapt;
  final double shadow;

  /// Fill used when transparency is reduced.
  final Color? fallbackColor;

  @override
  bool operator ==(Object other) =>
      other is GlassStyle &&
      other.blur == blur &&
      other.refraction == refraction &&
      other.bevel == bevel &&
      other.dispersion == dispersion &&
      other.magnify == magnify &&
      other.tint == tint &&
      other.tintColor == tintColor &&
      other.light == light &&
      other.saturation == saturation &&
      other.adapt == adapt &&
      other.shadow == shadow &&
      other.fallbackColor == fallbackColor;

  @override
  int get hashCode => Object.hash(
    blur,
    refraction,
    bevel,
    dispersion,
    magnify,
    tint,
    tintColor,
    light,
    saturation,
    adapt,
    shadow,
    fallbackColor,
  );
}

/// A glass surface for controls. Renders in one of four ways:
///  full    blur, refraction, colour dispersion, rim light
///  medium  blur, weaker refraction, rim light
///  low     blur and tint only
///  solid   an opaque surface, when transparency is reduced
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.radius,
    this.style = const GlassStyle(),
    this.hole,
    this.child,
    this.quality,
    this.solid,
  });

  final double radius;
  final GlassStyle style;

  /// Set to overrule the app-wide setting for this one piece of glass.
  final GlassQuality? quality;
  final bool? solid;

  /// A rounded hole (local coordinates) left untouched, so another piece of
  /// glass can sit in it and see the unblurred backdrop.
  final RRect? hole;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, Widget? child) {
        final LumenColors c = LumenColors.of(context);
        return _GlassRender(
          radius: radius,
          style: style,
          hole: hole,
          colors: c,
          quality: GlassShaders.available
              ? (quality ?? settings.effectiveQuality)
              : GlassQuality.low,
          solid: solid ?? settings.reduceTransparency,
          dpr: MediaQuery.devicePixelRatioOf(context),
          routeAnimation: routeMotionOf(context),
          child: child,
        );
      },
      child: child,
    );
  }
}

class _GlassRender extends SingleChildRenderObjectWidget {
  const _GlassRender({
    required this.radius,
    required this.style,
    required this.hole,
    required this.colors,
    required this.quality,
    required this.solid,
    required this.dpr,
    required this.routeAnimation,
    super.child,
  });

  final double dpr;
  final Listenable? routeAnimation;

  final double radius;
  final GlassStyle style;
  final RRect? hole;
  final LumenColors colors;
  final GlassQuality quality;
  final bool solid;

  @override
  RenderGlass createRenderObject(BuildContext context) => RenderGlass(
    radius: radius,
    style: style,
    hole: hole,
    colors: colors,
    quality: quality,
    solid: solid,
    dpr: dpr,
    routeAnimation: routeAnimation,
  );

  @override
  void updateRenderObject(BuildContext context, RenderGlass renderObject) {
    renderObject
      ..radius = radius
      ..style = style
      ..hole = hole
      ..colors = colors
      ..quality = quality
      ..solid = solid
      ..dpr = dpr
      ..routeAnimation = routeAnimation;
  }
}

/// Glass needs to know where it is on screen. If something above it moves it
/// without repainting it (a window metrics change, an ancestor transform),
/// this notices after the frame and repaints with the new position.
abstract final class _GlassWatch {
  static final Set<RenderGlass> _live = <RenderGlass>{};
  static bool _registered = false;

  static void add(RenderGlass g) {
    _live.add(g);
    if (!_registered) {
      _registered = true;
      SchedulerBinding.instance.addPersistentFrameCallback((_) {
        for (final RenderGlass g in _live) {
          g._checkTransform();
        }
      });
    }
  }

  static void remove(RenderGlass g) => _live.remove(g);
}

class RenderGlass extends RenderProxyBox {
  RenderGlass({
    required this._radius,
    required this._style,
    required this._hole,
    required this._colors,
    required this._quality,
    required this._solid,
    required this._dpr,
    this._routeAnimation,
  });

  // While the screen this glass belongs to is still opening or closing, the
  // route's clip moves every frame, so the glass repaints every frame too.
  Listenable? _routeAnimation;
  set routeAnimation(Listenable? v) {
    if (identical(v, _routeAnimation)) {
      return;
    }
    if (attached) {
      _routeAnimation?.removeListener(markNeedsPaint);
      v?.addListener(markNeedsPaint);
    }
    _routeAnimation = v;
  }

  double _dpr;
  set dpr(double v) {
    if (v != _dpr) {
      _dpr = v;
      markNeedsPaint();
    }
  }

  double _radius;
  set radius(double v) {
    if (v != _radius) {
      _radius = v;
      markNeedsPaint();
    }
  }

  GlassStyle _style;
  set style(GlassStyle v) {
    if (v != _style) {
      _style = v;
      markNeedsPaint();
    }
  }

  RRect? _hole;
  set hole(RRect? v) {
    if (v != _hole) {
      _hole = v;
      markNeedsPaint();
    }
  }

  LumenColors _colors;
  set colors(LumenColors v) {
    if (v != _colors) {
      _colors = v;
      markNeedsPaint();
    }
  }

  GlassQuality _quality;
  set quality(GlassQuality v) {
    if (v != _quality) {
      _quality = v;
      markNeedsPaint();
    }
  }

  bool _solid;
  set solid(bool v) {
    if (v != _solid) {
      _solid = v;
      markNeedsCompositingBitsUpdate();
      markNeedsPaint();
    }
  }

  ui.FragmentShader? _shader;
  final LayerHandle<ClipPathLayer> _clipLayer = LayerHandle<ClipPathLayer>();
  final LayerHandle<BackdropFilterLayer> _blurLayer =
      LayerHandle<BackdropFilterLayer>();
  final LayerHandle<BackdropFilterLayer> _refractLayer =
      LayerHandle<BackdropFilterLayer>();

  Matrix4? _paintedTransform;
  Rect? _paintedVisible;

  Rect _visibleBounds(Matrix4 toScreen) => visibleScreenRect(this, toScreen);

  void _checkTransform() {
    final Matrix4? painted = _paintedTransform;
    if (painted == null || !attached) {
      return;
    }
    final Matrix4 now = getTransformTo(null);
    final Float64List a = painted.storage, b = now.storage;
    for (int i = 0; i < 16; i++) {
      if ((a[i] - b[i]).abs() > 1e-3) {
        markNeedsPaint();
        return;
      }
    }
    if (_visibleBounds(now) != _paintedVisible) {
      markNeedsPaint();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _GlassWatch.add(this);
    _routeAnimation?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _GlassWatch.remove(this);
    _routeAnimation?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => !_solid;

  @override
  void dispose() {
    _clipLayer.layer = null;
    _blurLayer.layer = null;
    _refractLayer.layer = null;
    _shader?.dispose();
    super.dispose();
  }

  RRect _shape(Rect rect) => RRect.fromRectAndRadius(
    rect,
    Radius.circular(math.min(_radius, rect.shortestSide / 2)),
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) {
      return;
    }
    final Rect rect = offset & size;
    final RRect shape = _shape(rect);

    if (_style.shadow > 0) {
      // Shadow only outside the shape, so it never darkens what the glass sees.
      final Canvas canvas = context.canvas;
      canvas.save();
      canvas.clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(rect.inflate(60)),
          Path()..addRRect(shape),
        ),
      );
      canvas.drawRRect(
        shape.shift(const Offset(0, 8)),
        Paint()
          ..color = _colors.shadow.withValues(
            alpha: _colors.shadow.a * _style.shadow,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.restore();
    }

    if (_solid) {
      _clipLayer.layer = null;
      _blurLayer.layer = null;
      _refractLayer.layer = null;
      _paintedTransform = null;
      final Canvas canvas = context.canvas;
      canvas.drawRRect(
        shape,
        Paint()..color = _style.fallbackColor ?? _colors.surfaceHigh,
      );
      canvas.drawRRect(
        shape.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _colors.ink.withValues(alpha: 0.14),
      );
      super.paint(context, offset);
      return;
    }

    final Rect local = Offset.zero & size;
    Path clip = Path()..addRRect(_shape(local));
    final RRect? hole = _hole;
    if (hole != null) {
      clip = Path.combine(
        PathOperation.difference,
        clip,
        Path()..addRRect(hole),
      );
    }

    final bool useShader = _quality != GlassQuality.low;
    final Color tintColor = _style.tintColor ?? _colors.glassTint;
    final ui.ImageFilter blur = ui.ImageFilter.blur(
      sigmaX: math.max(_style.blur, 0.01),
      sigmaY: math.max(_style.blur, 0.01),
    );

    // Two passes. The engine blurs the backdrop into the shape first; the
    // shader then reads the screen (which now contains that blur) and bends
    // it. Chaining blur and shader in a single filter is not used because the
    // engine pads blurred textures, which shifts the shader's coordinates.
    ui.ImageFilter? refract;
    if (useShader) {
      final ui.FragmentShader shader = _shader ??= GlassShaders._program!
          .fragmentShader();
      // Where this surface is on screen, in physical pixels: the same space
      // as the backdrop texture the shader samples.
      // getTransformTo gives logical pixels; the backdrop is in physical ones.
      final Matrix4 m = getTransformTo(null);
      _paintedTransform = m;
      final double dpr = _dpr;
      final Offset center =
          MatrixUtils.transformPoint(m, size.center(Offset.zero)) * dpr;
      final double sx =
          dpr *
          math.sqrt(m.storage[0] * m.storage[0] + m.storage[1] * m.storage[1]);
      final double sy =
          dpr *
          math.sqrt(m.storage[4] * m.storage[4] + m.storage[5] * m.storage[5]);
      final double s = math.min(sx, sy);
      final double halfW = size.width / 2 * sx, halfH = size.height / 2 * sy;
      final Size screen =
          (owner!.rootNode! as RenderView).flutterView.physicalSize;
      final Rect visible = _visibleBounds(m);
      _paintedVisible = visible;
      final Rect vis = Rect.fromLTRB(
        visible.left * dpr,
        visible.top * dpr,
        visible.right * dpr,
        visible.bottom * dpr,
      ).intersect(Offset.zero & screen);
      final double left = vis.left.floorToDouble();
      final double top = vis.top.floorToDouble();
      final bool medium = _quality == GlassQuality.medium;
      final double r = math.min(_radius, size.shortestSide / 2);
      shader
        ..setFloat(2, center.dx)
        ..setFloat(3, center.dy)
        ..setFloat(4, halfW)
        ..setFloat(5, halfH)
        ..setFloat(6, r * s)
        ..setFloat(7, math.min(_style.bevel, size.shortestSide / 2) * s)
        ..setFloat(8, _style.refraction * (medium ? 0.5 : 1) * s)
        ..setFloat(9, medium ? 0 : _style.dispersion)
        ..setFloat(10, _style.magnify)
        ..setFloat(11, tintColor.r)
        ..setFloat(12, tintColor.g)
        ..setFloat(13, tintColor.b)
        ..setFloat(14, _style.tint)
        ..setFloat(15, _style.light * (_colors.dark ? 1 : 1.25))
        ..setFloat(16, _style.saturation)
        ..setFloat(17, _style.adapt)
        ..setFloat(18, s)
        ..setFloat(19, left)
        ..setFloat(20, top)
        ..setFloat(21, vis.right.ceilToDouble() - left)
        ..setFloat(22, vis.bottom.ceilToDouble() - top)
        ..setFloat(23, screen.width)
        ..setFloat(24, screen.height);
      refract = ui.ImageFilter.shader(shader);
    } else {
      _refractLayer.layer = null;
      _paintedTransform = null;
      _paintedVisible = null;
    }

    _clipLayer.layer = context.pushClipPath(
      needsCompositing,
      offset,
      local,
      clip,
      (PaintingContext context, Offset offset) {
        void content(PaintingContext context, Offset offset) {
          if (refract == null) {
            _paintFlat(context.canvas, offset & size, tintColor);
            super.paint(context, offset);
            return;
          }
          final BackdropFilterLayer layer = _refractLayer.layer ??=
              BackdropFilterLayer();
          layer
            ..filter = refract
            ..blendMode = BlendMode.srcOver;
          context.pushLayer(layer, super.paint, offset);
        }

        if (_style.blur < 0.3) {
          _blurLayer.layer = null;
          content(context, offset);
          return;
        }
        final BackdropFilterLayer layer = _blurLayer.layer ??=
            BackdropFilterLayer();
        layer
          ..filter = blur
          ..blendMode = BlendMode.srcOver;
        context.pushLayer(layer, content, offset);
      },
      clipBehavior: Clip.antiAlias,
      oldLayer: _clipLayer.layer,
    );
  }

  /// Low tier: tint and a drawn rim instead of the shader.
  void _paintFlat(Canvas canvas, Rect rect, Color tintColor) {
    final RRect shape = _shape(rect);
    canvas.drawRRect(
      shape,
      Paint()
        ..color = tintColor.withValues(
          alpha: (_style.tint + 0.18).clamp(0, 0.96),
        ),
    );
    final Color w = Colors.white;
    canvas.drawRRect(
      shape.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          <Color>[
            w.withValues(alpha: 0.55 * _style.light),
            w.withValues(alpha: 0.08 * _style.light),
            w.withValues(alpha: 0.38 * _style.light),
          ],
          <double>[0, 0.5, 1],
        ),
    );
  }
}
