import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';

class _Alt {
  const _Alt(this.name, this.gear, this.load, this.match, this.why);
  final String name, gear, load;
  final int match;

  /// One line per reason for swapping: 0 equipment busy, 1 discomfort, 2 variety.
  final List<String> why;
}

const _Alt _original = _Alt(
  'Bench press',
  'Barbell, bench',
  '80 kg',
  100,
  <String>['', '', ''],
);
const List<_Alt> _alts = <_Alt>[
  _Alt('Dumbbell press', 'Dumbbells, bench', '30 kg each', 95, <String>[
    'Needs a bench',
    'Freer wrist angle',
    'Same movement, each arm works alone',
  ]),
  _Alt('Weighted push-up', 'Floor, plate', '20 kg plate', 85, <String>[
    'No equipment queue',
    'Shoulder blades move freely',
    'Higher reps',
  ]),
  _Alt('Machine chest press', 'Machine', '65 kg', 90, <String>[
    'Usually free',
    'Fixed path, easy on shoulders',
    'Safe to push to the limit',
  ]),
  _Alt('Floor press', 'Barbell, floor', '70 kg', 80, <String>[
    'No bench needed',
    'Short range, kind to shoulders',
    'Builds the top half',
  ]),
];
// Best order for each reason.
const List<List<int>> _rank = <List<int>>[
  <int>[1, 3, 2, 0],
  <int>[2, 3, 0, 1],
  <int>[0, 2, 1, 3],
];

/// Room 48. Swapping an exercise mid-workout: say why, pick from a ranked
/// short list, keep your sets, and decide afterwards whether it is for
/// today or for good.
class SwapRoom extends StatefulWidget {
  const SwapRoom({super.key});

  @override
  State<SwapRoom> createState() => _SwapRoomState();
}

