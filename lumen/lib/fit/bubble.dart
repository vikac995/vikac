import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The workout, floating over other apps: a small glass lens with the timer, which opens
/// into a panel for logging the set. It appears when Prism leaves the screen during a workout. It is drawn by Android itself,
/// not by Flutter, so it costs nothing in Prism and works over any app.
class RestBubble with WidgetsBindingObserver {
  RestBubble._();
  static final RestBubble instance = RestBubble._();
  static const MethodChannel _device = MethodChannel('lumen/device');

  /// Whether Android has been told Prism may appear on top of other apps.
  final ValueNotifier<bool> allowed = ValueNotifier<bool>(false);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    try {
      countUp.value = _modeFile.readAsStringSync().trim() == 'up';
    } catch (_) {
      // Never chosen: a countdown.
    }
    refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh(); // The person may just have come back from granting it.
    }
  }

  Future<void> refresh() async {
    try {
      allowed.value =
          await _device.invokeMethod<bool>('overlayAllowed') ?? false;
    } catch (_) {
      // Not on Android.
    }
  }

  /// Opens Android's own screen for the permission. Only the person can grant it.
  Future<void> ask() async {
    try {
      await _device.invokeMethod<void>('askOverlay');
    } catch (_) {
      // Not on Android.
    }
  }

  /// Whether the rest timer counts up from zero (true) or down to zero (false).
  /// Switched by tapping the timer, here or in the floating sheet, and remembered.
  final ValueNotifier<bool> countUp = ValueNotifier<bool>(false);

  File get _modeFile {
    final Directory files = Directory(
      '${Directory.systemTemp.parent.path}/files',
    );
    return File(
      '${files.existsSync() ? files.path : Directory.systemTemp.path}/prism_timer_mode',
    );
  }

  void toggleMode() {
    countUp.value = !countUp.value;
    try {
      _modeFile.writeAsStringSync(countUp.value ? 'up' : 'down');
    } catch (_) {
      // Not saved: it starts as a countdown next time.
    }
  }

  /// What the floating sheet asks for. Set by the workout page.
  void Function(int set)? onToggle;
  void Function(int set, double kg, int reps)? onValue;
  void Function(bool add)? onRest;

  /// A call from Android. True if it was for the floating workout.
  bool handle(MethodCall call) {
    switch (call.method) {
      case 'toggle':
        onToggle?.call((call.arguments as num).toInt());
      case 'setValue':
        final Map<Object?, Object?> a = call.arguments as Map<Object?, Object?>;
        onValue?.call(
          (a['i']! as num).toInt(),
          (a['kg']! as num).toDouble(),
          (a['reps']! as num).toInt(),
        );
      case 'restAdd':
        onRest?.call(true);
      case 'restSkip':
        onRest?.call(false);
      case 'timerMode':
        toggleMode();
      default:
        return false;
    }
    return true;
  }

  /// Tells Android everything the floating workout shows, or null when no workout is on.
  void tell(Map<String, Object>? state) {
    _device.invokeMethod<void>('rest', state).catchError((Object _) {});
  }

  /// Tells Android whether Prism's own workout page is showing. The lens stays away from it:
  /// that page is the thing the lens stands for.
  void page(bool train) {
    _device.invokeMethod<void>('page', train).catchError((Object _) {});
  }
}
