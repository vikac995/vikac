import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/panel.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';

/// Room 37. Ways an app speaks up, from quietest to loudest: a badge, a
/// message at the bottom with Undo, a banner from the top, a stack of
/// notifications, and asking for permission politely.
class NotifyRoom extends StatefulWidget {
  const NotifyRoom({super.key});

  @override
  State<NotifyRoom> createState() => _NotifyRoomState();
}

class _NotifyRoomState extends State<NotifyRoom> with TickerProviderStateMixin {
  // Badge
  int _unread = 2;
  late final SpringValue _badge = SpringValue(
    this,
    value: 1,
    spring: Motions.expressiveFast,
  );

  // Bottom message with undo
  bool _archived = false;
  late final SpringValue _snack = SpringValue(this, spring: Motions.spatial);
  final ValueNotifier<double> _snackLeft = ValueNotifier<double>(1);
  late final Ticker _snackTicker = createTicker((Duration e) {
    _snackLeft.value = (1 - e.inMilliseconds / 4000).clamp(0.0, 1.0);
    if (_snackLeft.value == 0) {
      _snackTicker.stop();
      _snack.animateTo(0);
    }
  });

  // Banner
  late final SpringValue _banner = SpringValue(
    this,
    spring: Motions.expressive,
  );
  Timer? _bannerTimer;
  double _bannerDrag = 0;

  // Stack
  bool _open = false;
  late final SpringValue _stack = SpringValue(this, spring: Motions.expressive);

