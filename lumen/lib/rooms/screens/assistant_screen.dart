import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/tag.dart';
import '../shapes/shape_loader.dart';

class _Turn {
  _Turn(
    this.question,
    this.answer,
    this.steps,
    this.sources, {
    this.plan = false,
  });
  final String question;
  final String answer; // "[1]" marks a citation
  final List<String> steps;
  final List<(String, String)> sources;
  final bool plan;
  int words = 0;
  bool thinking = true,
      done = false,
      showSteps = false,
      showSources = false,
      added = false;
}

const List<(String, String, List<String>, List<(String, String)>, bool)>
_canned = <(String, String, List<String>, List<(String, String)>, bool)>[
  (
    'Plan my training week',
    'You trained pull on Monday and ran on Wednesday, so legs are the freshest [1]. I would put the heavy leg day tomorrow, an easy day after it, and push on Sunday when you usually have the most time [2]. Here is the week as a plan you can add.',
    <String>[
      'Read the last 14 days of workouts',
      'Checked which muscle groups rested longest',
      'Matched session length to your usual free time',
    ],
    <(String, String)>[
      ('Your workout log', 'Last 14 days'),
      ('Your calendar pattern', 'Sundays: 90 min sessions'),
    ],
    true,
  ),
  (
    'Why am I tired on leg day?',
    'Two things stand out. Your leg days follow your shortest nights: 6.1 hours on average against 7.4 on other days [1]. And you eat about 400 kcal less the day before [2]. Either one alone would be enough to feel it.',
    <String>[
      'Compared sleep before each workout type',
      'Compared food logged the day before',
      'Looked for anything else that differs',
    ],
    <(String, String)>[
      ('Sleep data', 'Health Connect, 8 weeks'),
      ('Food log', 'Days before leg sessions'),
    ],
    false,
  ),
];

