import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/tag.dart';
import '../details/small_things.dart';

/// Room 42. The screen after the last set: what you did, what was special,
/// one question, and a way out.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen>
    with TickerProviderStateMixin {
  late final SpringValue _check = SpringValue(this, spring: Motions.expressive);
  late final List<SpringValue> _rise = <SpringValue>[
    for (int i = 0; i < 4; i++) SpringValue(this, spring: Motions.expressive),
  ];
  final List<Timer> _timers = <Timer>[];
  bool _counted = false;
  int? _feel;

  @override
  void initState() {
    super.initState();
    _play();
  }

  void _play() {
    for (final Timer t in _timers) {
      t.cancel();
    }
    _timers.clear();
    setState(() => _counted = false);
    _check.jumpTo(0);
    for (final SpringValue s in _rise) {
      s.jumpTo(0);
    }
    // The tick lands first, then the page arrives in order, then the numbers count.
    _timers.add(
      Timer(const Duration(milliseconds: 250), () {
        _check.animateTo(1);
        Haptics.thud();
      }),
    );
    for (int i = 0; i < 4; i++) {
      _timers.add(
        Timer(
          Duration(milliseconds: 420 + i * 90),
          () => _rise[i].animateTo(1),
        ),
      );
    }
    _timers.add(
      Timer(
        const Duration(milliseconds: 650),
        () => setState(() => _counted = true),
      ),
    );
  }

  @override
  void dispose() {
    for (final Timer t in _timers) {
      t.cancel();
    }
    for (final SpringValue s in <SpringValue>[_check, ..._rise]) {
      s.dispose();
    }
    super.dispose();
  }

  Widget _in(int i, Widget child) => ListenableBuilder(
    listenable: _rise[i],
    builder: (BuildContext context, Widget? child) => Opacity(
      opacity: _rise[i].value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - _rise[i].value) * 26),
        child: child,
      ),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    const Color green = Color(0xFF2FA84F), gold = Color(0xFFF5B301);
    Widget stat(String label, int value, int digits, String unit) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: ShapeDecoration(
          color: c.ink.withValues(alpha: 0.055),
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: LumenType.label(color: c.inkMuted),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Odometer(
                  value: _counted ? value : 0,
                  digits: digits,
                  style: LumenType.display(
                    30,
                    weight: 700,
                    color: c.ink,
                    height: 1.1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Text(
                    unit,
                    style: LumenType.text(13, color: c.inkMuted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 40),
        children: <Widget>[
          const ScreenBar(number: 42),
          const SizedBox(height: 26),
          Tag(
            'R42.1',
            'The moment: tick, then title',
            child: Column(
              children: <Widget>[
                GestureDetector(
                  onTap: _play,
                  child: ListenableBuilder(
                    listenable: _check,
                    builder: (BuildContext context, Widget? child) =>
                        Transform.scale(scale: _check.value, child: child),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: const ShapeDecoration(
                        color: green,
                        shape: CircleBorder(),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _in(
                  0,
                  Text(
                    'Push day, done',
                    textAlign: TextAlign.center,
                    style: LumenType.display(
                      34,
                      weight: 720,
                      color: c.ink,
                      height: 1.05,
                    ),
                  ),
                ),
                _in(
                  0,
                  Text(
                    'Thursday  ·  tap the tick to replay',
                    textAlign: TextAlign.center,
                    style: LumenType.text(14, color: c.inkMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _in(
            1,
            Tag(
              'R42.2',
              'Numbers that count up once',
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      stat('Time', 52, 2, 'min'),
                      const SizedBox(width: 10),
                      stat('Lifted', 6840, 4, 'kg'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      stat('Sets', 17, 2, 'done'),
                      const SizedBox(width: 10),
                      stat('Streak', 4, 1, 'days'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _in(
            2,
            Tag(
              'R42.3',
              'What was special today',
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: ShapeDecoration(
                  color: gold.withValues(alpha: 0.13),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(color: gold.withValues(alpha: 0.5)),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: gold,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Personal best',
                            style: LumenType.text(
                              13,
                              weight: 650,
                              color: c.inkMuted,
                            ),
                          ),
                          Text(
                            'Bench press  80 kg × 8',
                            style: LumenType.text(
                              16.5,
                              weight: 680,
                              color: c.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+2.5 kg',
                      style: LumenType.text(
                        14,
                        weight: 700,
                        color: c.dark ? gold : const Color(0xFF8A6500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _in(
            3,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Tag(
                  'R42.4',
                  'One question, one tap',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'How did it feel?',
                        style: LumenType.text(15.5, weight: 650, color: c.ink),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          for (final (int i, (IconData, String) f)
                              in const <(IconData, String)>[
                                (
                                  Icons.sentiment_very_dissatisfied_rounded,
                                  'Rough',
                                ),
                                (Icons.sentiment_dissatisfied_rounded, 'Hard'),
                                (Icons.sentiment_neutral_rounded, 'Okay'),
                                (Icons.sentiment_satisfied_rounded, 'Good'),
                                (
                                  Icons.sentiment_very_satisfied_rounded,
                                  'Great',
                                ),
                              ].indexed)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() => _feel = i);
                                Haptics.tick();
                              },
                              child: Column(
                                children: <Widget>[
                                  AnimatedScale(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutBack,
                                    scale: _feel == i ? 1.18 : 1,
                                    child: Container(
                                      width: 54,
                                      height: 54,
                                      decoration: ShapeDecoration(
                                        color: _feel == i
                                            ? c.accent
                                            : c.ink.withValues(alpha: 0.06),
                                        shape: const CircleBorder(),
                                      ),
                                      child: Icon(
                                        f.$1,
                                        size: 28,
                                        color: _feel == i
                                            ? c.onAccent
                                            : c.inkMuted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    f.$2,
                                    style: LumenType.text(
                                      12,
                                      weight: _feel == i ? 700 : 520,
                                      color: _feel == i ? c.ink : c.inkMuted,
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
                const SizedBox(height: 26),
                Tag(
                  'R42.5',
                  'One way out, one extra',
                  child: Row(
                    children: <Widget>[
                      Pressable(
                        onTap: Haptics.tick,
                        child: Container(
                          height: 58,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          decoration: ShapeDecoration(
                            shape: StadiumBorder(
                              side: BorderSide(color: c.inkFaint),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.ios_share_rounded,
                                size: 20,
                                color: c.ink,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Share',
                                style: LumenType.text(
                                  15.5,
                                  weight: 650,
                                  color: c.ink,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Pressable(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            height: 58,
                            alignment: Alignment.center,
                            decoration: ShapeDecoration(
                              color: c.accent,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              'Done',
                              style: LumenType.text(
                                16,
                                weight: 700,
                                color: c.onAccent,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
