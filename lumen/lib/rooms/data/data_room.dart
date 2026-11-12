import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/room_header.dart';
import '../details/small_things.dart';

class _Series {
  const _Series(this.name, this.labels, this.values, this.unit);
  final String name;
  final List<String> labels;
  final List<double> values;
  final String unit;
}

List<double> _gen(int n, int seed, double base, double amp) {
  final math.Random r = math.Random(seed);
  double v = base;
  return List<double>.generate(n, (int i) {
    v = (v + (r.nextDouble() - 0.45) * amp).clamp(base * 0.35, base * 1.9);
    return (v + amp * 0.6 * math.sin(i * 0.9)).roundToDouble();
  });
}

final List<_Series> _series = <_Series>[
  _Series(
    'Week',
    const <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    _gen(7, 3, 8200, 2600),
    'steps',
  ),
  _Series(
    'Month',
    List<String>.generate(30, (int i) => '${i + 1} Nov'),
    _gen(30, 9, 7600, 2100),
    'steps',
  ),
  _Series(
    'Year',
    const <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ],
    _gen(12, 5, 7000, 1500),
    'avg steps',
  ),
];

/// Resamples a series to [n] evenly spaced points, so two series with
/// different lengths can morph point for point.
List<double> _resample(List<double> v, int n) {
  return List<double>.generate(n, (int i) {
    final double x = i / (n - 1) * (v.length - 1);
    final int a = x.floor(), b = math.min(a + 1, v.length - 1);
    final double t = x - a;
    // Smoothstep between samples keeps the line soft.
    final double s = t * t * (3 - 2 * t);
    return v[a] + (v[b] - v[a]) * s;
  });
}

/// Room 11. Numbers that move with meaning: a chart that morphs between
/// ranges, a scrubber with a magnetic cursor, and bars that grow in order.
class DataRoom extends StatefulWidget {
  const DataRoom({super.key});

  @override
  State<DataRoom> createState() => _DataRoomState();
}

class _DataRoomState extends State<DataRoom> with TickerProviderStateMixin {
  static const int _samples = 90;
  int _s = 0;
  List<double> _from = _resample(_series[0].values, _samples);
  List<double> _to = _resample(_series[0].values, _samples);
  double _maxFrom = 0, _maxTo = 0;
  late final SpringValue _t = SpringValue(
    this,
    value: 1,
    spring: Motions.spatial,
  );
  late final SpringValue _cursorX = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _cursorOn = SpringValue(this, spring: Motions.effects);
  late final SpringValue _dotsIn = SpringValue(
    this,
    value: 1,
    spring: Motions.effects,
  );
  int? _hover;

  @override
  void initState() {
    super.initState();
    _maxFrom = _maxTo = _niceMax(_series[0].values);
  }

  @override
  void dispose() {
    for (final SpringValue s in <SpringValue>[
      _t,
      _cursorX,
      _cursorOn,
      _dotsIn,
    ]) {
      s.dispose();
    }
    super.dispose();
  }

  double _niceMax(List<double> v) =>
      ((v.reduce(math.max) * 1.15) / 2000).ceil() * 2000.0;

