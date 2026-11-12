import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../shapes/shape_loader.dart';

const List<String> _suggestions = <String>[
  'Make this message sound calmer',
  'Summarise my unread mail',
  'Plan a quiet Sunday',
  'Explain springs like I am five',
];

const Map<String, String> _answers = <String, String>{
  'Make this message sound calmer':
      'Here is a calmer version: "Thanks for the update. I need a little more time to review this '
      'properly, and I will come back to you by Thursday with a clear answer." It keeps your deadline, '
      'drops the apology and sounds settled rather than rushed.',
  'Summarise my unread mail':
      'Three things need you today: Mira sent the final prints, the Thursday workshop moved rooms, '
      'and Jonas wants your opinion on the spring presets. Everything else can wait until Monday.',
  'Plan a quiet Sunday':
      'Slow breakfast without a screen, a long walk somewhere green before noon, one thing cooked '
      'properly for lunch, an afternoon with a book, and an early night. Leave one hour with no plan at all.',
  'Explain springs like I am five':
      'Imagine a ball tied to a rubber band. Pull it and let go: it zooms back, goes a bit too far, '
      'wobbles, and stops. Apps can move things the same way, so they feel like real objects instead of robots.',
};

const String _demoAnswer =
    'There is no real AI behind this bar: it is a demo of how an answer should arrive. It streams in '
    'word by word, says clearly what it is, and offers its sources and actions only once it has finished.';

enum _Phase { idle, thinking, streaming, done }

/// An AI prompt bar: rotating suggestions, a send button that changes shape
/// when there is something to send, a thinking state, and an answer that
/// streams in with an honest label about what it is.
class PromptBar extends StatefulWidget {
  const PromptBar({super.key});

  @override
  State<PromptBar> createState() => _PromptBarState();
}

