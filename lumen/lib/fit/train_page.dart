import 'bubble.dart';
import 'robot.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/haptics.dart';
import '../core/settings.dart';
import '../core/springs.dart';
import '../core/theme.dart';
import '../widgets/pressable.dart';
import '../widgets/tag.dart';
import '../core/glass.dart';
import 'common.dart';
import 'diag.dart';
import '../rooms/patterns/inputs_room.dart';

/// Room 39. A complete "workout in progress" screen: where you are, the
/// sets as thumb dials, one tap to finish a set, and a rest timer that
/// starts by itself and stays out of the way.
class TrainPage extends StatefulWidget {
  const TrainPage({super.key});

  @override
  State<TrainPage> createState() => _TrainPageState();
}

class _TrainPageState extends State<TrainPage> with TickerProviderStateMixin {
  static const int _restTotal = 90;
  final List<double> _kg = <double>[60, 80, 80, 80];
  final List<double> _reps = <double>[10, 8, 8, 6];
  final List<bool> _done = <bool>[true, false, false, false];
  late final List<SpringValue> _pop = <SpringValue>[
    for (int i = 0; i < 4; i++)
      SpringValue(this, value: 1, spring: Motions.expressiveFast),
  ];
  late final SpringValue _rest = SpringValue(this, spring: Motions.expressive);
  late final SpringValue _next = SpringValue(this, spring: Motions.expressive);
  int _elapsed = 14 * 60 + 32;
  int _restLeft = 0, _restOf = _restTotal;

  /// When the running rest ends. The countdown is worked out from this, not counted down tick
  /// by tick, so it stays right while Prism is off screen.
  DateTime? _restEnds;

