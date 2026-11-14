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
      final String pin = _pinFile.readAsStringSync().trim();
      pinned.value = pin.isEmpty ? null : pin;
    } catch (_) {
      // Nothing pinned.
    }
    try {
      countUp.value = _modeFile.readAsStringSync().trim() == 'up';
    } catch (_) {
      // Never chosen: a countdown.
    }
    try {
      container.value = _styleFile.readAsStringSync().trim() != 'classic';
    } catch (_) {
      // Never chosen: the container.
    }
    refresh();
  }

  /// Called when the phone changes between light and dark, for a theme that follows it.
  VoidCallback? onTheme;

  @override
  void didChangePlatformBrightness() => onTheme?.call();

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
      seesApps.value =
          await _device.invokeMethod<bool>('usageAllowed') ?? false;
    } catch (_) {
      // Not on Android.
    }
  }

  /// Whether Android lets Prism see which app is in front. It is used for one thing: a pinned
  /// app's lens, which steps aside when it has opened its app, comes back when that app is left.
  final ValueNotifier<bool> seesApps = ValueNotifier<bool>(false);

  /// Opens Android's own screen for that. Only the person can grant it.
  Future<void> askUsage() async {
    try {
      await _device.invokeMethod<void>('askUsage');
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

  /// Which floating lens this is. True: a container, always the same glass button, that holds
  /// what was put in it, and opens the blob menu when held. False: the lens as it was before,
  /// which takes on the look of the thing pinned to it.
  final ValueNotifier<bool> container = ValueNotifier<bool>(true);

  File get _styleFile {
    final Directory files = Directory(
      '${Directory.systemTemp.parent.path}/files',
    );
    return File(
      '${files.existsSync() ? files.path : Directory.systemTemp.path}/prism_lens_style',
    );
  }

  void setContainer(bool v) {
    container.value = v;
    try {
      _styleFile.writeAsStringSync(v ? 'container' : 'classic');
    } catch (_) {
      // Not saved: it is the container next time.
    }
  }

  /// What is pinned from the blob menu to float over the phone: 'action:3', 'app:com.whatsapp', or null.
  final ValueNotifier<String?> pinned = ValueNotifier<String?>(null);

  File get _pinFile {
    final Directory files = Directory(
      '${Directory.systemTemp.parent.path}/files',
    );
    return File(
      '${files.existsSync() ? files.path : Directory.systemTemp.path}/prism_pin',
    );
  }

  void setPin(String? key) {
    pinned.value = key;
    try {
      _pinFile.writeAsStringSync(key ?? '');
    } catch (_) {
      // Not saved: nothing is pinned next time.
    }
  }

  /// Tells Android what is pinned (its name, colour and picture), or null for nothing.
  void tellPin(Map<String, Object>? pin) {
    _device.invokeMethod<void>('pin', pin).catchError((Object _) {});
  }

  /// Tells Android what the blobs in the menu are, so the floating lens can open the same menu.
  void tellBlobs(List<Map<String, Object>> blobs) {
    _device.invokeMethod<void>('blobs', blobs).catchError((Object _) {});
  }

  /// A blob has been shot out of Prism's button to become the floating lens. Android puts the
  /// lens in its place, unseen if it was not there already, and answers with where that is on
  /// the screen in real pixels (x, y of its corner, and its size), so the blob can land on it.
  /// Null if the lens cannot float here.
  Future<Map<Object?, Object?>?> land(Map<String, Object> blob) async {
    try {
      return await _device.invokeMethod<Map<Object?, Object?>>('land', blob);
    } catch (_) {
      return null; // Not on Android.
    }
  }

  /// The blob has landed: the lens shows itself, with the give of something just caught.
  void landed() {
    _device.invokeMethod<void>('landed').catchError((Object _) {});
  }

  /// The workout was stopped from the floating sheet. Set by the workout page.
  VoidCallback? onStop;

  /// A blob was put in the floating lens from its own menu (or taken out: null). Set by the shell.
  void Function(String? key)? onPinned;

  /// Tells Android the numbers the pinned sheets show.
  void tellData(Map<String, Object> data) {
    _device.invokeMethod<void>('pinData', data).catchError((Object _) {});
  }

  /// What a pinned sheet asks for. Set by the shell.
  void Function(double kg)? onWeigh;
  void Function(int meal)? onFood;
  void Function(int action)? onAction;

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
      case 'unpinned':
        setPin(null);
      case 'stop':
        onStop?.call();
      case 'pinned':
        onPinned?.call(call.arguments as String?);
      case 'weigh':
        onWeigh?.call((call.arguments as num).toDouble());
      case 'food':
        onFood?.call((call.arguments as num).toInt());
      case 'action':
        onAction?.call((call.arguments as num).toInt());
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
