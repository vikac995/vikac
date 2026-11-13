import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/tag.dart';

const List<String> _lifts = <String>['Bench', 'Squat', 'Deadlift'];
const Map<String, List<String>> _labels = <String, List<String>>{
  '1M': <String>['wk 1', 'wk 2', 'wk 3', 'wk 4'],
  '3M': <String>['Sep', 'Oct', 'Nov'],
  '1Y': <String>['Dec', 'Mar', 'Jun', 'Sep'],
};

/// Room 45. A complete progress screen: one headline number, a chart you
/// can run a finger along, and the bests underneath.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  static const int _n = 12;
  int _lift = 0;
  String _period = '3M';
  int? _scrub;
  late List<double> _from = _series(), _to = _series();
  late final SpringValue _t = SpringValue(
    this,
    value: 1,
    spring: Motions.expressiveSlow,
  );

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  // Made-up but steady: each lift climbs, with a small wobble, faster over a year.
  List<double> _series() {
    final double base = <double>[72.5, 100, 125][_lift];
    final double gain = <String, double>{
      '1M': 2.5,
      '3M': 7.5,
      '1Y': 20,
    }[_period]!;
    final math.Random r = math.Random(
      _lift * 7 + _period.length * 31 + _period.codeUnitAt(0),
    );
    return <double>[
      for (int i = 0; i < _n; i++)
        ((base +
                        gain * i / (_n - 1) +
                        (i == 0 || i == _n - 1
                            ? 0
                            : (r.nextDouble() - 0.5) * gain * 0.35)) *
                    2)
                .round() /
            2,
    ];
  }

  void _change(VoidCallback f) {
    final List<double> now = _shown;
    setState(() {
      f();
      _from = now;
      _to = _series();
      _scrub = null;
    });
    _t.jumpTo(0);
    _t.animateTo(1);
  }

  List<double> get _shown => <double>[
    for (int i = 0; i < _n; i++) ui.lerpDouble(_from[i], _to[i], _t.value)!,
  ];

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    const Color green = Color(0xFF2FA84F);
    final double shown = _scrub == null ? _to.last : _to[_scrub!];
    final double delta = _to.last - _to.first;
    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 40),
        children: <Widget>[
          const ScreenBar(number: 45),
          const SizedBox(height: 20),
          Tag(
            'R45.1',
            'Switch what you are looking at',
            child: Row(
              children: <Widget>[
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        if (i != _lift) {
                          _change(() => _lift = i);
                          Haptics.tick();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: i == _lift ? c.ink : Colors.transparent,
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: i == _lift ? c.ink : c.inkFaint,
                            ),
                          ),
                        ),
                        child: Text(
                          _lifts[i],
                          style: LumenType.text(
                            14,
                            weight: 650,
                            color: i == _lift ? c.bg : c.ink,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Tag(
            'R45.2',
            'One headline number',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _scrub == null ? 'ESTIMATED BEST, ONE REP' : 'ON THAT DAY',
                  style: LumenType.label(color: c.inkMuted),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      _fmt(shown),
                      textScaler: TextScaler.noScaling,
                      style:
                          LumenType.display(
                            60,
                            weight: 720,
                            color: c.ink,
                            height: 1.05,
                          ).copyWith(
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 11, left: 6),
                      child: Text(
                        'kg',
                        style: LumenType.text(18, color: c.inkMuted),
                      ),
                    ),
                    const Spacer(),
                    if (_scrub == null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: ShapeDecoration(
                          color: green.withValues(alpha: 0.15),
                          shape: const StadiumBorder(),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.arrow_upward_rounded,
                              size: 15,
                              color: green,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${_fmt(delta)} kg',
                              style: LumenType.text(
                                13.5,
                                weight: 700,
                                color: green,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Tag(
            'R45.3',
            'A chart you can touch',
            child: SizedBox(
              height: 210,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  void at(double x) {
                    final int i = (x / box.maxWidth * (_n - 1)).round().clamp(
                      0,
                      _n - 1,
                    );
                    if (i != _scrub) {
                      setState(() => _scrub = i);
                      Haptics.tick();
                    }
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (DragStartDetails d) =>
                        at(d.localPosition.dx),
                    onHorizontalDragUpdate: (DragUpdateDetails d) =>
                        at(d.localPosition.dx),
                    onHorizontalDragEnd: (_) => setState(() => _scrub = null),
                    onTapDown: (TapDownDetails d) => at(d.localPosition.dx),
                    onTapUp: (_) => setState(() => _scrub = null),
                    onTapCancel: () {},
                    child: ListenableBuilder(
                      listenable: _t,
                      builder: (BuildContext context, Widget? _) => CustomPaint(
                        size: Size.infinite,
                        painter: _Chart(_shown, c.accent, c.ink, c.bg, _scrub),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (final String l in _labels[_period]!)
                  Text(l, style: LumenType.text(12, color: c.inkFaint)),
              ],
            ),
          ),
          Segmented<String>(
            values: const <String>['1M', '3M', '1Y'],
            labels: const <String>['Month', '3 months', 'Year'],
            value: _period,
            onChanged: (String v) => _change(() => _period = v),
          ),
          const SizedBox(height: 26),
          Text('BESTS', style: LumenType.label(color: c.inkMuted)),
          const SizedBox(height: 10),
          Tag(
            'R45.4',
            'Bests as plain rows',
            child: Container(
              decoration: ShapeDecoration(
                color: c.ink.withValues(alpha: 0.055),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Column(
                children: <Widget>[
                  for (final (int i, (String, String, String) r)
                      in const <(String, String, String)>[
                        ('Heaviest set', '80 kg × 8', '2 days ago'),
                        ('Most reps', '60 kg × 15', '3 weeks ago'),
                        ('Biggest session', '4,120 kg', 'October'),
                      ].indexed) ...<Widget>[
                    if (i > 0)
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(left: 16),
                        color: c.ink.withValues(alpha: 0.07),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              r.$1,
                              style: LumenType.text(15, color: c.inkMuted),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                r.$2,
                                style: LumenType.text(
                                  16,
                                  weight: 680,
                                  color: c.ink,
                                ),
                              ),
                              Text(
                                r.$3,
                                style: LumenType.text(12.5, color: c.inkFaint),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chart extends CustomPainter {
  const _Chart(this.v, this.accent, this.ink, this.bg, this.scrub);
  final List<double> v;
  final Color accent, ink, bg;
  final int? scrub;

  @override
  void paint(Canvas canvas, Size size) {
    final double lo = v.reduce(math.min), hi = v.reduce(math.max);
    final double pad = math.max(1.0, (hi - lo) * 0.25);
    Offset p(int i) => Offset(
      size.width * i / (v.length - 1),
      size.height -
          14 -
          (size.height - 34) * (v[i] - lo + pad) / (hi - lo + pad * 2),
    );
    for (int g = 0; g < 4; g++) {
      final double y = 10 + (size.height - 24) * g / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()..color = ink.withValues(alpha: 0.07),
      );
    }
    // A smooth line through the points.
    final Path line = Path()..moveTo(p(0).dx, p(0).dy);
    for (int i = 1; i < v.length; i++) {
      final Offset a = p(i - 1), b = p(i);
      final double mx = (a.dx + b.dx) / 2;
      line.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final Path fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          <Color>[accent.withValues(alpha: 0.28), accent.withValues(alpha: 0)],
        ),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    final int i = scrub ?? v.length - 1;
    final Offset d = p(i);
    if (scrub != null) {
      canvas.drawLine(
        Offset(d.dx, 0),
        Offset(d.dx, size.height),
        Paint()
          ..color = ink.withValues(alpha: 0.3)
          ..strokeWidth = 1.5,
      );
    }
    canvas.drawCircle(d, 9, Paint()..color = bg);
    canvas.drawCircle(d, 6, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_Chart old) => true;
}
