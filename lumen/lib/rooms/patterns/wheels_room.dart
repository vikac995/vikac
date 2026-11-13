import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../widgets/panel.dart';
import '../../widgets/room_header.dart';

/// Room 43. Wheel pickers: for values people know by position (a time, a
/// duration, a body weight) rather than by typing.
class WheelsRoom extends StatefulWidget {
  const WheelsRoom({super.key});

  @override
  State<WheelsRoom> createState() => _WheelsRoomState();
}

class _WheelsRoomState extends State<WheelsRoom> {
  int _min = 1, _sec = 6; // sec in steps of 5
  int _hour = 18, _minute = 6; // minute in steps of 5
  int _kg = 81, _dec = 8;

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    Widget sep(String s) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        s,
        style: LumenType.display(26, weight: 700, color: c.inkMuted),
      ),
    );
    Widget result(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        s,
        textAlign: TextAlign.center,
        style: LumenType.text(14.5, weight: 620, color: c.accent),
      ),
    );
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 43,
          title: 'Wheels',
          hint: 'Pattern: spin to choose. Each step ticks, the wheel snaps to a value, and a flick carries it. Good for times and durations; poor for long ranges.',
        ),
        const SectionLabel('Duration'),
        Panel(
          child: Column(
            children: <Widget>[
              result('Rest for $_min min ${_two(_sec * 5)} s'),
              _Wheels(
                children: <Widget>[
                  _Wheel(
                    count: 10,
                    initial: _min,
                    label: (int i) => '$i',
                    onChanged: (int v) => setState(() => _min = v),
                  ),
                  sep('min'),
                  _Wheel(
                    count: 12,
                    initial: _sec,
                    label: (int i) => _two(i * 5),
                    onChanged: (int v) => setState(() => _sec = v),
                  ),
                  sep('s'),
                ],
              ),
            ],
          ),
        ),
        const SectionLabel(
          'Time of day',
          detail: 'The hours loop round, so 23 sits next to 00.',
        ),
        Panel(
          child: Column(
            children: <Widget>[
              result('Remind me at ${_two(_hour)}:${_two(_minute * 5)}'),
              _Wheels(
                children: <Widget>[
                  _Wheel(
                    count: 24,
                    initial: _hour,
                    loop: true,
                    label: _two,
                    onChanged: (int v) => setState(() => _hour = v),
                  ),
                  sep(':'),
                  _Wheel(
                    count: 12,
                    initial: _minute,
                    loop: true,
                    label: (int i) => _two(i * 5),
                    onChanged: (int v) => setState(() => _minute = v),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionLabel(
          'Body weight',
          detail:
              'Two wheels: whole kilos and tenths. Faster than one long wheel.',
        ),
        Panel(
          child: Column(
            children: <Widget>[
              result('$_kg.$_dec kg'),
              _Wheels(
                children: <Widget>[
                  _Wheel(
                    count: 171,
                    initial: _kg - 30,
                    label: (int i) => '${i + 30}',
                    onChanged: (int v) => setState(() => _kg = v + 30),
                  ),
                  sep('.'),
                  _Wheel(
                    count: 10,
                    initial: _dec,
                    loop: true,
                    label: (int i) => '$i',
                    onChanged: (int v) => setState(() => _dec = v),
                  ),
                  sep('kg'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Wheels extends StatelessWidget {
  const _Wheels({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return SizedBox(
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // The band that marks the chosen row.
          Container(
            height: 48,
            decoration: ShapeDecoration(
              color: c.ink.withValues(alpha: 0.07),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: children),
        ],
      ),
    );
  }
}

class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.count,
    required this.initial,
    required this.label,
    required this.onChanged,
    this.loop = false,
  });
  final int count, initial;
  final String Function(int) label;
  final ValueChanged<int> onChanged;
  final bool loop;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final FixedExtentScrollController _ctl = FixedExtentScrollController(
    initialItem: widget.initial,
  );
  late int _at = widget.initial;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    Widget item(int i) => Center(
      child: Text(
        widget.label(i),
        textScaler: TextScaler.noScaling,
        style:
            LumenType.display(
              28,
              weight: i == _at ? 720 : 560,
              color: i == _at ? c.ink : c.inkMuted,
            ).copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
      ),
    );
    return SizedBox(
      width: 78,
      child: ListWheelScrollView.useDelegate(
        controller: _ctl,
        itemExtent: 48,
        diameterRatio: 1.5,
        perspective: 0.003,
        overAndUnderCenterOpacity: 0.45,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (int i) {
          final int v = i % widget.count;
          setState(() => _at = v);
          Haptics.tick();
          widget.onChanged(v);
        },
        childDelegate: widget.loop
            ? ListWheelChildLoopingListDelegate(
                children: <Widget>[
                  for (int i = 0; i < widget.count; i++) item(i),
                ],
              )
            : ListWheelChildBuilderDelegate(
                childCount: widget.count,
                builder: (BuildContext context, int i) => item(i),
              ),
      ),
    );
  }
}