/// Room 28. A complete AI chat screen. The answer streams in, cites where
/// it got things, can show its working, and can hand back something to act
/// on instead of more text.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final List<_Turn> _turns = <_Turn>[];
  final ScrollController _scroll = ScrollController();
  Timer? _timer;
  bool get _busy => _turns.isNotEmpty && !_turns.last.done;

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _ask(int i) {
    if (_busy) {
      return;
    }
    final (
      String q,
      String a,
      List<String> st,
      List<(String, String)> so,
      bool plan,
    ) = _canned[i];
    final _Turn t = _Turn(q, a, st, so, plan: plan);
    setState(() => _turns.add(t));
    Haptics.tick();
    _toEnd();
    final List<String> words = a.split(' ');
    _timer = Timer(const Duration(milliseconds: 1400), () {
      setState(() => t.thinking = false);
      _timer = Timer.periodic(const Duration(milliseconds: 45), (Timer tm) {
        setState(() => t.words++);
        _toEnd();
        if (t.words >= words.length) {
          tm.cancel();
          setState(() => t.done = true);
          Haptics.settle();
        }
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _turns.last
        ..thinking = false
        ..done = true;
    });
    Haptics.tick();
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          ListView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              safe.top + 108,
              16,
              safe.bottom + 170,
            ),
            children: <Widget>[
              if (_turns.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: <Widget>[
                      ShapeLoader(size: 64, color: c.accent),
                      const SizedBox(height: 18),
                      Text(
                        'Ask about your training',
                        style: LumenType.display(26, weight: 700, color: c.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A demo: the two suggestions below have prepared answers. There is no model behind it.',
                        textAlign: TextAlign.center,
                        style: LumenType.text(14, color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
              for (final _Turn t in _turns) ..._turn(c, t),
            ],
          ),
          Positioned(
            top: safe.top + 44,
            left: 16,
            right: 16,
            child: const ScreenBar(number: 28),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 26, 16, safe.bottom + 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const <double>[0, 0.3],
                  colors: <Color>[c.bg.withValues(alpha: 0), c.bg],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Tag(
                    'R28.5',
                    'Suggestion chips',
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          for (int i = 0; i < _canned.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Pressable(
                                onTap: _busy ? null : () => _ask(i),
                                scale: 0.95,
                                child: Opacity(
                                  opacity: _busy ? 0.4 : 1,
                                  child: Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: ShapeDecoration(
                                      color: c.surface,
                                      shape: StadiumBorder(
                                        side: BorderSide(color: c.hairline),
                                      ),
                                    ),
                                    child: Text(
                                      _canned[i].$1,
                                      style: LumenType.text(
                                        14,
                                        weight: 600,
                                        color: c.ink,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Tag(
                    'R28.6',
                    'Prompt bar: send becomes stop',
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.only(left: 18, right: 7),
                      decoration: ShapeDecoration(
                        color: c.surface,
                        shape: StadiumBorder(
                          side: BorderSide(color: c.hairline),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _busy ? 'Answering…' : 'Ask anything',
                              style: LumenType.text(16, color: c.inkFaint),
                            ),
                          ),
                          GestureDetector(
                            onTap: _busy
                                ? _stop
                                : () => _ask(_turns.length % _canned.length),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 44,
                              height: 44,
                              decoration: ShapeDecoration(
                                color: _busy ? c.ink : c.accent,
                                shape: RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.circular(
                                    _busy ? 14 : 22,
                                  ),
                                ),
                              ),
                              child: Icon(
                                _busy
                                    ? Icons.stop_rounded
                                    : Icons.arrow_upward_rounded,
                                color: _busy ? c.bg : c.onAccent,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _turn(LumenColors c, _Turn t) {
    final List<String> words = t.answer.split(' ');
    final String shown = words.take(t.words).join(' ');
    return <Widget>[
      Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 60, bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: ShapeDecoration(
            color: c.accent,
            shape: const RoundedSuperellipseBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(6),
              ),
            ),
          ),
          child: Text(
            t.question,
            style: LumenType.text(15.5, weight: 560, color: c.onAccent),
          ),
        ),
      ),
      if (t.thinking)
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            children: <Widget>[
              ShapeLoader(size: 22, color: c.accent),
              const SizedBox(width: 10),
              Text(
                'Looking at your data',
                style: LumenType.text(14.5, color: c.inkMuted),
              ),
            ],
          ),
        )
      else ...<Widget>[
        Tag(
          'R28.1',
          'Collapsible reasoning',
          child: _fold(
            c,
            t.showSteps,
            'How I worked this out',
            Icons.psychology_alt_outlined,
            () => setState(() => t.showSteps = !t.showSteps),
            <Widget>[
              for (int i = 0; i < t.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${i + 1}. ${t.steps[i]}',
                    style: LumenType.text(13.5, color: c.inkMuted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Tag(
          'R28.2',
          'Streaming answer with citations',
          child: Text.rich(
            TextSpan(children: _withCitations(c, shown, !t.done)),
            style: LumenType.text(16, color: c.ink, height: 1.55),
          ),
        ),
        if (t.done && t.plan) ...<Widget>[
          const SizedBox(height: 14),
          Tag(
            'R28.3',
            'Generated card with an action',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: ShapeDecoration(
                color: c.surface,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: c.hairline),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'PROPOSED WEEK',
                    style: LumenType.label(color: c.inkFaint),
                  ),
                  const SizedBox(height: 8),
                  for (final (String d, String w) in <(String, String)>[
                    ('Sat', 'Legs, heavy · 70 min'),
                    ('Sun', 'Push · 90 min'),
                    ('Tue', 'Pull · 60 min'),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 44,
                            child: Text(
                              d,
                              style: LumenType.text(
                                14,
                                weight: 700,
                                color: c.accent,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              w,
                              style: LumenType.text(
                                15,
                                weight: 560,
                                color: c.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  Pressable(
                    onTap: t.added
                        ? null
                        : () {
                            setState(() => t.added = true);
                            Haptics.settle();
                          },
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: t.added ? const Color(0xFF2FA84F) : c.accent,
                        shape: const StadiumBorder(),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (t.added) ...<Widget>[
                            const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            t.added ? 'Added to your plan' : 'Add to my plan',
                            style: LumenType.text(
                              15,
                              weight: 660,
                              color: t.added ? Colors.white : c.onAccent,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (t.done) ...<Widget>[
          const SizedBox(height: 12),
          Tag(
            'R28.4',
            'Sources',
            child: _fold(
              c,
              t.showSources,
              '${t.sources.length} sources',
              Icons.link_rounded,
              () => setState(() => t.showSources = !t.showSources),
              <Widget>[
                for (int i = 0; i < t.sources.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: <Widget>[
                        _cite(c, i + 1),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: <InlineSpan>[
                                TextSpan(
                                  text: t.sources[i].$1,
                                  style: LumenType.text(
                                    14,
                                    weight: 620,
                                    color: c.ink,
                                  ),
                                ),
                                TextSpan(
                                  text: '  ${t.sources[i].$2}',
                                  style: LumenType.text(13, color: c.inkMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              for (final IconData i in <IconData>[
                Icons.content_copy_rounded,
                Icons.thumb_up_alt_outlined,
                Icons.thumb_down_alt_outlined,
                Icons.refresh_rounded,
              ])
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(i, size: 18, color: c.inkFaint),
                ),
              const Spacer(),
              Text(
                'AI answer · check before relying on it',
                style: LumenType.text(11.5, color: c.inkFaint),
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),
      ],
    ];
  }

  Widget _cite(LumenColors c, int n) => Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: ShapeDecoration(
      color: c.accent.withValues(alpha: 0.2),
      shape: const CircleBorder(),
    ),
    child: Text(
      '$n',
      textScaler: TextScaler.noScaling,
      style: LumenType.text(11, weight: 700, color: c.accent, height: 1),
    ),
  );

  List<InlineSpan> _withCitations(LumenColors c, String text, bool cursor) {
    final List<InlineSpan> out = <InlineSpan>[];
    final RegExp re = RegExp(r'\[(\d)\]');
    int at = 0;
    for (final RegExpMatch m in re.allMatches(text)) {
      out.add(TextSpan(text: text.substring(at, m.start)));
      out.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _cite(c, int.parse(m.group(1)!)),
          ),
        ),
      );
      at = m.end;
    }
    out.add(TextSpan(text: text.substring(at)));
    if (cursor) {
      out.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
          ),
        ),
      );
    }
    return out;
  }

  Widget _fold(
    LumenColors c,
    bool open,
    String title,
    IconData icon,
    VoidCallback onTap,
    List<Widget> body,
  ) {
    return Container(
      decoration: ShapeDecoration(
        color: c.ink.withValues(alpha: 0.05),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              onTap();
              Haptics.tick();
            },
            child: SizedBox(
              height: 44,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 12),
                  Icon(icon, size: 18, color: c.inkMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: LumenType.text(
                        13.5,
                        weight: 620,
                        color: c.inkMuted,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: c.inkMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: body,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
