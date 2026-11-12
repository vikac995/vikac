import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/panel.dart';
import '../../widgets/room_header.dart';

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

/// WCAG contrast ratio, from 1 (none) to 21 (black on white).
double contrastRatio(Color a, Color b) {
  final double la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

const List<List<double>> _filters = <List<double>>[
  <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0],
  // Red-green colour blindness (deuteranopia), approximate.
  <double>[
    0.625,
    0.375,
    0,
    0,
    0,
    0.7,
    0.3,
    0,
    0,
    0,
    0,
    0.3,
    0.7,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ],
  <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ],
];

/// Room 15. Contrast you can measure, and why colour alone is not enough.
class ContrastRoom extends StatefulWidget {
  const ContrastRoom({super.key});

  @override
  State<ContrastRoom> createState() => _ContrastRoomState();
}

class _ContrastRoomState extends State<ContrastRoom> {
  double _text = 0.62; // lightness of the text
  double _bg = 0.96; // lightness of the background
  int _vision = 0;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final Color text = HSLColor.fromAHSL(1, 222, 0.12, _text).toColor();
    final Color bg = HSLColor.fromAHSL(1, 40, 0.25, _bg).toColor();
    final double ratio = contrastRatio(text, bg);
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 15,
          title: 'Contrast',
          hint:
              'Basics: legibility. Contrast between text and background is a number, and there is a '
              'pass mark: 4.5 to 1 for normal text. Pale grey on white is the most common failure.',
        ),
        const SizedBox(height: 18),
        Panel(
          color: bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Can you read this comfortably?',
                style: LumenType.display(
                  26,
                  weight: 700,
                  color: text,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Small text needs more contrast than large text. Try this outdoors, or with the screen dimmed.',
                style: LumenType.text(14.5, color: text, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    ratio.toStringAsFixed(1),
                    style: LumenType.display(
                      46,
                      weight: 720,
                      color: c.ink,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7, left: 6),
                    child: Text(
                      ': 1',
                      style: LumenType.text(18, weight: 600, color: c.inkMuted),
                    ),
                  ),
                  const Spacer(),
                  _Badge(label: 'Large text', pass: ratio >= 3),
                  const SizedBox(width: 6),
                  _Badge(label: 'Body', pass: ratio >= 4.5),
                  const SizedBox(width: 6),
                  _Badge(label: 'Best', pass: ratio >= 7),
                ],
              ),
              const SizedBox(height: 10),
              _sliderRow(
                c,
                'Text',
                _text,
                (double v) => setState(() => _text = v),
              ),
              _sliderRow(
                c,
                'Background',
                _bg,
                (double v) => setState(() => _bg = v),
              ),
            ],
          ),
        ),
        const SectionLabel(
          'Not by colour alone',
          detail: 'About one in twelve men cannot tell red from green. Add a shape or a word.',
        ),
        Segmented<int>(
          values: const <int>[0, 1, 2],
          labels: const <String>['Full colour', 'Red-green blind', 'Greyscale'],
          value: _vision,
          onChanged: (int v) => setState(() => _vision = v),
        ),
        const SizedBox(height: 12),
        ColorFiltered(
          colorFilter: ColorFilter.matrix(_filters[_vision]),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Colour only',
                  style: LumenType.text(13, weight: 600, color: c.inkMuted),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: <Widget>[
                    _Status('Invoice 204', Color(0xFF2FA84F), null),
                    SizedBox(width: 8),
                    _Status('Invoice 205', Color(0xFFD9483B), null),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Colour, icon and word',
                  style: LumenType.text(13, weight: 600, color: c.inkMuted),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: <Widget>[
                    _Status(
                      'Paid',
                      Color(0xFF2FA84F),
                      Icons.check_circle_rounded,
                    ),
                    SizedBox(width: 8),
                    _Status('Overdue', Color(0xFFD9483B), Icons.error_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sliderRow(
    LumenColors c,
    String label,
    double v,
    ValueChanged<double> on,
  ) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: LumenType.text(13.5, weight: 560, color: c.ink),
          ),
        ),
        Expanded(
          child: LumenSlider(value: v, onChanged: on),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.pass});
  final String label;
  final bool pass;

  @override
  Widget build(BuildContext context) {
    final Color col = pass ? const Color(0xFF2FA84F) : const Color(0xFFD9483B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: ShapeDecoration(
        color: col.withValues(alpha: 0.16),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            pass ? Icons.check_rounded : Icons.close_rounded,
            size: 14,
            color: col,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: LumenType.text(11.5, weight: 620, color: col, height: 1.1),
          ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: LumenType.text(
              13.5,
              weight: 620,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
