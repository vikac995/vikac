import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/haptics.dart';
import '../core/theme.dart';
import '../widgets/pressable.dart';
import 'common.dart';
import 'lens.dart';

/// Today's screen time, as Android itself keeps it: how long the screen was in use since
/// midnight, on which apps, and how many times the phone was unlocked. Read only when Home is
/// shown, at most once a minute: nothing runs in the background, and nothing is kept.
class ScreenTime extends ChangeNotifier {
  ScreenTime._();
  static final ScreenTime instance = ScreenTime._();
  static const MethodChannel _device = MethodChannel('lumen/device');

  /// Whether the person has given Prism usage access, and whether that is known yet.
  bool allowed = false, known = false;
  int totalMs = 0, unlocks = 0;
  List<(String, int)> top = <(String, int)>[];
  DateTime? _at;

  Future<void> refresh({bool force = false}) async {
    final DateTime now = DateTime.now();
    if (!force && _at != null && now.difference(_at!).inSeconds < 60) {
      return;
    }
    _at = now;
    if (!Platform.isAndroid) {
      // Off the phone there is nothing to read: made-up figures stand in, to look at.
      allowed = known = true;
      totalMs = (3 * 60 + 12) * 60000;
      unlocks = 41;
      top = <(String, int)>[
        ('Chat', 52 * 60000),
        ('Video', 38 * 60000),
        ('Maps', 21 * 60000),
      ];
      notifyListeners();
      return;
    }
    try {
      allowed = await _device.invokeMethod<bool>('usageAllowed') ?? false;
      if (allowed) {
        final Map<Object?, Object?>? m = await _device
            .invokeMethod<Map<Object?, Object?>>('screenTime');
        if (m != null) {
          totalMs = (m['total'] as num?)?.toInt() ?? 0;
          unlocks = (m['unlocks'] as num?)?.toInt() ?? 0;
          top = <(String, int)>[
            for (final Object? o in (m['top'] as List<Object?>? ?? <Object?>[]))
              (
                (o! as Map<Object?, Object?>)['label']! as String,
                ((o as Map<Object?, Object?>)['ms']! as num).toInt(),
              ),
          ];
        }
      }
    } catch (_) {
      allowed = false;
    }
    known = true;
    notifyListeners();
  }

  /// Opens Android's screen where usage access is given. Only the person can give it.
  Future<void> ask() async {
    try {
      await _device.invokeMethod<void>('askUsage');
    } catch (_) {
      // Not on Android.
    }
  }

  static String time(int ms) {
    final int mins = (ms / 60000).round();
    if (mins < 60) {
      return '$mins min';
    }
    return '${mins ~/ 60} h ${mins % 60} min';
  }
}

/// The screen-time card on Home.
class ScreenTimeCard extends StatefulWidget {
  const ScreenTimeCard({super.key});

  @override
  State<ScreenTimeCard> createState() => _ScreenTimeCardState();
}

class _ScreenTimeCardState extends State<ScreenTimeCard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ScreenTime.instance.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back on Home: perhaps from giving usage access, perhaps after time in other apps.
    if (state == AppLifecycleState.resumed) {
      ScreenTime.instance.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return LensTarget(
      page: 'home',
      title: 'Screen time',
      explain: 'How long the screen was in use today, and on what, as Android keeps it.',
      color: const Color(0xFF3E6FB0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: card(c),
        child: ListenableBuilder(
          listenable: ScreenTime.instance,
          builder: (BuildContext context, Widget? _) {
            final ScreenTime s = ScreenTime.instance;
            final List<Widget> rows = <Widget>[
              Text('SCREEN TIME', style: LumenType.label(color: c.inkMuted)),
              const SizedBox(height: 10),
            ];
            if (!s.known) {
              rows.add(const SizedBox(height: 40));
            } else if (!s.allowed) {
              rows.addAll(<Widget>[
                Text(
                  'Allow usage access, and today\'s screen time shows here. Android asks for it on a screen of its own.',
                  style: LumenType.text(14.5, color: c.ink, height: 1.35),
                ),
                const SizedBox(height: 12),
                Pressable(
                  onTap: () {
                    Haptics.tick();
                    s.ask();
                  },
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: c.ink.withValues(alpha: 0.08),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      'Allow usage access',
                      style: LumenType.text(
                        15,
                        weight: 700,
                        color: c.ink,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ]);
            } else {
              final int most = s.top.isEmpty ? 1 : s.top.first.$2;
              rows.addAll(<Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      ScreenTime.time(s.totalMs),
                      style: LumenType.display(30, weight: 700, color: c.ink),
                    ),
                    const Spacer(),
                    Text(
                      '${s.unlocks} unlocks',
                      style: LumenType.text(
                        13.5,
                        weight: 600,
                        color: c.inkMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final (String name, int ms) in s.top.take(3)) ...<Widget>[
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 96,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LumenType.text(14, weight: 600, color: c.ink),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: (ms / most).clamp(0.04, 1.0),
                            child: Container(
                              height: 6,
                              decoration: ShapeDecoration(
                                color: c.accent.withValues(alpha: 0.85),
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        ScreenTime.time(ms),
                        style: LumenType.text(13, color: c.inkMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ]);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            );
          },
        ),
      ),
    );
  }
}