class _PromptBarState extends State<PromptBar> with TickerProviderStateMixin {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  late final SpringValue _hint = SpringValue(this, spring: Motions.spatial);
  late final SpringValue _ready = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _think = SpringValue(this, spring: Motions.effects);
  late final SpringValue _card = SpringValue(this, spring: Motions.expressive);
  late final SpringValue _actions = SpringValue(this, spring: Motions.effects);
  final ValueNotifier<double> _spin = ValueNotifier<double>(0);
  late final Ticker _spinner = createTicker(
    (Duration e) => _spin.value = e.inMicroseconds / 1e6,
  );
  Timer? _hintTimer;
  Timer? _stream;
  _Phase _phase = _Phase.idle;
  int _words = 0;
  List<String> _answerWords = const <String>[];
  bool _canned = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      _ready.animateTo(_text.text.trim().isEmpty ? 0 : 1);
      setState(() {});
    });
    _hintTimer = Timer.periodic(
      const Duration(milliseconds: 2800),
      (_) => _hint.animateTo(_hint.target + 1),
    );
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _stream?.cancel();
    _spinner.dispose();
    _spin.dispose();
    for (final SpringValue s in <SpringValue>[
      _hint,
      _ready,
      _think,
      _card,
      _actions,
    ]) {
      s.dispose();
    }
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final String q = _text.text.trim().isEmpty
        ? _suggestions[_hint.target.round() % _suggestions.length]
        : _text.text.trim();
    if (_phase == _Phase.thinking || _phase == _Phase.streaming) {
      return;
    }
    _focus.unfocus();
    Haptics.tick();
    setState(() {
      _phase = _Phase.thinking;
      _asked = q;
      _words = 0;
      _canned = !_answers.containsKey(q);
      _answerWords = (_answers[q] ?? _demoAnswer).split(' ');
    });
    _text.clear();
    _spinner.start();
    _think.animateTo(1);
    _actions.jumpTo(0);
    _card.jumpTo(0);
    _card.animateTo(1);
    _stream?.cancel();
    _stream = Timer(const Duration(milliseconds: 1300), () {
      setState(() => _phase = _Phase.streaming);
      _stream = Timer.periodic(const Duration(milliseconds: 42), (Timer t) {
        setState(() => _words++);
        if (_words >= _answerWords.length) {
          t.cancel();
          setState(() => _phase = _Phase.done);
          _think.animateTo(0);
          _think.onSettle = () => _spinner.stop();
          _actions.onSettle = Haptics.settle;
          _actions.animateTo(1);
        }
      });
    });
  }

  String _asked = '';

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _bar(c),
        if (_phase != _Phase.idle)
          ListenableBuilder(
            listenable: _card,
            builder: (BuildContext context, Widget? child) {
              final double v = _card.value;
              return Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - v) * -18),
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _answerCard(c),
            ),
          ),
      ],
    );
  }

  Widget _bar(LumenColors c) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_think, _spin, _ready, _hint]),
      builder: (BuildContext context, Widget? field) {
        final double th = _think.value.clamp(0.0, 1.0);
        return CustomPaint(
          foregroundPainter: _SweepBorder(th, _spin.value, c),
          child: Container(
            height: 60,
            padding: const EdgeInsets.only(left: 20, right: 8),
            decoration: ShapeDecoration(
              color: c.surface,
              shape: StadiumBorder(side: BorderSide(color: c.hairline)),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: Color.lerp(c.inkFaint, c.accent, th),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: <Widget>[
                      if (_text.text.isEmpty) _hintText(c, th),
                      field!,
                    ],
                  ),
                ),
                _sendButton(c),
              ],
            ),
          ),
        );
      },
      child: TextField(
        controller: _text,
        focusNode: _focus,
        onSubmitted: (_) => _send(),
        textInputAction: TextInputAction.send,
        cursorColor: c.accent,
        style: LumenType.text(16, color: c.ink),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }

  Widget _hintText(LumenColors c, double thinking) {
    if (_phase == _Phase.thinking) {
      return Text('Thinking…', style: LumenType.text(16, color: c.inkMuted));
    }
    // The suggestion rolls up and the next one rises in behind it.
    final double v = _hint.value;
    final int i = v.floor();
    final double t = v - i;
    Widget line(String s, double dy, double a) => Transform.translate(
      offset: Offset(0, dy),
      child: Opacity(
        opacity: a.clamp(0.0, 1.0),
        child: Text(
          s,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: LumenType.text(16, color: c.inkFaint),
        ),
      ),
    );
    return IgnorePointer(
      child: ClipRect(
        child: SizedBox(
          height: 26,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              line(_suggestions[i % _suggestions.length], -22 * t, 1 - t * 1.6),
              line(
                _suggestions[(i + 1) % _suggestions.length],
                22 * (1 - t),
                t * 1.6 - 0.4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sendButton(LumenColors c) {
    final double r = _ready.value;
    final double on = r.clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label: 'Send',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _send,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Transform.rotate(
              angle: (1 - r) * -math.pi / 2,
              child: Container(
                width: 44,
                height: 44,
                decoration: ShapeDecoration(
                  color: Color.lerp(c.surfaceHigh, c.accent, on),
                  // Round while idle, a softer square once there is something to send.
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(
                      ui.lerpDouble(22, 14, r)!,
                    ),
                  ),
                ),
                child: Icon(
                  on > 0.5
                      ? Icons.arrow_upward_rounded
                      : Icons.subdirectory_arrow_left_rounded,
                  size: 22,
                  color: Color.lerp(c.inkMuted, c.onAccent, on),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _answerCard(LumenColors c) {
    final bool streaming = _phase == _Phase.streaming;
    final String shown = _answerWords.take(_words).join(' ');
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: ShapeDecoration(
        color: c.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: c.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '“$_asked”',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: LumenType.text(13.5, weight: 560, color: c.inkMuted),
          ),
          const SizedBox(height: 12),
          if (_phase == _Phase.thinking)
            Row(
              children: <Widget>[
                ShapeLoader(size: 22, color: c.accent),
                const SizedBox(width: 12),
                Text(
                  'Reading your message',
                  style: LumenType.text(15, color: c.inkMuted),
                ),
              ],
            )
          else
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: shown),
                  if (streaming)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        margin: const EdgeInsets.only(left: 3),
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              style: LumenType.text(16, color: c.ink, height: 1.5),
            ),
          const SizedBox(height: 14),
          ListenableBuilder(
            listenable: _actions,
            builder: (BuildContext context, Widget? child) => Opacity(
              opacity: _actions.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - _actions.value)),
                child: child,
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (_canned)
                  _Chip(
                    icon: Icons.science_outlined,
                    label: 'Demo reply, no model',
                    color: c.accent,
                  )
                else
                  _Chip(
                    icon: Icons.auto_awesome_rounded,
                    label: 'AI draft',
                    color: c.accent,
                  ),
                _Chip(
                  icon: Icons.link_rounded,
                  label: _canned ? '0 sources' : '2 sources',
                  color: c.inkMuted,
                ),
                _Chip(
                  icon: Icons.info_outline_rounded,
                  label: 'Check before using',
                  color: c.inkMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: c.ink.withValues(alpha: 0.06),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: LumenType.text(12, weight: 560, color: color, height: 1.1),
          ),
        ],
      ),
    );
  }
}

/// A bright arc that runs around the bar while it is thinking.
class _SweepBorder extends CustomPainter {
  const _SweepBorder(this.amount, this.time, this.c);
  final double amount;
  final double time;
  final LumenColors c;

  @override
  void paint(Canvas canvas, Size size) {
    if (amount <= 0.01) {
      return;
    }
    final Rect r = Offset.zero & size;
    final RRect rr = RRect.fromRectAndRadius(
      r.deflate(1),
      Radius.circular(size.height / 2),
    );
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = SweepGradient(
        transform: GradientRotation(time * 3.2),
        colors: <Color>[
          c.accent.withValues(alpha: 0),
          c.accent.withValues(alpha: amount),
          const Color(0xFF8E7CFF).withValues(alpha: amount),
          c.accent.withValues(alpha: 0),
        ],
        stops: const <double>[0.0, 0.18, 0.34, 0.5],
      ).createShader(r);
    canvas.drawRRect(rr, p);
    canvas.drawRRect(
      rr,
      p
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(_SweepBorder old) =>
      old.amount != amount || old.time != time || old.c != c;
}