  /// Starts, changes or ends the rest, and tells the floating timer.
  void _setRest(DateTime? ends) {
    _restEnds = ends;
    _restLeft = ends == null
        ? 0
        : (ends.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(
            0,
            86400,
          );
    _sync();
  }

  /// A workout is on from the first set you touch until the last one is ticked.
  bool _started = false;
  DateTime _lastSet = DateTime.now();

  void _modeChanged() {
    if (mounted) {
      setState(() {});
      _sync();
    }
  }

  void _addRest() {
    setState(() {
      _restOf += 15;
      _setRest((_restEnds ?? DateTime.now()).add(const Duration(seconds: 15)));
    });
    Haptics.tick();
  }

  void _skipRest() {
    setState(() => _setRest(null));
    _rest.animateTo(0, spring: Motions.spatial);
    Diag.instance.extra = '';
    Haptics.tick();
  }

  /// Tells the floating workout what it should show.
  void _sync() {
    final int i = _current;
    if (!_started || i < 0) {
      RestBubble.instance.tell(null);
      return;
    }
    final LumenColors c = LumenColors.of(context);
    RestBubble.instance.tell(<String, Object>{
      'title': 'Bench press',
      'exercise': 'Exercise 2 of 5',
      'set': i == 0 ? 'Warm-up set' : 'Set $i of ${_done.length - 1}',
      'current': i,
      'sets': <Map<String, Object>>[
        for (int k = 0; k < _done.length; k++)
          <String, Object>{
            'kg': _kg[k],
            'reps': _reps[k].round(),
            'done': _done[k],
          },
      ],
      'countUp': RestBubble.instance.countUp.value,
      'haptics': settings.haptics,
      'endsAt': _restEnds?.millisecondsSinceEpoch ?? 0,
      'total': _restOf,
      'sinceAt': _lastSet.millisecondsSinceEpoch,
      'accent': c.accent.toARGB32(),
      'onAccent': c.onAccent.toARGB32(),
    });
  }

  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    // A set logged from the floating panel: take its numbers and tick it, exactly as a tap here would.
    // What the floating sheet does is exactly what a touch on this page does.
    RestBubble.instance
      ..onToggle = (int i) {
        if (mounted && i >= 0 && i < _done.length) {
          _toggle(i);
        }
      }
      ..onValue = (int i, double kg, int reps) {
        if (mounted && i >= 0 && i < _done.length) {
          setState(() {
            _kg[i] = kg;
            _reps[i] = reps.toDouble();
          });
          _started = true;
          _sync();
        }
      }
      ..onRest = (bool add) {
        if (mounted) {
          add ? _addRest() : _skipRest();
        }
      }
      ..countUp.addListener(_modeChanged);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      // Keep time always, but only redraw while this page is the one on screen:
      // a clock nobody can see should not wake the screen once a second.
      void Function(void Function()) apply = Diag.instance.page == 'train'
          ? setState
          : (void Function() f) => f();
      apply(() {
        _elapsed++;
        if (_restEnds != null) {
          _restLeft =
              (_restEnds!.difference(DateTime.now()).inMilliseconds / 1000)
                  .ceil()
                  .clamp(0, 86400);
          if (_restLeft == 0) {
            _restEnds = null;
            // One buzz when a rest ends, never two. Where the floating lens is on screen it gives
            // it; on this page, where the lens is not, the page does.
            final bool hereAndNow =
                Diag.instance.page == 'train' &&
                WidgetsBinding.instance.lifecycleState ==
                    AppLifecycleState.resumed;
            if (hereAndNow || !RestBubble.instance.allowed.value) {
              Haptics.thud();
            }
            _rest.animateTo(0, spring: Motions.spatial);
            Diag.instance.extra = '';
          }
        }
      });
    });
  }

  @override
  void dispose() {
    RestBubble.instance
      ..onToggle = null
      ..onValue = null
      ..onRest = null
      ..countUp.removeListener(_modeChanged);
    _clock.cancel();
    for (final SpringValue s in <SpringValue>[..._pop, _rest, _next]) {
      s.dispose();
    }
    super.dispose();
  }

  String _mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  int get _current => _done.indexOf(false);

  void _toggle(int i) {
    _started = true;
    if (!_done[i]) {
      _lastSet = DateTime.now();
    }
    setState(() => _done[i] = !_done[i]);
    Diag.instance.event('set tick');
    _pop[i].jumpTo(0.7);
    _pop[i].animateTo(1);
    final bool all = !_done.contains(false);
    _next.animateTo(all ? 1 : 0);
    if (_done[i] && !all) {
      // Finishing a set starts the rest; nobody should have to ask for it.
      Haptics.settle();
      setState(() {
        _restOf = _restTotal;
        _setRest(DateTime.now().add(const Duration(seconds: _restTotal)));
      });
      _rest.animateTo(1);
      Diag.instance.extra = '+rest';
    } else {
      all ? Haptics.thud() : Haptics.tick();
      setState(() => _setRest(null));
      _rest.animateTo(0, spring: Motions.spatial);
      Diag.instance.extra = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    const Color green = Color(0xFF2FA84F);
    final int cur = _current;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              safe.top + 22,
              16,
              safe.bottom + 200,
            ),
            children: <Widget>[
              const PageTitle('Train'),
              const SizedBox(height: 20),
              Tag(
                'R39.1',
                'Where you are',
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < 5; i++)
                      Expanded(
                        child: Container(
                          height: 5,
                          margin: EdgeInsets.only(right: i < 4 ? 5 : 0),
                          decoration: ShapeDecoration(
                            color: i < 1
                                ? green
                                : (i == 1
                                      ? c.accent
                                      : c.ink.withValues(alpha: 0.12)),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Icon(Icons.schedule_rounded, size: 15, color: c.inkMuted),
                    const SizedBox(width: 4),
                    Text(
                      _mmss(_elapsed),
                      textScaler: TextScaler.noScaling,
                      style:
                          LumenType.text(
                            13.5,
                            weight: 650,
                            color: c.inkMuted,
                          ).copyWith(
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('EXERCISE 2 OF 5', style: LumenType.label(color: c.accent)),
              const SizedBox(height: 2),
              Text(
                'Bench press',
                style: LumenType.display(
                  38,
                  weight: 720,
                  color: c.ink,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Tag(
                  'R39.2',
                  'Last time, as a hint',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: ShapeDecoration(
                      color: c.ink.withValues(alpha: 0.06),
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: c.inkMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Last time 77.5 kg × 8, 8, 7',
                          style: LumenType.text(
                            13.5,
                            weight: 560,
                            color: c.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Tag(
                'R39.3',
                'Set rows with dials',
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(40, 0, 66, 6),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Center(
                              child: Text(
                                'KG',
                                style: LumenType.label(color: c.inkFaint),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Center(
                              child: Text(
                                'REPS',
                                style: LumenType.label(color: c.inkFaint),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (int i = 0; i < 4; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        // No padding above, below or to the right: that room belongs to the controls now,
                        // so a thumb landing anywhere in the row hits something.
                        padding: const EdgeInsets.only(left: 14),
                        decoration: ShapeDecoration(
                          color: _done[i]
                              ? green.withValues(alpha: 0.1)
                              : c.ink.withValues(alpha: i == cur ? 0.08 : 0.04),
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                              color: i == cur
                                  ? c.accent.withValues(alpha: 0.6)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              width: 26,
                              child: Text(
                                i == 0 ? 'W' : '$i',
                                style: LumenType.text(
                                  15,
                                  weight: 700,
                                  color: i == 0 ? c.inkMuted : c.ink,
                                ),
                              ),
                            ),
                            Expanded(
                              child: IgnorePointer(
                                ignoring: _done[i],
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: _done[i] ? 0.55 : 1,
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: DragDial(
                                          value: _kg[i],
                                          step: 1,
                                          fineStep: 0.5,
                                          min: 0,
                                          max: 400,
                                          unit: 'kg',
                                          touchPad: const EdgeInsets.fromLTRB(
                                            0,
                                            10,
                                            4,
                                            10,
                                          ),
                                          onChanged: (double v) => setState(() {
                                            _kg[i] = v;
                                            _sync();
                                          }),
                                        ),
                                      ),
                                      Expanded(
                                        child: DragDial(
                                          value: _reps[i],
                                          step: 1,
                                          fineStep: 1,
                                          min: 0,
                                          max: 60,
                                          unit: 'reps',
                                          touchPad: const EdgeInsets.fromLTRB(
                                            4,
                                            10,
                                            0,
                                            10,
                                          ),
                                          onChanged: (double v) => setState(() {
                                            _reps[i] = v;
                                            _sync();
                                          }),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Semantics(
                              button: true,
                              label: _done[i] ? 'Set done' : 'Finish set',
                              child: GestureDetector(
                                key: i == 1 ? Robot.key('tick') : null,
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _toggle(i),
                                // The tick looks the same size, but the whole right end of the row is its button.
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    12,
                                    10,
                                    12,
                                  ),
                                  child: ListenableBuilder(
                                    listenable: _pop[i],
                                    builder:
                                        (BuildContext context, Widget? child) =>
                                            Transform.scale(
                                              scale: _pop[i].value,
                                              child: child,
                                            ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      width: 48,
                                      height: 48,
                                      decoration: ShapeDecoration(
                                        color: _done[i]
                                            ? green
                                            : Colors.transparent,
                                        shape: CircleBorder(
                                          side: BorderSide(
                                            color: _done[i]
                                                ? green
                                                : c.inkFaint,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.check_rounded,
                                        size: 24,
                                        color: _done[i]
                                            ? Colors.white
                                            : c.inkFaint,
                                      ),
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
              Row(
                children: <Widget>[
                  Icon(Icons.add_rounded, size: 18, color: c.accent),
                  const SizedBox(width: 4),
                  Text(
                    'Add a set',
                    style: LumenType.text(14.5, weight: 650, color: c.accent),
                  ),
                  const Spacer(),
                  Text(
                    'W = warm-up',
                    style: LumenType.text(12.5, color: c.inkFaint),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Tag(
                'R39.5',
                'The next step wakes up when it is time',
                child: ListenableBuilder(
                  listenable: _next,
                  builder: (BuildContext context, Widget? _) {
                    final double t = _next.value.clamp(0.0, 1.0);
                    return Transform.scale(
                      scale: 1 + 0.03 * _next.value,
                      child: Pressable(
                        onTap: Haptics.settle,
                        child: Container(
                          height: 58,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: Color.lerp(
                              c.ink.withValues(alpha: 0.07),
                              c.accent,
                              t,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Next: Incline press',
                            style: LumenType.text(
                              16,
                              weight: 680,
                              color: Color.lerp(c.inkMuted, c.onAccent, t),
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // Rest timer: appears when a set is finished, floats, never blocks the rows.
          Positioned(
            left: 16,
            right: 16,
            bottom: safe.bottom + 96,
            child: ListenableBuilder(
              listenable: _rest,
              builder: (BuildContext context, Widget? child) => IgnorePointer(
                ignoring: _rest.value < 0.5,
                child: Transform.translate(
                  offset: Offset(0, (1 - _rest.value) * 280),
                  child: child,
                ),
              ),
              child: Tag(
                'R39.4',
                'Rest timer starts itself',
                child: Container(
                  height: 72,
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(shape: const StadiumBorder()),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: Glass(
                          radius: 36,
                          style: GlassStyle(
                            blur: 18,
                            tint: 0.5,
                            refraction: 26,
                            bevel: 18,
                            fallbackColor: c.surfaceHigh,
                          ),
                        ),
                      ),
                      AnimatedFractionallySizedBox(
                        duration: const Duration(seconds: 1),
                        // The bar empties in a countdown and fills when counting up.
                        widthFactor: _restOf == 0
                            ? 0
                            : ((RestBubble.instance.countUp.value
                                          ? _restOf - _restLeft
                                          : _restLeft) /
                                      _restOf)
                                  .clamp(0.0, 1.0),
                        heightFactor: 1,
                        alignment: Alignment.centerLeft,
                        child: ColoredBox(
                          color: c.accent.withValues(alpha: 0.2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 24, right: 10),
                        child: Row(
                          children: <Widget>[
                            // A tap on the time switches between counting down and counting up.
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                RestBubble.instance.toggleMode();
                                Haptics.settle();
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    RestBubble.instance.countUp.value
                                        ? 'RESTING'
                                        : 'REST LEFT',
                                    style: LumenType.label(color: c.inkMuted),
                                  ),
                                  Text(
                                    _mmss(
                                      RestBubble.instance.countUp.value
                                          ? (_restOf - _restLeft).clamp(
                                              0,
                                              86400,
                                            )
                                          : _restLeft,
                                    ),
                                    textScaler: TextScaler.noScaling,
                                    style:
                                        LumenType.display(
                                          28,
                                          weight: 700,
                                          color: c.ink,
                                          height: 1.05,
                                        ).copyWith(
                                          fontFeatures: const <FontFeature>[
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            _pill(c, '+15 s', _addRest),
                            const SizedBox(width: 8),
                            _pill(c, 'Skip', _skipRest, strong: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(
    LumenColors c,
    String label,
    VoidCallback onTap, {
    bool strong = false,
  }) => Pressable(
    onTap: onTap,
    child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: strong ? c.accent : c.ink.withValues(alpha: 0.08),
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: LumenType.text(
          14.5,
          weight: 680,
          color: strong ? c.onAccent : c.ink,
          height: 1,
        ),
      ),
    ),
  );
}
