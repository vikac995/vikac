import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/panel.dart';
import '../../widgets/room_header.dart';
import '../patterns/inputs_room.dart';

const List<(double, Color, double)> _plates = <(double, Color, double)>[
  (25, Color(0xFFD9363E), 1),
  (20, Color(0xFF2F6FDE), 1),
  (15, Color(0xFFE9B10A), 0.9),
  (10, Color(0xFF2FA84F), 0.78),
  (5, Color(0xFFE8E6E1), 0.6),
  (2.5, Color(0xFF3A3D45), 0.5),
  (1.25, Color(0xFF8A8D96), 0.42),
];

String _n(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toString();

/// Room 44. A plate calculator: turn a number into a picture of what to
/// put on the bar. An example of showing the answer instead of stating it.
class PlatesRoom extends StatefulWidget {
  const PlatesRoom({super.key});

  @override
  State<PlatesRoom> createState() => _PlatesRoomState();
}

class _PlatesRoomState extends State<PlatesRoom> {
  double _target = 82.5;
  double _bar = 20;

  List<int> get _side {
    double left = (_target - _bar) / 2;
    final List<int> out = <int>[];
    for (int i = 0; i < _plates.length; i++) {
      while (left >= _plates[i].$1 - 0.001) {
        out.add(i);
        left -= _plates[i].$1;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final List<int> side = _side;
    final Color steel = c.dark
        ? const Color(0xFF9EA3AD)
        : const Color(0xFF7C818B);
    Widget plate(int i, int n) => TweenAnimationBuilder<double>(
      key: ValueKey<String>('$i-$n'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double t, Widget? child) =>
          Transform.scale(scaleY: t.clamp(0.0, 1.2), child: child),
      child: Container(
        width: _plates[i].$1 >= 10 ? 15 : 11,
        height: 132 * _plates[i].$3,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          color: _plates[i].$2,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black.withValues(alpha: 0.25)),
        ),
      ),
    );
    final Map<int, int> seen = <int, int>{};
    final List<Widget> right = <Widget>[
      for (final int i in side) plate(i, seen[i] = (seen[i] ?? 0) + 1),
    ];
    final Map<int, int> seenL = <int, int>{};
    final List<Widget> left = <Widget>[
      for (final int i in side) plate(i, -(seenL[i] = (seenL[i] ?? 0) + 1)),
    ].reversed.toList();
    final Map<int, int> counts = <int, int>{};
    for (final int i in side) {
      counts[i] = (counts[i] ?? 0) + 1;
    }

    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 44,
          title: 'Plates',
          hint: 'Pattern: show the answer as a picture. Dial a weight and the bar loads itself; nobody should do this sum between sets.',
        ),
        const SizedBox(height: 16),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // The bar.
                    FractionallySizedBox(
                      widthFactor: 0.94,
                      child: Container(
                        height: 8,
                        decoration: ShapeDecoration(
                          color: steel,
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        ...left,
                        Container(
                          width: 8,
                          height: 26,
                          decoration: BoxDecoration(
                            color: steel,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 104),
                        Container(
                          width: 8,
                          height: 26,
                          decoration: BoxDecoration(
                            color: steel,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        ...right,
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                side.isEmpty
                    ? 'Just the bar'
                    : 'Each side: ${counts.entries.map((MapEntry<int, int> e) => e.value > 1 ? '${e.value} × ${_n(_plates[e.key].$1)}' : _n(_plates[e.key].$1)).join('  +  ')}',
                textAlign: TextAlign.center,
                style: LumenType.text(16, weight: 650, color: c.ink),
              ),
            ],
          ),
        ),
        const SectionLabel(
          'Weight on the bar',
          detail:
              'Moves in 2.5 kg steps, the smallest change two plates can make.',
        ),
        DragDial(
          value: _target,
          step: 2.5,
          fineStep: 2.5,
          min: _bar,
          max: 300,
          unit: 'kg',
          onChanged: (double v) => setState(() => _target = v),
        ),
        const SectionLabel('Bar'),
        Segmented<double>(
          values: const <double>[20, 15, 10],
          labels: const <String>['20 kg', '15 kg', '10 kg'],
          value: _bar,
          onChanged: (double v) => setState(() {
            _bar = v;
            // Keep the total reachable with the new bar.
            _target = (v + ((_target - v) / 2.5).round().clamp(0, 200) * 2.5)
                .toDouble();
          }),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: <Widget>[
            for (final (double w, Color col, double _) in _plates)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: col,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: c.hairline),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _n(w),
                    style: LumenType.text(13, weight: 600, color: c.inkMuted),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
