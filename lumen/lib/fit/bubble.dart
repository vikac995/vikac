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

  /// Called when a set is logged from the floating panel, with the weight and reps chosen there.
  void Function(double kg, int reps)? onLog;

  /// Tells Android everything the floating workout shows, or null when no workout is on.
  void tell(Map<String, Object>? state) {
    _device.invokeMethod<void>('rest', state).catchError((Object _) {});
  }
}
