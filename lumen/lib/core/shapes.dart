import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// A shape described as its radius in every direction around the centre.
/// Two shapes morph by blending those radii direction by direction, so every
/// in-between frame is a clean, closed outline with no tangles.
class MorphShape {
  const MorphShape(this.name, this.radii);
  final String name;
  final Float32List radii;
}

abstract final class ShapeLib {
  static const int samples = 180;
  static const int _fine = 720;

  /// Direction of sample [i] of [n]: 0 points up, increasing clockwise.
  static double _dir(int i, int n) => i / n * 2 * math.pi;

  static Float32List _fromFn(double Function(double a) f) {
    final Float32List out = Float32List(samples);
    for (int i = 0; i < samples; i++) {
      out[i] = f(_dir(i, samples));
    }
    return _normalize(out);
  }

  /// Regular polygon with a corner at the top. Corners are rounded by
  /// averaging the radius over neighbouring directions.
  static Float32List _polygon(int k, double rounding) {
    final Float64List fine = Float64List(_fine);
    final double seg = 2 * math.pi / k;
    for (int i = 0; i < _fine; i++) {
      final double phi = (_dir(i, _fine) % seg) - seg / 2;
      fine[i] = math.cos(math.pi / k) / math.cos(phi);
    }
    final int w = (rounding * _fine).round();
    const int step = _fine ~/ samples;
    final Float32List out = Float32List(samples);
    for (int i = 0; i < samples; i++) {
      double sum = 0;
      for (int j = -w; j <= w; j++) {
        sum += fine[(i * step + j) % _fine];
      }
      out[i] = sum / (2 * w + 1);
    }
    return _normalize(out);
  }

  static double _sdRoundBox(
    double x,
    double y,
    double bx,
    double by,
    double r,
  ) {
    final double qx = x.abs() - bx + r, qy = y.abs() - by + r;
    final double ox = math.max(qx, 0.0), oy = math.max(qy, 0.0);
    return math.sqrt(ox * ox + oy * oy) + math.min(math.max(qx, qy), 0.0) - r;
  }

  /// Distance from the centre to the edge of a distance-field shape.
  static double _ray(double a, double Function(double x, double y) sdf) {
    double lo = 0, hi = 4;
    final double dx = math.sin(a), dy = -math.cos(a);
    for (int i = 0; i < 32; i++) {
      final double mid = (lo + hi) / 2;
      if (sdf(dx * mid, dy * mid) < 0) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Scale so shapes read as the same size: halfway between matching their
  /// furthest point and matching their area.
  static Float32List _normalize(Float32List r) {
    double max = 0, sq = 0;
    for (final double v in r) {
      max = math.max(max, v);
      sq += v * v;
    }
    final double rms = math.sqrt(sq / r.length);
    final double s = 0.5 * max + 0.5 * rms;
    for (int i = 0; i < r.length; i++) {
      r[i] = r[i] / s;
    }
    return r;
  }

  static double _superellipse(double a, double n) {
    final double c = math.pow(math.cos(a).abs(), n).toDouble();
    final double s = math.pow(math.sin(a).abs(), n).toDouble();
    return math.pow(c + s, -1 / n).toDouble();
  }

  static final List<MorphShape> gallery = <MorphShape>[
    MorphShape('Circle', _fromFn((double a) => 1)),
    MorphShape('Cookie', _fromFn((double a) => 1 + 0.09 * math.cos(7 * a))),
    MorphShape('Clover', _fromFn((double a) => 1 + 0.22 * math.cos(4 * a))),
    MorphShape('Triangle', _polygon(3, 0.045)),
    MorphShape('Squircle', _fromFn((double a) => _superellipse(a, 4))),
    MorphShape('Burst', _fromFn((double a) => 1 + 0.07 * math.cos(12 * a))),
    MorphShape(
      'Pill',
      _fromFn(
        (double a) =>
            _ray(a, (double x, double y) => _sdRoundBox(x, y, 1, 0.56, 0.56)),
      ),
    ),
    MorphShape('Pentagon', _polygon(5, 0.035)),
  ];

  /// The loading indicator's cycle, in the spirit of M3 Expressive.
  static final List<MorphShape> loader = <MorphShape>[
    MorphShape('Cookie 9', _fromFn((double a) => 1 + 0.10 * math.cos(9 * a))),
    MorphShape('Pentagon', _polygon(5, 0.05)),
    MorphShape('Clover', _fromFn((double a) => 1 + 0.18 * math.cos(4 * a))),
    MorphShape(
      'Oval',
      _fromFn(
        (double a) =>
            _ray(a, (double x, double y) => _sdRoundBox(x, y, 1, 0.7, 0.7)),
      ),
    ),
    MorphShape('Burst', _fromFn((double a) => 1 + 0.08 * math.cos(12 * a))),
    MorphShape('Cookie 4', _fromFn((double a) => 1 + 0.12 * math.cos(4 * a))),
  ];

  /// Outline between two shapes. [t] 0 is [a], 1 is [b].
  static Path lerpPath(
    Float32List a,
    Float32List b,
    double t,
    Offset c,
    double scale,
    double rotation,
  ) {
    const int n = samples;
    final List<Offset> pts = List<Offset>.generate(n, (int i) {
      final double r = (a[i] + (b[i] - a[i]) * t) * scale;
      final double ang = _dir(i, n) + rotation;
      return Offset(c.dx + math.sin(ang) * r, c.dy - math.cos(ang) * r);
    }, growable: false);
    // Quadratic curves through the midpoints: smooth at any size.
    Offset mid(int i) => (pts[i % n] + pts[(i + 1) % n]) / 2;
    final Offset m0 = mid(0);
    final Path p = Path()..moveTo(m0.dx, m0.dy);
    for (int i = 1; i <= n; i++) {
      final Offset q = pts[i % n];
      final Offset m = mid(i);
      p.quadraticBezierTo(q.dx, q.dy, m.dx, m.dy);
    }
    return p..close();
  }

  /// Outline at a continuous position [v] along a cyclic sequence.
  static Path at(
    List<MorphShape> seq,
    double v,
    Offset c,
    double scale,
    double rotation,
  ) {
    final int i0 = v.floor();
    final double t = v - i0;
    return lerpPath(
      seq[i0 % seq.length].radii,
      seq[(i0 + 1) % seq.length].radii,
      t,
      c,
      scale,
      rotation,
    );
  }
}
