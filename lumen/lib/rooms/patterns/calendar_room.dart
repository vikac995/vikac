import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/panel.dart';
import '../../widgets/room_header.dart';
import '../../widgets/spring_box.dart';

const List<String> _months = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const List<String> _kinds = <String>['Push', 'Pull', 'Legs'];

/// Room 38. History as a month: which days had a session, a selection that
/// travels between days, and the day's summary underneath.
class CalendarRoom extends StatefulWidget {
  const CalendarRoom({super.key});

  @override
  State<CalendarRoom> createState() => _CalendarRoomState();
}

class _CalendarRoomState extends State<CalendarRoom>
    with SingleTickerProviderStateMixin {
  static final DateTime _today = DateTime(2026, 11, 13);
  DateTime _month = DateTime(2026, 11);
  DateTime _picked = _today;
  late final SpringValue _slide = SpringValue(this, spring: Motions.spatial);

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  // A made-up but stable history: roughly four sessions a week, none in the future.
  int? _session(DateTime d) {
    if (d.isAfter(_today)) {
      return null;
    }
    final int h = (d.year * 372 + d.month * 31 + d.day) * 2654435761 % 1000;
    return h % 7 < 4 ? h % 3 : null;
  }

  void _go(int by) {
    final DateTime m = DateTime(_month.year, _month.month + by);
    if (m.isAfter(DateTime(_today.year, _today.month))) {
      Haptics.thud();
      _slide.jumpTo(-0.08);
      _slide.animateTo(0, spring: Motions.expressiveFast);
      return;
    }
    setState(() => _month = m);
    Haptics.tick();
    // The new month arrives from the side it lives on.
    _slide.jumpTo(by.toDouble());
    _slide.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final int offset =
        DateTime(_month.year, _month.month).weekday - 1; // Monday first
    final int days = DateTime(_month.year, _month.month + 1, 0).day;
    final int rows = ((offset + days) / 7).ceil();
    int count = 0;
    for (int d = 1; d <= days; d++) {
      if (_session(DateTime(_month.year, _month.month, d)) != null) {
        count++;
      }
    }
    final int? s = _session(_picked);
    final bool pickedHere =
        _picked.year == _month.year && _picked.month == _month.month;

    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 38,
          title: 'Calendar',
          hint: 'Pattern: history as a month. Tap a day, swipe or use the arrows to change month. The future is not selectable.',
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${_months[_month.month - 1]} ${_month.year}',
                    style: LumenType.display(26, weight: 700, color: c.ink),
                  ),
                  Text(
                    '$count sessions',
                    style: LumenType.text(13.5, color: c.inkMuted),
                  ),
                ],
              ),
            ),
            RoundButton(
              icon: Icons.chevron_left_rounded,
              semanticLabel: 'Previous month',
              onTap: () => _go(-1),
            ),
            const SizedBox(width: 8),
            RoundButton(
              icon: Icons.chevron_right_rounded,
              semanticLabel: 'Next month',
              onTap: () => _go(1),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            for (final String d in 'MTWTFSS'.split(''))
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: LumenType.text(12, weight: 650, color: c.inkFaint),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onHorizontalDragEnd: (DragEndDetails d) {
            final double v = d.primaryVelocity ?? 0;
            if (v.abs() > 200) {
              _go(v < 0 ? 1 : -1);
            }
          },
          child: ClipRect(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                final double cw = box.maxWidth / 7;
                const double ch = 52;
                final int pi = offset + _picked.day - 1;
                return ListenableBuilder(
                  listenable: _slide,
                  builder: (BuildContext context, Widget? child) =>
                      Transform.translate(
                        offset: Offset(_slide.value * box.maxWidth * 0.5, 0),
                        child: Opacity(
                          opacity: (1 - _slide.value.abs()).clamp(0.0, 1.0),
                          child: child,
                        ),
                      ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: rows * ch,
                      child: Stack(
                        children: <Widget>[
                          // One highlight that travels, instead of each day lighting up.
                          if (pickedHere)
                            SpringPositioned(
                              left: (pi % 7) * cw + (cw - 44) / 2,
                              top: (pi ~/ 7) * ch + 4,
                              width: 44,
                              height: 44,
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: c.accent,
                                  shape: const CircleBorder(),
                                ),
                              ),
                            ),
                          for (int d = 1; d <= days; d++)
                            Positioned(
                              left: ((offset + d - 1) % 7) * cw,
                              top: ((offset + d - 1) ~/ 7) * ch,
                              width: cw,
                              height: ch,
                              child: _day(
                                c,
                                DateTime(_month.year, _month.month, d),
                                pickedHere && d == _picked.day,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Row(
              key: ValueKey<DateTime>(_picked),
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: ShapeDecoration(
                    color: (s == null ? c.ink : c.accent).withValues(
                      alpha: 0.14,
                    ),
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    s == null
                        ? Icons.bedtime_outlined
                        : Icons.fitness_center_rounded,
                    color: s == null ? c.inkMuted : c.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${_picked.day} ${_months[_picked.month - 1]}${_picked == _today ? '  ·  today' : ''}',
                        style: LumenType.text(
                          13,
                          weight: 600,
                          color: c.inkMuted,
                        ),
                      ),
                      Text(
                        s == null ? 'Rest day' : '${_kinds[s]} day',
                        style: LumenType.text(17, weight: 660, color: c.ink),
                      ),
                      if (s != null)
                        Text(
                          '${48 + _picked.day % 20} min  ·  ${5 + _picked.day % 3} exercises  ·  ${(6 + _picked.day % 5)}.${_picked.day % 10} t lifted',
                          style: LumenType.text(13.5, color: c.inkMuted),
                        ),
                    ],
                  ),
                ),
                if (s != null)
                  Icon(Icons.chevron_right_rounded, color: c.inkFaint),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _day(LumenColors c, DateTime d, bool picked) {
    final bool future = d.isAfter(_today);
    final bool today = d == _today;
    final int? s = _session(d);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: future
          ? null
          : () {
              setState(() => _picked = d);
              Haptics.tick();
            },
      child: Column(
        children: <Widget>[
          const SizedBox(height: 4),
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: CircleBorder(
                side: BorderSide(
                  color: today && !picked ? c.accent : Colors.transparent,
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '${d.day}',
                  textScaler: TextScaler.noScaling,
                  style: LumenType.text(
                    15,
                    weight: picked || today ? 700 : 520,
                    color: picked ? c.onAccent : (future ? c.inkFaint : c.ink),
                    height: 1.1,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 5,
                  height: 5,
                  decoration: ShapeDecoration(
                    color: s == null
                        ? Colors.transparent
                        : (picked ? c.onAccent : c.accent),
                    shape: const CircleBorder(),
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