  // Permission
  int _perm = 0; // 0 ask, 1 on, 2 later

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _snackTicker.dispose();
    _snackLeft.dispose();
    for (final SpringValue s in <SpringValue>[
      _badge,
      _snack,
      _banner,
      _stack,
    ]) {
      s.dispose();
    }
    super.dispose();
  }

  void _archive() {
    setState(() => _archived = true);
    Haptics.settle();
    _snack.animateTo(1);
    _snackTicker
      ..stop()
      ..start();
  }

  void _undo() {
    _snackTicker.stop();
    _snack.animateTo(0);
    setState(() => _archived = false);
    Haptics.tick();
  }

  void _showBanner() {
    _bannerDrag = 0;
    _banner.animateTo(1);
    Haptics.settle();
    _bannerTimer?.cancel();
    _bannerTimer = Timer(
      const Duration(seconds: 4),
      () => _banner.animateTo(0, spring: Motions.spatial),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    Widget action(String label, VoidCallback onTap) => Pressable(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: c.accent.withValues(alpha: 0.16),
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: LumenType.text(15, weight: 650, color: c.accent, height: 1),
        ),
      ),
    );
    Widget note(IconData icon, String title, String body, String time) =>
        Container(
          padding: const EdgeInsets.all(14),
          decoration: ShapeDecoration(
            color: c.surfaceHigh,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: c.hairline),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: ShapeDecoration(
                  color: c.accent.withValues(alpha: 0.16),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Icon(icon, size: 19, color: c.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LumenType.text(14.5, weight: 650, color: c.ink),
                    ),
                    Text(
                      body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LumenType.text(13.5, color: c.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(time, style: LumenType.text(12, color: c.inkFaint)),
            ],
          ),
        );

    return Stack(
      children: <Widget>[
        RoomScaffold(
          children: <Widget>[
            const RoomHeader(
              number: 37,
              title: 'Notifications',
              hint: 'Pattern: speak as quietly as the news allows. Five volumes, quietest first.',
            ),
            const SectionLabel(
              '1  Badge',
              detail: 'A count on the place the news lives. No interruption.',
            ),
            Panel(
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      Icon(Icons.home_rounded, color: c.inkMuted, size: 28),
                      Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Icon(Icons.forum_rounded, color: c.ink, size: 28),
                          if (_unread > 0)
                            Positioned(
                              right: -10,
                              top: -7,
                              child: ListenableBuilder(
                                listenable: _badge,
                                builder:
                                    (BuildContext context, Widget? child) =>
                                        Transform.scale(
                                          scale: _badge.value,
                                          child: child,
                                        ),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                  ),
                                  height: 20,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: const ShapeDecoration(
                                    color: Color(0xFFE5484D),
                                    shape: StadiumBorder(),
                                  ),
                                  child: Text(
                                    _unread > 9 ? '9+' : '$_unread',
                                    textScaler: TextScaler.noScaling,
                                    style: LumenType.text(
                                      11.5,
                                      weight: 720,
                                      color: Colors.white,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Icon(Icons.person_rounded, color: c.inkMuted, size: 28),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: action('New message', () {
                          setState(() => _unread++);
                          _badge.jumpTo(1.5);
                          _badge.animateTo(1);
                          Haptics.tick();
                        }),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: action(
                          'Read all',
                          () => setState(() => _unread = 0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SectionLabel(
              '2  Message with Undo',
              detail: 'Confirms what just happened and lets you take it back. Leaves by itself.',
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _archived
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Archived. The message is at the bottom of the screen.',
                        style: LumenType.text(14, color: c.inkMuted),
                      ),
                    )
                  : Column(
                      children: <Widget>[
                        note(
                          Icons.fitness_center_rounded,
                          'Tuesday, legs',
                          '52 min  ·  6 exercises',
                          'Tue',
                        ),
                        const SizedBox(height: 10),
                        action('Archive this session', _archive),
                      ],
                    ),
            ),
            const SectionLabel(
              '3  Banner',
              detail: 'News from elsewhere in the app. Swipe it up to dismiss, or wait four seconds.',
            ),
            action('Show a banner', _showBanner),
            const SectionLabel(
              '4  Stack',
              detail: 'Several from one source fold into one. Tap to open.',
            ),
            GestureDetector(
              onTap: () {
                setState(() => _open = !_open);
                _stack.animateTo(_open ? 1 : 0);
                Haptics.tick();
              },
              child: ListenableBuilder(
                listenable: _stack,
                builder: (BuildContext context, Widget? _) {
                  final double t = _stack.value;
                  const double h = 68;
                  return SizedBox(
                    height: h + 16 + t * (2 * (h + 8) - 16),
                    child: Stack(
                      children: <Widget>[
                        for (int i = 2; i >= 0; i--)
                          Positioned(
                            left: (1 - t.clamp(0.0, 1.0)) * i * 10,
                            right: (1 - t.clamp(0.0, 1.0)) * i * 10,
                            top: i * (8 + t * h),
                            height: h,
                            child: Opacity(
                              opacity: i == 0
                                  ? 1
                                  : (0.55 + 0.45 * t).clamp(0.0, 1.0),
                              child: note(
                                <IconData>[
                                  Icons.emoji_events_rounded,
                                  Icons.timer_outlined,
                                  Icons.group_rounded,
                                ][i],
                                <String>[
                                  'New personal best',
                                  'Rest is over',
                                  'Ana finished her session',
                                ][i],
                                <String>[
                                  'Deadlift, 125 kg',
                                  'Set 3 of 4 is waiting',
                                  'Push day, 48 min',
                                ][i],
                                <String>['now', '2 m', '9 m'][i],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SectionLabel(
              '5  Asking permission',
              detail: 'Explain the value in your own words first. The system dialog can only be shown once.',
            ),
            Panel(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _perm == 0
                    ? Column(
                        key: const ValueKey<int>(0),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 34,
                            color: c.accent,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Know when rest is over',
                            textAlign: TextAlign.center,
                            style: LumenType.display(
                              22,
                              weight: 680,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'One buzz when your rest timer ends, even with the phone locked. Nothing else.',
                            textAlign: TextAlign.center,
                            style: LumenType.text(
                              14,
                              color: c.inkMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Pressable(
                            onTap: () {
                              setState(() => _perm = 1);
                              Haptics.settle();
                            },
                            child: Container(
                              height: 50,
                              alignment: Alignment.center,
                              decoration: ShapeDecoration(
                                color: c.accent,
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                'Turn on',
                                style: LumenType.text(
                                  15.5,
                                  weight: 680,
                                  color: c.onAccent,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _perm = 2),
                            child: SizedBox(
                              height: 48,
                              child: Center(
                                child: Text(
                                  'Not now',
                                  style: LumenType.text(
                                    15,
                                    weight: 600,
                                    color: c.inkMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : GestureDetector(
                        key: ValueKey<int>(_perm),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _perm = 0),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              _perm == 1
                                  ? Icons.check_circle_rounded
                                  : Icons.schedule_rounded,
                              color: _perm == 1
                                  ? const Color(0xFF2FA84F)
                                  : c.inkMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _perm == 1
                                    ? 'On. Here the system dialog would appear, once.'
                                    : 'Fine. Ask again later, in context, not on every launch.',
                                style: LumenType.text(
                                  14.5,
                                  color: c.ink,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            Text(
                              'Reset',
                              style: LumenType.text(
                                13.5,
                                weight: 650,
                                color: c.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 70),
          ],
        ),
        // Banner, from the top.
        Positioned(
          left: 12,
          right: 12,
          top: safe.top + 40,
          child: ListenableBuilder(
            listenable: _banner,
            builder: (BuildContext context, Widget? child) {
              final double t = _banner.value;
              return IgnorePointer(
                ignoring: t < 0.5,
                child: Transform.translate(
                  offset: Offset(0, (t - 1) * 140 + _bannerDrag),
                  child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                ),
              );
            },
            child: GestureDetector(
              onVerticalDragUpdate: (DragUpdateDetails d) => setState(
                () => _bannerDrag = (_bannerDrag + d.delta.dy).clamp(
                  -200.0,
                  12.0,
                ),
              ),
              onVerticalDragEnd: (_) {
                if (_bannerDrag < -24) {
                  _bannerTimer?.cancel();
                  _banner.animateTo(0, spring: Motions.spatialFast);
                } else {
                  setState(() => _bannerDrag = 0);
                }
              },
              child: Material(
                type: MaterialType.transparency,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: c.shadow,
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: note(
                    Icons.cloud_done_outlined,
                    'Backup finished',
                    '142 sessions are safe',
                    'now',
                  ),
                ),
              ),
            ),
          ),
        ),
        // Message with undo, from the bottom.
        Positioned(
          left: 16,
          right: 16,
          bottom: safe.bottom + 18,
          child: ListenableBuilder(
            listenable: _snack,
            builder: (BuildContext context, Widget? child) => IgnorePointer(
              ignoring: _snack.value < 0.5,
              child: Transform.translate(
                offset: Offset(0, (1 - _snack.value) * 110),
                child: Opacity(
                  opacity: _snack.value.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                height: 56,
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: c.dark
                      ? const Color(0xFFF3F0EA)
                      : const Color(0xFF1B1D23),
                  shape: const StadiumBorder(),
                  shadows: <BoxShadow>[
                    BoxShadow(
                      color: c.shadow,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: <Widget>[
                    // The time left to undo, drawn as the bar draining.
                    ValueListenableBuilder<double>(
                      valueListenable: _snackLeft,
                      builder: (BuildContext context, double v, Widget? _) =>
                          FractionallySizedBox(
                            widthFactor: v,
                            heightFactor: 1,
                            child: ColoredBox(
                              color: c.accent.withValues(alpha: 0.22),
                            ),
                          ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 22, right: 6),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Session archived',
                              style: LumenType.text(
                                15,
                                weight: 600,
                                color: c.dark
                                    ? const Color(0xFF16171B)
                                    : Colors.white,
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _undo,
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Undo',
                                style: LumenType.text(
                                  15,
                                  weight: 720,
                                  color: c.dark
                                      ? const Color(0xFFD9431F)
                                      : const Color(0xFFFF8A6B),
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
            ),
          ),
        ),
      ],
    );
  }
}
