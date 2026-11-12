import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/panel.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';
import '../shapes/shape_loader.dart';

enum _Outcome { content, empty, error }

/// Room 16. Every control and every screen has more than one state. The
/// ones people forget: disabled, loading, empty and error.
class StatesRoom extends StatefulWidget {
  const StatesRoom({super.key});

  @override
  State<StatesRoom> createState() => _StatesRoomState();
}

class _StatesRoomState extends State<StatesRoom> with TickerProviderStateMixin {
  _Outcome _outcome = _Outcome.content;
  bool _loading = false;
  Timer? _timer;
  final ValueNotifier<double> _shimmer = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (Duration e) => _shimmer.value = (e.inMilliseconds % 1400) / 1400,
  );
  late final SpringValue _in = SpringValue(
    this,
    value: 1,
    spring: Motions.effectsSlow,
  );

  @override
  void dispose() {
    _timer?.cancel();
    _ticker.dispose();
    _shimmer.dispose();
    _in.dispose();
    super.dispose();
  }

  void _load() {
    setState(() => _loading = true);
    _ticker.start();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1800), () {
      _ticker.stop();
      setState(() => _loading = false);
      _in.jumpTo(0);
      _in.onSettle = _outcome == _Outcome.error ? Haptics.thud : Haptics.settle;
      _in.animateTo(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 16,
          title: 'States',
          hint:
              'Basics: design every state, not just the happy one. A button has six. '
              'A screen has at least four: loading, content, empty and error.',
        ),
        const SectionLabel('One button, six states'),
        Panel(
          child: Wrap(
            spacing: 10,
            runSpacing: 14,
            children: <Widget>[
              _state(c, 'Default', _btn(c)),
              _state(
                c,
                'Pressed',
                Transform.scale(
                  scale: 0.95,
                  child: _btn(
                    c,
                    fill: Color.lerp(c.accent, Colors.black, 0.18),
                  ),
                ),
              ),
              _state(
                c,
                'Focused',
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: ShapeDecoration(
                    shape: StadiumBorder(
                      side: BorderSide(color: c.ink, width: 2),
                    ),
                  ),
                  child: _btn(c),
                ),
              ),
              _state(
                c,
                'Disabled',
                _btn(c, fill: c.ink.withValues(alpha: 0.1), ink: c.inkFaint),
              ),
              _state(
                c,
                'Loading',
                _btn(c, child: ShapeLoader(size: 20, color: c.onAccent)),
              ),
              _state(
                c,
                'Done',
                _btn(
                  c,
                  fill: const Color(0xFF2FA84F),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SectionLabel(
          'One screen, four states',
          detail: 'Choose how the load ends, then reload.',
        ),
        Segmented<_Outcome>(
          values: _Outcome.values,
          labels: const <String>['Content', 'Empty', 'Error'],
          value: _outcome,
          onChanged: (_Outcome o) {
            setState(() => _outcome = o);
            _load();
          },
        ),
        const SizedBox(height: 12),
        Panel(
          child: SizedBox(
            height: 250,
            child: _loading
                ? ListenableBuilder(
                    listenable: _shimmer,
                    builder: (BuildContext context, Widget? _) => _skeleton(c),
                  )
                : ListenableBuilder(
                    listenable: _in,
                    builder: (BuildContext context, Widget? child) => Opacity(
                      opacity: _in.value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - _in.value)),
                        child: child,
                      ),
                    ),
                    child: switch (_outcome) {
                      _Outcome.content => _content(c),
                      _Outcome.empty => _message(
                        c,
                        Icons.inbox_rounded,
                        'Nothing here yet',
                        'Walks you save will show up here.',
                        'Find a walk',
                      ),
                      _Outcome.error => _message(
                        c,
                        Icons.wifi_off_rounded,
                        'Could not load',
                        'Check your connection. Your saved walks are safe.',
                        'Try again',
                      ),
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Pressable(
          onTap: _loading ? null : _load,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: _loading ? c.ink.withValues(alpha: 0.1) : c.accent,
              shape: const StadiumBorder(),
            ),
            child: Text(
              _loading ? 'Loading…' : 'Reload',
              style: LumenType.text(
                15.5,
                weight: 640,
                color: _loading ? c.inkFaint : c.onAccent,
                height: 1,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
          child: Text(
            'The grey placeholders are a skeleton: they show the shape of what is coming, so the wait feels shorter than a spinner.',
            style: LumenType.text(13.5, color: c.inkMuted),
          ),
        ),
      ],
    );
  }

  Widget _state(LumenColors c, String name, Widget child) {
    return SizedBox(
      width: 104,
      child: Column(
        children: <Widget>[
          SizedBox(height: 56, child: Center(child: child)),
          const SizedBox(height: 4),
          Text(name, style: LumenType.text(12, weight: 560, color: c.inkMuted)),
        ],
      ),
    );
  }

  Widget _btn(LumenColors c, {Color? fill, Color? ink, Widget? child}) {
    return Container(
      width: 92,
      height: 44,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: fill ?? c.accent,
        shape: const StadiumBorder(),
      ),
      child:
          child ??
          Text(
            'Save',
            style: LumenType.text(
              15,
              weight: 640,
              color: ink ?? c.onAccent,
              height: 1,
            ),
          ),
    );
  }

  Widget _bone(
    LumenColors c, {
    double? width,
    double height = 14,
    double radius = 7,
  }) {
    final double t = _shimmer.value;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(-1 + 3 * t - 1, 0),
          end: Alignment(3 * t - 1, 0),
          colors: <Color>[
            c.ink.withValues(alpha: 0.07),
            c.ink.withValues(alpha: 0.16),
            c.ink.withValues(alpha: 0.07),
          ],
        ),
      ),
    );
  }

  Widget _skeleton(LumenColors c) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: <Widget>[
                _bone(c, width: 56, height: 56, radius: 16),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _bone(c, width: 120 + i * 20),
                      const SizedBox(height: 10),
                      _bone(c, width: 190 - i * 24, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _content(LumenColors c) {
    const List<(String, String, Color)> rows = <(String, String, Color)>[
      ('Tidal flats', '5.2 km · easy', Color(0xFF3F8FB5)),
      ('Ember ridge', '9.0 km · steep', Color(0xFFE2563A)),
      ('Moss forest', '3.4 km · easy', Color(0xFF5E9E6E)),
    ];
    return Column(
      children: <Widget>[
        for (final (String t, String s, Color col) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: ShapeDecoration(
                    color: col,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Icon(
                    Icons.landscape_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        t,
                        style: LumenType.text(16, weight: 620, color: c.ink),
                      ),
                      Text(s, style: LumenType.text(13.5, color: c.inkMuted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.inkFaint),
              ],
            ),
          ),
      ],
    );
  }

  Widget _message(
    LumenColors c,
    IconData icon,
    String title,
    String detail,
    String action,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: ShapeDecoration(
            color: c.ink.withValues(alpha: 0.07),
            shape: const CircleBorder(),
          ),
          child: Icon(icon, size: 30, color: c.inkMuted),
        ),
        const SizedBox(height: 14),
        Text(title, style: LumenType.text(18, weight: 660, color: c.ink)),
        const SizedBox(height: 4),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: LumenType.text(14, color: c.inkMuted),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: ShapeDecoration(
            shape: StadiumBorder(side: BorderSide(color: c.accent)),
          ),
          child: Text(
            action,
            style: LumenType.text(
              14,
              weight: 640,
              color: c.accent,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}
