import 'dart:math' as math;
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/panel.dart';
import '../../widgets/room_header.dart';

/// Room 13. Type hierarchy: a scale built from one ratio, and what a page
/// looks like with and without it.
class TypeRoom extends StatefulWidget {
  const TypeRoom({super.key});

  @override
  State<TypeRoom> createState() => _TypeRoomState();
}

class _TypeRoomState extends State<TypeRoom> with TickerProviderStateMixin {
  static const List<(double, String)> _ratios = <(double, String)>[
    (1.125, '1.125'),
    (1.2, '1.2'),
    (1.25, '1.25'),
    (1.333, '1.333'),
    (1.5, '1.5'),
  ];
  static const List<String> _names = <String>[
    'Caption',
    'Body',
    'Subtitle',
    'Title',
    'Headline',
    'Display',
  ];

  double _ratio = 1.25;
  bool _hierarchy = true;
  double _leading = 0.5;
  late final SpringValue _r = SpringValue(
    this,
    value: 1.25,
    spring: Motions.expressive,
    settleDistance: 0.002,
  );
  late final SpringValue _h = SpringValue(
    this,
    value: 1,
    spring: Motions.spatial,
  );

  @override
  void dispose() {
    _r.dispose();
    _h.dispose();
    super.dispose();
  }

  /// Size of step [i] (Body is step 0), blended toward plain body size when
  /// hierarchy is switched off.
  double _size(int i) => lerpDouble(
    16,
    16 * math.pow(_r.value, i).toDouble(),
    _h.value.clamp(0.0, 1.0),
  )!;
  double _weight(double w) => lerpDouble(450, w, _h.value.clamp(0.0, 1.0))!;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final double lh = lerpDouble(1.1, 1.9, _leading)!;
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 13,
          title: 'Type',
          hint:
              'Basics: hierarchy. Size, weight and colour tell the eye what to read first. '
              'Good interfaces pick one ratio and build every text size from it.',
        ),
        const SizedBox(height: 18),
        ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[_r, _h]),
          builder: (BuildContext context, Widget? _) {
            final double h = _h.value.clamp(0.0, 1.0);
            return Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'FIELD NOTES',
                    style: LumenType.text(
                      _size(-1),
                      weight: _weight(650),
                      color: Color.lerp(c.ink, c.accent, h),
                      spacing: 1.2 * h,
                    ),
                  ),
                  SizedBox(height: 6 + 4 * h),
                  Text(
                    'The tide leaves twice a day',
                    style: LumenType.display(
                      _size(3),
                      weight: _weight(760),
                      color: c.ink,
                      height: 1.08,
                    ),
                  ),
                  SizedBox(height: 4 + 6 * h),
                  Text(
                    'Low water on the northern flats',
                    style: LumenType.text(
                      _size(1),
                      weight: _weight(560),
                      color: Color.lerp(c.ink, c.inkMuted, h),
                    ),
                  ),
                  SizedBox(height: 6 + 8 * h),
                  Text(
                    'What it leaves is a mirror a few millimetres deep, and the sky lands in it twice. Walkers keep to the ridges where the sand is firm.',
                    style: LumenType.text(_size(0), color: c.ink, height: lh),
                  ),
                  SizedBox(height: 6 + 6 * h),
                  Text(
                    '4 min read  ·  North Sea',
                    style: LumenType.text(
                      _size(-1),
                      color: Color.lerp(c.ink, c.inkFaint, h),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
          child: SwitchLine(
            label: 'Hierarchy',
            value: _hierarchy,
            onChanged: (bool v) {
              setState(() => _hierarchy = v);
              _h.animateTo(v ? 1 : 0);
            },
          ),
        ),
        const SectionLabel(
          'Scale ratio',
          detail: 'Each size is the one below it times this number.',
        ),
        Segmented<double>(
          values: _ratios.map(((double, String) r) => r.$1).toList(),
          labels: _ratios.map(((double, String) r) => r.$2).toList(),
          value: _ratio,
          onChanged: (double v) {
            setState(() => _ratio = v);
            _r.animateTo(v);
          },
        ),
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: _r,
          builder: (BuildContext context, Widget? _) => Panel(
            child: Column(
              children: <Widget>[
                for (int i = 4; i >= -1; i--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        SizedBox(
                          width: 76,
                          child: Text(
                            _names[i + 1],
                            style: LumenType.text(12.5, color: c.inkMuted),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(
                            (16 * math.pow(_r.value, i)).round().toString(),
                            style: LumenType.text(
                              12.5,
                              weight: 650,
                              color: c.accent,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Aa Tide',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                            textScaler: TextScaler.noScaling,
                            style: LumenType.display(
                              16 * math.pow(_r.value, i).toDouble(),
                              weight: 620,
                              color: c.ink,
                              height: 1.05,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SectionLabel(
          'Line height',
          detail: 'Too tight is hard to read; too loose falls apart. Body text sits near 1.5.',
        ),
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: <Widget>[
              Text('Tight', style: LumenType.text(13, color: c.inkMuted)),
              const SizedBox(width: 12),
              Expanded(
                child: LumenSlider(
                  value: _leading,
                  onChanged: (double v) => setState(() => _leading = v),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 34,
                child: Text(
                  lh.toStringAsFixed(2),
                  style: LumenType.text(13, weight: 650, color: c.ink),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
