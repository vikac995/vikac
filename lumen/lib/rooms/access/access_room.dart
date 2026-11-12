import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';

enum _Need { standard, largeText, contrast, motion }

/// Room 12. One small screen, shown four ways. Accessibility as a design
/// feature, not an afterthought.
class AccessRoom extends StatefulWidget {
  const AccessRoom({super.key});

  @override
  State<AccessRoom> createState() => _AccessRoomState();
}

class _AccessRoomState extends State<AccessRoom> {
  int _play = 0;
  bool _reader = false;
  bool _targets = false;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 32),
        children: <Widget>[
          const RoomHeader(
            number: 12,
            title: 'Access',
            hint:
                'Trend: accessibility designed in from the start. The same screen, built once, adapts to '
                'larger text, higher contrast and less motion, and tells a screen reader what everything is.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
            decoration: ShapeDecoration(
              color: c.surface,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: c.hairline),
              ),
            ),
            child: Column(
              children: <Widget>[
                _row(
                  c,
                  'Show what a screen reader says',
                  _reader,
                  (bool v) => setState(() => _reader = v),
                ),
                Divider(height: 1, color: c.hairline),
                _row(
                  c,
                  'Show touch areas',
                  _targets,
                  (bool v) => setState(() => _targets = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Pressable(
            onTap: () {
              setState(() => _play++);
              Haptics.tick();
            },
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: c.accent,
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.play_arrow_rounded, color: c.onAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Play the same action on all four',
                    style: LumenType.text(
                      15,
                      weight: 640,
                      color: c.onAccent,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          for (final _Need n in _Need.values) ...<Widget>[
            _Panel(need: n, play: _play, reader: _reader, targets: _targets),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _row(LumenColors c, String label, bool v, ValueChanged<bool> on) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: LumenType.text(15, weight: 560, color: c.ink),
          ),
        ),
        LumenSwitch(value: v, onChanged: on),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.need,
    required this.play,
    required this.reader,
    required this.targets,
  });
  final _Need need;
  final int play;
  final bool reader;
  final bool targets;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final (String title, String detail) = switch (need) {
      _Need.standard => ('Standard', 'The default design.'),
      _Need.largeText => (
        'Large text, 170%',
        'Text grows and the layout reflows; nothing is cut off or overlaps.',
      ),
      _Need.contrast => (
        'High contrast',
        'Solid colours, thicker outlines, no faint grey text.',
      ),
      _Need.motion => (
        'Reduced motion',
        'Same feedback, no bounce or travel: things fade and change in place.',
      ),
    };
    final MediaQueryData mq = MediaQuery.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title.toUpperCase(),
                style: LumenType.label(color: c.accent),
              ),
              const SizedBox(height: 2),
              Text(detail, style: LumenType.text(13, color: c.inkMuted)),
            ],
          ),
        ),
        MediaQuery(
          data: mq.copyWith(
            textScaler: need == _Need.largeText
                ? TextScaler.linear(mq.textScaler.scale(10) / 10 * 1.7)
                : mq.textScaler,
            highContrast: need == _Need.contrast,
            disableAnimations: need == _Need.motion,
          ),
          child: _Sample(play: play, reader: reader, targets: targets),
        ),
      ],
    );
  }
}

/// The sample screen. It reads its needs from MediaQuery, like a real app.
class _Sample extends StatefulWidget {
  const _Sample({
    required this.play,
    required this.reader,
    required this.targets,
  });
  final int play;
  final bool reader;
  final bool targets;

  @override
  State<_Sample> createState() => _SampleState();
}

