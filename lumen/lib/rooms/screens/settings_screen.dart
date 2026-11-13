import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/settings.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/pressable.dart';
import '../../widgets/tag.dart';
import '../patterns/inputs_room.dart';

/// Room 30. A complete settings screen: who you are at the top, rows in
/// small groups, controls that work in place, and the one dangerous action
/// set apart at the bottom behind a hold.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  double _rest = 90;
  String _units = 'kg';
  bool _reminders = true;

  // Back up: 0 idle, 0..1 running, 2 done.
  final ValueNotifier<double> _backup = ValueNotifier<double>(0);
  late final Ticker _backupTicker = createTicker((Duration e) {
    final double t = e.inMilliseconds / 1800;
    if (t >= 1) {
      _backupTicker.stop();
      _backup.value = 2;
      Haptics.settle();
    } else {
      _backup.value = t.clamp(0.001, 0.999);
    }
  });

  // Erase: fills while held; letting go early drains it back.
  late final SpringValue _hold = SpringValue(this, spring: Motions.spatialFast);
  final ValueNotifier<double> _held = ValueNotifier<double>(0);
  late final Ticker _holdTicker = createTicker(_onHold);
  int _lastTick = 0;
  bool _erased = false;
  Timer? _undo;

  void _onHold(Duration e) {
    final double t = e.inMilliseconds / 1600;
    _held.value = t.clamp(0.0, 1.0);
    final int step = (t * 8).floor();
    if (step != _lastTick && t < 1) {
      _lastTick = step;
      Haptics.tick();
    }
    if (t >= 1) {
      _holdTicker.stop();
      Haptics.thud();
      setState(() => _erased = true);
      _undo?.cancel();
      _undo = Timer(const Duration(seconds: 6), () {
        if (mounted) {
          setState(() => _erased = false);
          _held.value = 0;
        }
      });
    }
  }

  void _holdStart() {
    if (_erased) {
      return;
    }
    _lastTick = 0;
    _hold.jumpTo(0);
    _holdTicker
      ..stop()
      ..start();
  }

  void _holdEnd() {
    if (_erased || !_holdTicker.isActive) {
      return;
    }
    _holdTicker.stop();
    // Drain back with a spring from wherever it got to.
    _hold.jumpTo(_held.value);
    _held.value = 0;
    _hold.animateTo(0);
  }

  @override
  void dispose() {
    _undo?.cancel();
    _backupTicker.dispose();
    _holdTicker.dispose();
    _backup.dispose();
    _held.dispose();
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    const Color danger = Color(0xFFE5484D);

    Widget group(List<Widget> rows) => Container(
      decoration: ShapeDecoration(
        color: c.ink.withValues(alpha: 0.055),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Container(
                  height: 1,
                  color: c.ink.withValues(alpha: 0.07),
                ),
              ),
            rows[i],
          ],
        ],
      ),
    );

    Widget row(
      IconData icon,
      Color tint,
      String title, {
      String? detail,
      Widget? trailing,
      VoidCallback? onTap,
    }) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: ShapeDecoration(
                  color: tint.withValues(alpha: 0.18),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: Icon(icon, size: 19, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: LumenType.text(15.5, weight: 580, color: c.ink),
                    ),
                    if (detail != null)
                      Text(
                        detail,
                        style: LumenType.text(
                          13,
                          color: c.inkMuted,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: c.inkFaint,
                  ),
            ],
          ),
        ),
      ),
    );

    Widget label(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 26, 14, 10),
      child: Text(t.toUpperCase(), style: LumenType.label(color: c.inkMuted)),
    );

    return Scaffold(
      backgroundColor: c.bg,
      body: ListenableBuilder(
        listenable: settings,
        builder: (BuildContext context, Widget? _) => ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 48),
          children: <Widget>[
            const ScreenBar(number: 30),
            const SizedBox(height: 22),
            Tag(
              'R30.1',
              'Profile header',
              child: Row(
                children: <Widget>[
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          c.accent,
                          Color.lerp(c.accent, const Color(0xFFFF6B4A), 0.6)!,
                        ],
                      ),
                      shape: const CircleBorder(),
                    ),
                    child: Text(
                      'MK',
                      style: LumenType.display(
                        24,
                        weight: 700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Mila Kovač',
                          style: LumenType.display(
                            24,
                            weight: 680,
                            color: c.ink,
                          ),
                        ),
                        Text(
                          'Training since March  ·  142 sessions',
                          style: LumenType.text(13.5, color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.inkFaint),
                ],
              ),
            ),
            label('Training'),
            Tag(
              'R30.2',
              'Controls that work in the row',
              child: group(<Widget>[
                row(
                  Icons.timer_outlined,
                  const Color(0xFF4FB8FF),
                  'Rest between sets',
                  trailing: SizedBox(
                    width: 132,
                    child: DragDial(
                      value: _rest,
                      step: 5,
                      fineStep: 1,
                      min: 10,
                      max: 300,
                      unit: 's',
                      onChanged: (double v) => setState(() => _rest = v),
                    ),
                  ),
                ),
                row(
                  Icons.straighten_rounded,
                  const Color(0xFF8E7CFF),
                  'Units',
                  trailing: SizedBox(
                    width: 132,
                    child: Segmented<String>(
                      values: const <String>['kg', 'lb'],
                      labels: const <String>['kg', 'lb'],
                      value: _units,
                      onChanged: (String v) => setState(() => _units = v),
                    ),
                  ),
                ),
                row(
                  Icons.notifications_none_rounded,
                  const Color(0xFFF5B301),
                  'Reminders',
                  detail: _reminders ? 'Mon, Wed, Fri at 18:00' : 'Off',
                  trailing: LumenSwitch(
                    value: _reminders,
                    onChanged: (bool v) => setState(() => _reminders = v),
                  ),
                  onTap: () => setState(() => _reminders = !_reminders),
                ),
              ]),
            ),
            label('Feel'),
            Tag(
              'R30.3',
              'Live switches',
              child: group(<Widget>[
                row(
                  Icons.vibration_rounded,
                  const Color(0xFF2ED3B7),
                  'Haptics',
                  detail: 'Real: turns vibration off across Lumen',
                  trailing: LumenSwitch(
                    value: settings.haptics,
                    onChanged: (bool v) => settings.haptics = v,
                  ),
                  onTap: () => settings.haptics = !settings.haptics,
                ),
                row(
                  Icons.motion_photos_off_outlined,
                  const Color(0xFFFF6B4A),
                  'Reduce motion',
                  detail: 'Real: springs become short fades',
                  trailing: LumenSwitch(
                    value: settings.reduceMotion,
                    onChanged: (bool v) => settings.reduceMotion = v,
                  ),
                  onTap: () => settings.reduceMotion = !settings.reduceMotion,
                ),
              ]),
            ),
            label('Your data'),
            Tag(
              'R30.4',
              'Progress inside the row',
              child: group(<Widget>[
                ValueListenableBuilder<double>(
                  valueListenable: _backup,
                  builder: (BuildContext context, double b, Widget? _) => row(
                    Icons.cloud_upload_outlined,
                    const Color(0xFF4FB8FF),
                    'Back up now',
                    detail: b == 2
                        ? 'Backed up just now'
                        : (b > 0
                              ? 'Backing up… ${(b * 100).round()}%'
                              : 'Last backup yesterday, 21:14'),
                    trailing: SizedBox.square(
                      dimension: 26,
                      child: b == 2
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF2FA84F),
                              size: 26,
                            )
                          : (b > 0
                                ? CircularProgressIndicator(
                                    value: b,
                                    strokeWidth: 3,
                                    color: c.accent,
                                    backgroundColor: c.ink.withValues(
                                      alpha: 0.1,
                                    ),
                                  )
                                : Icon(
                                    Icons.chevron_right_rounded,
                                    size: 22,
                                    color: c.inkFaint,
                                  )),
                    ),
                    onTap: () {
                      if (!_backupTicker.isActive) {
                        Haptics.tick();
                        _backupTicker.start();
                      }
                    },
                  ),
                ),
                row(
                  Icons.ios_share_rounded,
                  const Color(0xFF8E7CFF),
                  'Export as a file',
                  detail: 'Everything, readable in a spreadsheet',
                ),
              ]),
            ),
            label('Danger zone'),
            Tag(
              'R30.5',
              'Hold to erase, with undo',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    _erased
                        ? 'Erased. You have a few seconds to take it back.'
                        : 'Erases 142 sessions from this phone. A tap does nothing: hold the button until it fills.',
                    style: LumenType.text(14, color: c.inkMuted, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  if (_erased)
                    Pressable(
                      onTap: () {
                        _undo?.cancel();
                        _held.value = 0;
                        setState(() => _erased = false);
                        Haptics.settle();
                      },
                      child: Container(
                        height: 56,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: c.ink.withValues(alpha: 0.08),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Undo',
                          style: LumenType.text(
                            16,
                            weight: 680,
                            color: c.ink,
                            height: 1,
                          ),
                        ),
                      ),
                    )
                  else
                    Listener(
                      onPointerDown: (_) => _holdStart(),
                      onPointerUp: (_) => _holdEnd(),
                      onPointerCancel: (_) => _holdEnd(),
                      child: GestureDetector(
                        onVerticalDragUpdate: (_) {},
                        onHorizontalDragUpdate: (_) {},
                        child: ListenableBuilder(
                          listenable: Listenable.merge(<Listenable>[
                            _held,
                            _hold,
                          ]),
                          builder: (BuildContext context, Widget? _) {
                            final double v =
                                (_holdTicker.isActive
                                        ? _held.value
                                        : _hold.value)
                                    .clamp(0.0, 1.0);
                            return Transform.scale(
                              scale: 1 - 0.03 * (v > 0 ? 1 : 0),
                              child: Container(
                                height: 56,
                                clipBehavior: Clip.antiAlias,
                                decoration: ShapeDecoration(
                                  color: danger.withValues(alpha: 0.14),
                                  shape: StadiumBorder(
                                    side: BorderSide(
                                      color: danger.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: <Widget>[
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: v,
                                        heightFactor: 1,
                                        child: const ColoredBox(color: danger),
                                      ),
                                    ),
                                    Text(
                                      v > 0.02
                                          ? 'Keep holding…'
                                          : 'Hold to erase everything',
                                      style: LumenType.text(
                                        16,
                                        weight: 680,
                                        color: v > 0.02 ? Colors.white : danger,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