  void _choose(int i) {
    final double t = _t.value.clamp(0.0, 1.0);
    setState(() {
      _from = List<double>.generate(
        _samples,
        (int k) => _from[k] + (_to[k] - _from[k]) * t,
      );
      _maxFrom = _maxFrom + (_maxTo - _maxFrom) * t;
      _to = _resample(_series[i].values, _samples);
      _maxTo = _niceMax(_series[i].values);
      _s = i;
      _hover = null;
    });
    _cursorOn.animateTo(0);
    _t.jumpTo(0);
    _t.animateTo(1);
    _dotsIn.jumpTo(0);
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) {
        _dotsIn.animateTo(1);
      }
    });
  }

  void _scrub(Offset local, double width) {
    final List<double> v = _series[_s].values;
    final double x = (local.dx / width).clamp(0.0, 1.0);
    // Magnetic: the cursor snaps to the nearest real data point.
    final int i = (x * (v.length - 1)).round();
    if (i != _hover) {
      setState(() => _hover = i);
      Haptics.tick();
    }
    _cursorX.animateTo(i / (v.length - 1));
    _cursorOn.animateTo(1);
  }

  void _endScrub() {
    _cursorOn.animateTo(0);
    setState(() => _hover = null);
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final _Series s = _series[_s];
    final int total = s.values
        .fold<double>(0, (double a, double b) => a + b)
        .round();
    final int shown = _hover != null
        ? s.values[_hover!].round()
        : (total / s.values.length).round();
    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 32),
        children: <Widget>[
          const RoomHeader(
            number: 11,
            title: 'Data',
            hint:
                'Trend: data that explains itself through motion. Values glide to their new place '
                'instead of jumping, so you can see what changed. Drag across the chart to read it.',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: ShapeDecoration(
              color: c.surface,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: c.hairline),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _hover != null
                      ? s.labels[_hover!].toUpperCase()
                      : 'DAILY AVERAGE, ${s.name.toUpperCase()}',
                  style: LumenType.label(color: c.inkFaint),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Odometer(
                      value: shown,
                      digits: 5,
                      style: LumenType.display(
                        42,
                        weight: 700,
                        color: c.ink,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        s.unit,
                        style: LumenType.text(14, color: c.inkMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 210,
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) =>
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragDown: (DragDownDetails d) =>
                              _scrub(d.localPosition, box.maxWidth),
                          onHorizontalDragUpdate: (DragUpdateDetails d) =>
                              _scrub(d.localPosition, box.maxWidth),
                          onHorizontalDragEnd: (_) => _endScrub(),
                          onHorizontalDragCancel: _endScrub,
                          child: ListenableBuilder(
                            listenable: Listenable.merge(<Listenable>[
                              _t,
                              _cursorX,
                              _cursorOn,
                              _dotsIn,
                            ]),
                            builder: (BuildContext context, Widget? _) =>
                                CustomPaint(
                                  size: Size(box.maxWidth, 210),
                                  painter: _LinePainter(
                                    from: _from,
                                    to: _to,
                                    t: _t.value,
                                    maxFrom: _maxFrom,
                                    maxTo: _maxTo,
                                    points: s.values,
                                    dots: _dotsIn.value,
                                    cursorX: _cursorX.value,
                                    cursorOn: _cursorOn.value,
                                    hover: _hover,
                                    c: c,
                                  ),
                                ),
                          ),
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                Segmented<int>(
                  values: const <int>[0, 1, 2],
                  labels: _series.map((_Series x) => x.name).toList(),
                  value: _s,
                  onChanged: _choose,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Bars(
            key: ValueKey<int>(_s),
            values: _series[_s].values.take(7).toList(),
            labels: _series[_s].labels.take(7).toList(),
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.from,
    required this.to,
    required this.t,
    required this.maxFrom,
    required this.maxTo,
    required this.points,
    required this.dots,
    required this.cursorX,
    required this.cursorOn,
    required this.hover,
    required this.c,
  });
  final List<double> from, to, points;
  final double t, maxFrom, maxTo, dots, cursorX, cursorOn;
  final int? hover;
  final LumenColors c;

  @override
  void paint(Canvas canvas, Size size) {
    const double bottom = 22;
    final double h = size.height - bottom;
    final double max = maxFrom + (maxTo - maxFrom) * t;
    double y(double v) => h - v / max * h;

    // Grid lines with values; they slide with the scale.
    for (int g = 1; g <= 4; g++) {
      final double v = max * g / 4;
      canvas.drawLine(
        Offset(0, y(v)),
        Offset(size.width, y(v)),
        Paint()..color = c.ink.withValues(alpha: 0.07),
      );
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k',
          style: LumenType.text(10.5, color: c.inkFaint),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width, y(v) - tp.height - 2));
      tp.dispose();
    }

    final int n = from.length;
    final Path line = Path();
    for (int i = 0; i < n; i++) {
      final double v = from[i] + (to[i] - from[i]) * t;
      final Offset p = Offset(i / (n - 1) * size.width, y(v));
      i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
    }
    final Path area = Path.from(line)
      ..lineTo(size.width, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, h), <Color>[
          c.accent.withValues(alpha: 0.28),
          c.accent.withValues(alpha: 0),
        ]),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = c.accent,
    );

    // Real data points, faded in after the morph lands.
    if (points.length <= 31) {
      for (int i = 0; i < points.length; i++) {
        final double v = points[i];
        final Offset p = Offset(i / (points.length - 1) * size.width, y(v));
        canvas.drawCircle(p, 3.5 * dots, Paint()..color = c.surface);
        canvas.drawCircle(
          p,
          3.5 * dots,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = c.accent.withValues(alpha: dots.clamp(0.0, 1.0)),
        );
      }
    }

    if (cursorOn > 0.01 && hover != null) {
      final double x = cursorX * size.width;
      final double v = points[hover!];
      final Offset p = Offset(x, y(v));
      final double a = cursorOn.clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, h),
        Paint()
          ..color = c.ink.withValues(alpha: 0.25 * a)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        p,
        11 * a,
        Paint()..color = c.accent.withValues(alpha: 0.2 * a),
      );
      canvas.drawCircle(p, 6 * a, Paint()..color = c.accent);
      canvas.drawCircle(p, 3 * a, Paint()..color = c.surface);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => true;
}

