import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The rest timer as a small round countdown that floats over other apps.
/// It appears when Prism leaves the screen while a rest is running, and a tap
/// on it brings Prism back on the workout page. It is drawn by Android itself,
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

  /// Tells Android when the running rest ends, or that there is none.
  void tell(DateTime? ends, int totalSeconds, Color accent, Color onAccent) {
    _device
        .invokeMethod<void>(
          'rest',
          ends == null
              ? null
              : <String, Object>{
                  'endsAt': ends.millisecondsSinceEpoch,
                  'total': totalSeconds,
                  'accent': accent.toARGB32(),
                  'onAccent': onAccent.toARGB32(),
                },
        )
        .catchError((Object _) {});
  }
}