class _SwapRoomState extends State<SwapRoom> with TickerProviderStateMixin {
  _Alt _shown = _original, _next = _original;
  int _reason = 0;
  bool _asked = false; // the "today or always" question is showing
  String? _scope;
  late final SpringValue _sheet = SpringValue(this, spring: Motions.spatial);
  late final SpringValue _flip = SpringValue(this, spring: Motions.expressive);
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    _sheet.dispose();
    _flip.dispose();
    super.dispose();
  }

  void _pick(_Alt a) {
    _sheet.animateTo(0);
    Haptics.settle();
    setState(() {
      _next = a;
      _asked = a != _original;
      _scope = null;
    });
    // The card turns over: old face out, new face in.
    _flip.jumpTo(0);
    _flip.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Size screen = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              safe.top + 44,
              16,
              safe.bottom + 40,
            ),
            children: <Widget>[
              const RoomHeader(
                number: 48,
                title: 'Swap',
                hint: 'Pattern: the rack is taken, or a shoulder complains. One tap, a short ranked list, and the sets carry over.',
              ),
              const SizedBox(height: 18),
              ListenableBuilder(
                listenable: _flip,
                builder: (BuildContext context, Widget? _) {
                  final double t = _flip.value.clamp(0.0, 1.0);
                  final bool second = t > 0.5 || _next == _shown;
                  if (t >= 1 && _shown != _next) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => setState(() => _shown = _next),
                    );
                  }
                  final _Alt a = second ? _next : _shown;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateX(
                        _next == _shown ? 0 : (t < 0.5 ? t : t - 1) * math.pi,
                      ),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: ShapeDecoration(
                        color: c.surfaceHigh,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(28),
                          side: BorderSide(color: c.hairline),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'EXERCISE 2 OF 5',
                                      style: LumenType.label(color: c.accent),
                                    ),
                                    Text(
                                      a.name,
                                      style: LumenType.display(
                                        28,
                                        weight: 720,
                                        color: c.ink,
                                        height: 1.1,
                                      ),
                                    ),
                                    Text(
                                      a.gear,
                                      style: LumenType.text(
                                        13.5,
                                        color: c.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Pressable(
                                onTap: () {
                                  _sheet.animateTo(1);
                                  Haptics.tick();
                                },
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: ShapeDecoration(
                                    color: c.accent.withValues(alpha: 0.16),
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        Icons.swap_horiz_rounded,
                                        size: 20,
                                        color: c.accent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Swap',
                                        style: LumenType.text(
                                          14.5,
                                          weight: 680,
                                          color: c.accent,
                                          height: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          for (int i = 0; i < 3; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: <Widget>[
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '${i + 1}',
                                      style: LumenType.text(
                                        15,
                                        weight: 700,
                                        color: c.inkMuted,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${a.load}  ×  8',
                                    style: LumenType.text(
                                      16,
                                      weight: 620,
                                      color: c.ink,
                                    ),
                                  ),
                                  if (a != _original && i == 0) ...<Widget>[
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: ShapeDecoration(
                                        color: c.ink.withValues(alpha: 0.08),
                                        shape: const StadiumBorder(),
                                      ),
                                      child: Text(
                                        'weight adjusted',
                                        style: LumenType.text(
                                          11.5,
                                          weight: 600,
                                          color: c.inkMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // Asked after the swap, when the answer is known, never before it.
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !_asked
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                        decoration: ShapeDecoration(
                          color: c.ink.withValues(alpha: 0.055),
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: _scope != null
                            ? Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF2FA84F),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _scope == 'today'
                                          ? 'Swapped for today only'
                                          : 'Your routine now uses ${_next.name}',
                                      style: LumenType.text(
                                        14.5,
                                        weight: 600,
                                        color: c.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Swapped. Keep it this way?',
                                    style: LumenType.text(
                                      14.5,
                                      weight: 620,
                                      color: c.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: <Widget>[
                                      for (final (String label, String v)
                                          in const <(String, String)>[
                                            ('Just today', 'today'),
                                            ('Every time', 'always'),
                                          ])
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Pressable(
                                            onTap: () {
                                              setState(() => _scope = v);
                                              Haptics.settle();
                                              _hide?.cancel();
                                              _hide = Timer(
                                                const Duration(seconds: 3),
                                                () {
                                                  if (mounted) {
                                                    setState(
                                                      () => _asked = false,
                                                    );
                                                  }
                                                },
                                              );
                                            },
                                            child: Container(
                                              height: 44,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              alignment: Alignment.center,
                                              decoration: ShapeDecoration(
                                                color: v == 'today'
                                                    ? c.accent
                                                    : Colors.transparent,
                                                shape: StadiumBorder(
                                                  side: BorderSide(
                                                    color: v == 'today'
                                                        ? c.accent
                                                        : c.inkFaint,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                label,
                                                style: LumenType.text(
                                                  14,
                                                  weight: 680,
                                                  color: v == 'today'
                                                      ? c.onAccent
                                                      : c.ink,
                                                  height: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      const Spacer(),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _pick(_original),
                                        child: SizedBox(
                                          height: 44,
                                          child: Center(
                                            child: Text(
                                              'Undo',
                                              style: LumenType.text(
                                                14.5,
                                                weight: 700,
                                                color: c.accent,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                ],
                              ),
                      ),
              ),
            ],
          ),
          // Scrim and sheet.
          ListenableBuilder(
            listenable: _sheet,
            builder: (BuildContext context, Widget? child) {
              final double t = _sheet.value;
              return IgnorePointer(
                ignoring: t < 0.5,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => _sheet.animateTo(0),
                        child: ColoredBox(
                          color: Colors.black.withValues(
                            alpha: 0.5 * t.clamp(0.0, 1.0),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -(1 - t) * (screen.height * 0.8) - 40,
                      child: child!,
                    ),
                  ],
                ),
              );
            },
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 10, 16, safe.bottom + 56),
                decoration: ShapeDecoration(
                  color: c.surface,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(34),
                    ),
                    side: BorderSide(color: c.hairline),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: ShapeDecoration(
                          color: c.inkFaint,
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Swap bench press',
                      style: LumenType.display(24, weight: 700, color: c.ink),
                    ),
                    const SizedBox(height: 10),
                    // The reason reorders the list, so the first answer is usually right.
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          for (final (int i, String r) in const <String>[
                            'Equipment busy',
                            'Discomfort',
                            'Variety',
                          ].indexed)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _reason = i);
                                  Haptics.tick();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: ShapeDecoration(
                                    color: _reason == i
                                        ? c.ink
                                        : Colors.transparent,
                                    shape: StadiumBorder(
                                      side: BorderSide(
                                        color: _reason == i
                                            ? c.ink
                                            : c.inkFaint,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    r,
                                    style: LumenType.text(
                                      13.5,
                                      weight: 650,
                                      color: _reason == i ? c.bg : c.ink,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final (int place, int i) in _rank[_reason].indexed)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Pressable(
                          key: ValueKey<int>(i * 10 + _reason),
                          scale: 0.98,
                          onTap: () => _pick(_alts[i]),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                            decoration: ShapeDecoration(
                              color: place == 0
                                  ? c.accent.withValues(alpha: 0.13)
                                  : c.ink.withValues(alpha: 0.05),
                              shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(22),
                                side: BorderSide(
                                  color: place == 0
                                      ? c.accent.withValues(alpha: 0.55)
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Flexible(
                                            child: Text(
                                              _alts[i].name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: LumenType.text(
                                                16,
                                                weight: 660,
                                                color: c.ink,
                                              ),
                                            ),
                                          ),
                                          if (place == 0) ...<Widget>[
                                            const SizedBox(width: 8),
                                            Text(
                                              'BEST FIT',
                                              style: LumenType.label(
                                                color: c.accent,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        _alts[i].why[_reason],
                                        style: LumenType.text(
                                          13.5,
                                          color: c.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Text(
                                      _alts[i].load,
                                      style: LumenType.text(
                                        14.5,
                                        weight: 680,
                                        color: c.ink,
                                      ),
                                    ),
                                    Text(
                                      '${_alts[i].match}% same muscles',
                                      style: LumenType.text(
                                        12,
                                        color: c.inkFaint,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: c.inkMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Search all exercises',
                              style: LumenType.text(
                                15,
                                weight: 600,
                                color: c.inkMuted,
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
          ),
        ],
      ),
    );
  }
}