class _Bars extends StatefulWidget {
  const _Bars({super.key, required this.values, required this.labels});
  final List<double> values;
  final List<String> labels;

  @override
  State<_Bars> createState() => _BarsState();
}

class _BarsState extends State<_Bars> with TickerProviderStateMixin {
  late final List<SpringValue> _grow = <SpringValue>[
    for (int i = 0; i < widget.values.length; i++)
      SpringValue(this, spring: Motions.expressive),
  ];
  late final List<SpringValue> _focus = <SpringValue>[
    for (int i = 0; i < widget.values.length; i++)
      SpringValue(this, value: 1, spring: Motions.effects),
  ];
  int? _sel;

  @override
  void initState() {
    super.initState();
    // A wave from left to right.
    for (int i = 0; i < _grow.length; i++) {
      Future<void>.delayed(Duration(milliseconds: 40 * i), () {
        if (mounted) {
          _grow[i].animateTo(1);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final SpringValue s in <SpringValue>[..._grow, ..._focus]) {
      s.dispose();
    }
    super.dispose();
  }

  void _tap(int i) {
    setState(() => _sel = _sel == i ? null : i);
    for (int k = 0; k < _focus.length; k++) {
      _focus[k].animateTo(_sel == null || _sel == k ? 1 : 0.3);
    }
    Haptics.tick();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final double max = widget.values.reduce(math.max);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: ShapeDecoration(
        color: c.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: c.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'FIRST SEVEN, TAP A BAR',
            style: LumenType.label(color: c.inkFaint),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (int i = 0; i < widget.values.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _tap(i),
                      child: ListenableBuilder(
                        listenable: Listenable.merge(<Listenable>[
                          _grow[i],
                          _focus[i],
                        ]),
                        builder: (BuildContext context, Widget? _) {
                          final double g = _grow[i].value;
                          final double f = _focus[i].value;
                          return Opacity(
                            opacity: f.clamp(0.0, 1.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                if (_sel == i)
                                  Text(
                                    '${(widget.values[i] / 1000).toStringAsFixed(1)}k',
                                    style: LumenType.text(
                                      12,
                                      weight: 650,
                                      color: c.ink,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 26,
                                  height: math.max(
                                    0,
                                    120 * widget.values[i] / max * g,
                                  ),
                                  decoration: ShapeDecoration(
                                    color: _sel == i
                                        ? c.accent
                                        : c.accent.withValues(alpha: 0.55),
                                    shape: RoundedSuperellipseBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.labels[i].split(' ').first,
                                  style: LumenType.text(11, color: c.inkMuted),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