class _SampleState extends State<_Sample> with TickerProviderStateMixin {
  late final SpringValue _progress = SpringValue(
    this,
    value: 0.35,
    spring: Motions.expressive,
  );
  late final SpringValue _heart = SpringValue(
    this,
    value: 1,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _fade = SpringValue(
    this,
    value: 1,
    spring: Motions.effects,
  );
  bool _liked = false;
  bool _share = true;

  bool get _reduced => MediaQuery.of(context).disableAnimations;

  @override
  void didUpdateWidget(_Sample old) {
    super.didUpdateWidget(old);
    if (old.play != widget.play) {
      _act();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _heart.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _act() {
    final double next = _progress.target > 0.9
        ? 0.35
        : (_progress.target + 0.3).clamp(0.0, 1.0);
    setState(() => _liked = !_liked);
    if (_reduced) {
      // Change in place with a quick fade, no travel or overshoot.
      _progress.animateTo(next, spring: Motions.reduced, velocity: 0);
      _fade.jumpTo(0.4);
      _fade.animateTo(1);
    } else {
      _progress.animateTo(next);
      _heart.jumpTo(0.6);
      _heart.animateTo(1, velocity: 8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors base = LumenColors.of(context);
    final bool hc = MediaQuery.of(context).highContrast;
    final Color bg = hc ? Colors.black : base.surface;
    final Color ink = hc ? Colors.white : base.ink;
    final Color muted = hc ? Colors.white : base.inkMuted;
    final Color accent = hc ? const Color(0xFFFFD60A) : base.accent;
    final Color onAccent = hc ? Colors.black : base.onAccent;
    final BorderSide edge = hc
        ? const BorderSide(color: Colors.white, width: 2)
        : BorderSide(color: base.hairline);

    Widget label(int n, String said, Widget child) {
      if (!widget.reader) {
        return child;
      }
      return Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          child,
          Positioned(
            left: -17,
            top: -9,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const ShapeDecoration(
                color: Color(0xFF2E7BFF),
                shape: StadiumBorder(),
              ),
              child: Text(
                '$n',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget target(Widget child) {
      if (!widget.targets) {
        return child;
      }
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          child,
          IgnorePointer(
            child: Container(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF30D158), width: 1.5),
                borderRadius: BorderRadius.circular(6),
                color: const Color(0x2230D158),
              ),
            ),
          ),
        ],
      );
    }

    final List<String> spoken = <String>[
      'Morning run, heading',
      '5.2 kilometres in 28 minutes',
      'Progress, ${(_progress.target * 100).round()} percent',
      _liked ? 'Liked, button, double tap to unlike' : 'Like, button',
      'Share with team, switch, ${_share ? 'on' : 'off'}',
    ];

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_progress, _heart, _fade]),
      builder: (BuildContext context, Widget? _) {
        return Opacity(
          opacity: _fade.value.clamp(0.0, 1.0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: ShapeDecoration(
              color: bg,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(26),
                side: edge,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          label(
                            1,
                            spoken[0],
                            Semantics(
                              header: true,
                              child: Text(
                                'Morning run',
                                style: LumenType.text(
                                  19,
                                  weight: 680,
                                  color: ink,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          label(
                            2,
                            spoken[1],
                            Text(
                              '5.2 km · 28 min',
                              style: LumenType.text(14, color: muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    label(
                      4,
                      spoken[3],
                      target(
                        Semantics(
                          button: true,
                          toggled: _liked,
                          label: 'Like',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _act,
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Transform.scale(
                                scale: _heart.value,
                                child: Icon(
                                  _liked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: _liked ? accent : muted,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                label(
                  3,
                  spoken[2],
                  Semantics(
                    label: 'Progress',
                    value: '${(_progress.target * 100).round()} percent',
                    child: Container(
                      height: hc ? 12 : 8,
                      alignment: Alignment.centerLeft,
                      decoration: ShapeDecoration(
                        color: hc
                            ? Colors.black
                            : accent.withValues(alpha: 0.18),
                        shape: StadiumBorder(
                          side: hc
                              ? const BorderSide(color: Colors.white, width: 2)
                              : BorderSide.none,
                        ),
                      ),
                      child: FractionallySizedBox(
                        heightFactor: 1,
                        widthFactor: _progress.value.clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: accent,
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: label(
                        5,
                        spoken[4],
                        Text(
                          'Share with team',
                          style: LumenType.text(15, weight: 560, color: ink),
                        ),
                      ),
                    ),
                    target(
                      Semantics(
                        toggled: _share,
                        label: 'Share with team',
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            extensions: <ThemeExtension<dynamic>>[
                              hc
                                  ? LumenColors(
                                      dark: true,
                                      bg: Colors.black,
                                      surface: Colors.black,
                                      surfaceHigh: Colors.black,
                                      ink: Colors.white,
                                      inkMuted: Colors.white,
                                      inkFaint: Colors.white,
                                      accent: accent,
                                      onAccent: onAccent,
                                      hairline: Colors.white,
                                      glassTint: Colors.black,
                                      glassInk: Colors.white,
                                      shadow: Colors.black,
                                    )
                                  : base,
                            ],
                          ),
                          child: LumenSwitch(
                            value: _share,
                            onChanged: (bool v) => setState(() => _share = v),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.reader) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: ShapeDecoration(
                      color: const Color(0xFF2E7BFF).withValues(alpha: 0.12),
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'A SCREEN READER SAYS, IN ORDER',
                          style: LumenType.label(
                            color: const Color(0xFF5B9BFF),
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (int i = 0; i < spoken.length; i++)
                          Text(
                            '${i + 1}.  “${spoken[i]}”',
                            style: LumenType.text(13, color: ink, height: 1.5),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
