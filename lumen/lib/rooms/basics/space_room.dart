import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/panel.dart';
import '../../widgets/room_header.dart';

/// Room 14. Spacing: one base unit, a grid, and grouping by distance.
class SpaceRoom extends StatefulWidget {
  const SpaceRoom({super.key});

  @override
  State<SpaceRoom> createState() => _SpaceRoomState();
}

class _SpaceRoomState extends State<SpaceRoom> with TickerProviderStateMixin {
  double _unit = 8;
  bool _grid = false;
  bool _grouped = true;
  late final SpringValue _u = SpringValue(
    this,
    value: 8,
    spring: Motions.expressive,
    settleDistance: 0.05,
    settleVelocity: 1,
  );
  late final SpringValue _g = SpringValue(
    this,
    value: 1,
    spring: Motions.expressive,
  );
  late final SpringValue _gridIn = SpringValue(this, spring: Motions.effects);

  @override
  void dispose() {
    _u.dispose();
    _g.dispose();
    _gridIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 14,
          title: 'Space',
          hint:
              'Basics: spacing. Every gap is a multiple of one small unit, usually 8. '
              'And things that belong together sit closer than things that do not.',
        ),
        const SizedBox(height: 18),
        ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[_u, _g, _gridIn]),
          builder: (BuildContext context, Widget? _) {
            final double u = _u.value;
            final double g = _g.value;
            // Inside a group: tight. Between groups: wide. Ungrouped: all equal.
            final double inner = lerpDouble(
              u * 2,
              u * 0.5,
              g,
            )!.clamp(0.0, 80.0);
            final double outer = lerpDouble(
              u * 2,
              u * 3.5,
              g,
            )!.clamp(0.0, 80.0);
            Widget field(String label, String value) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: LumenType.text(12.5, weight: 560, color: c.inkMuted),
                ),
                SizedBox(height: inner),
                Text(
                  value,
                  style: LumenType.text(16, weight: 560, color: c.ink),
                ),
              ],
            );
            return CustomPaint(
              foregroundPainter: _GridPainter(u, _gridIn.value, c.accent),
              child: Panel(
                padding: EdgeInsets.all((u * 2.5).clamp(0.0, 60.0)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: u * 6,
                          height: u * 6,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: c.accent,
                            shape: const CircleBorder(),
                          ),
                          child: Text(
                            'M',
                            style: LumenType.display(
                              u * 2.6,
                              weight: 700,
                              color: c.onAccent,
                            ),
                          ),
                        ),
                        SizedBox(width: u * 1.5),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Mira Halden',
                                style: LumenType.text(
                                  18,
                                  weight: 660,
                                  color: c.ink,
                                ),
                              ),
                              SizedBox(height: inner * 0.5),
                              Text(
                                'Print designer',
                                style: LumenType.text(14, color: c.inkMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: outer),
                    field('Email', 'mira@studionorth.example'),
                    SizedBox(height: outer),
                    field('Phone', '+44 20 7946 0958'),
                    SizedBox(height: outer),
                    field('Studio', 'Harbour Road 12'),
                    SizedBox(height: outer),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            height: (u * 6).clamp(32.0, 72.0),
                            alignment: Alignment.center,
                            decoration: ShapeDecoration(
                              color: c.accent,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              'Message',
                              style: LumenType.text(
                                15,
                                weight: 640,
                                color: c.onAccent,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: u * 1.5),
                        Expanded(
                          child: Container(
                            height: (u * 6).clamp(32.0, 72.0),
                            alignment: Alignment.center,
                            decoration: ShapeDecoration(
                              shape: StadiumBorder(
                                side: BorderSide(color: c.inkFaint),
                              ),
                            ),
                            child: Text(
                              'Call',
                              style: LumenType.text(
                                15,
                                weight: 640,
                                color: c.ink,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SectionLabel(
          'Base unit',
          detail: 'The whole card is built from this one number.',
        ),
        Segmented<double>(
          values: const <double>[4, 8, 12],
          labels: const <String>['Cramped · 4', 'Standard · 8', 'Airy · 12'],
          value: _unit,
          onChanged: (double v) {
            setState(() => _unit = v);
            _u.animateTo(v);
          },
        ),
        const SizedBox(height: 14),
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
          child: Column(
            children: <Widget>[
              SwitchLine(
                label: 'Group related things',
                value: _grouped,
                onChanged: (bool v) {
                  setState(() => _grouped = v);
                  _g.animateTo(v ? 1 : 0);
                },
              ),
              Divider(height: 1, color: c.hairline),
              SwitchLine(
                label: 'Show the grid',
                value: _grid,
                onChanged: (bool v) {
                  setState(() => _grid = v);
                  _gridIn.animateTo(v ? 1 : 0);
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
          child: Text(
            'Switch grouping off: every gap becomes equal, and you can no longer tell which label belongs to which value.',
            style: LumenType.text(13.5, color: c.inkMuted),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.unit, this.amount, this.color);
  final double unit;
  final double amount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (amount <= 0.01 || unit < 2) {
      return;
    }
    final Paint p = Paint()
      ..color = color.withValues(alpha: 0.28 * amount.clamp(0.0, 1.0))
      ..strokeWidth = 0.5;
    for (double x = 0; x <= size.width; x += unit) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += unit) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.unit != unit || old.amount != amount || old.color != color;
}
