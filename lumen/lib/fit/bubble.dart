import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'apps.dart';

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
    try {
      final List<String> where = _floatFile.readAsStringSync().trim().split(
        ' ',
      );
      floatIn.value = where[0] != '0';
      floatOut.value = where.length < 2 || where[1] != '0';
      follow.value = where.length > 2 && where[2] == '1';
    } catch (_) {
      // Never chosen: both.
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
      // The person may also just have allowed Prism to be told of notifications.
      await Notes.instance.refresh();
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

  /// Where the floating elements (a blob that was put down, the workout's timer) may be seen:
  /// over Prism itself, and over other apps. Both, unless the person chooses otherwise.
  final ValueNotifier<bool> floatIn = ValueNotifier<bool>(true);
  final ValueNotifier<bool> floatOut = ValueNotifier<bool>(true);

  /// "Launch and follow": an app opened from Prism brings its blob along as the floating one,
  /// tucked at the side. Off unless the person chooses it.
  final ValueNotifier<bool> follow = ValueNotifier<bool>(false);

  /// Android says Prism has just opened this app.
  void Function(String package)? onLaunched;

  /// The blob of the app just opened is to be the floating one for now.
  void followTo(Map<String, Object> blob) {
    _device.invokeMethod<void>('follow', blob).catchError((Object _) {});
  }

  /// Whether there can be floating elements at all.
  bool get canFloat => floatIn.value || floatOut.value;

  File get _floatFile => File('${_styleFile.parent.path}/prism_floating');

  void setFloating({bool? inPrism, bool? overApps, bool? followApps}) {
    floatIn.value = inPrism ?? floatIn.value;
    floatOut.value = overApps ?? floatOut.value;
    follow.value = followApps ?? follow.value;
    // Following is over other apps: on, it switches that on; that off, it goes off too.
    if (followApps == true) {
      floatOut.value = true;
    }
    if (!floatOut.value) {
      follow.value = false;
    }
    try {
      _floatFile.writeAsStringSync(
        '${floatIn.value ? 1 : 0} ${floatOut.value ? 1 : 0} ${follow.value ? 1 : 0}',
      );
    } catch (_) {
      // Not saved: both are on next time.
    }
    tellFloating();
  }

  /// Tells Android where the floating elements may be seen.
  void tellFloating() {
    _device
        .invokeMethod<void>('floating', <bool>[
          floatIn.value,
          floatOut.value,
          follow.value,
        ])
        .catchError((Object _) {});
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

  /// Tells Android where Prism's own blobs sit while they are out (the middle of the button and
  /// how near and far from it counts as among them, in real pixels), or null when they are not.
  /// A lens let go among them is put back with them.
  void tellFan(List<double>? fan) {
    _device.invokeMethod<void>('fan', fan).catchError((Object _) {});
  }

  /// The lens is being carried over Prism's blobs (where, in real pixels; null once it is not).
  void Function(Offset? at)? onLensAt;

  /// The lens was let go among Prism's blobs, there: it is one of them again. [inner] is how
  /// large the blob was drawn inside the lens, in real pixels.
  void Function(Offset at, double inner)? onReturned;

  /// Tells Android what the blobs in the menu are, so the floating lens can open the same menu.
  void tellBlobs(List<Map<String, Object>> blobs) {
    _device.invokeMethod<void>('blobs', blobs).catchError((Object _) {});
  }

  /// Tells Android whether the blobs show their names, so the lens's own menu does the same.
  void tellNames(bool names) {
    _device.invokeMethod<void>('blobNames', names).catchError((Object _) {});
  }

  /// A blob is on its way to become the floating lens: shot out of Prism's button, or put down
  /// somewhere ([at], the middle of where, and [velocity], how fast it was going, both in real
  /// pixels). Android puts the lens in its place, unseen if it was not there already, and
  /// answers with where that is on the screen in real pixels (x, y of its corner, and its
  /// size), so the blob can land on it. Null if the lens cannot float here.
  Future<Map<Object?, Object?>?> land(
    Map<String, Object> blob, {
    Offset? at,
    Offset velocity = Offset.zero,
  }) async {
    try {
      return await _device.invokeMethod<Map<Object?, Object?>>(
        'land',
        <String, Object>{
          ...blob,
          if (at != null) 'atX': at.dx,
          if (at != null) 'atY': at.dy,
          'vx': velocity.dx,
          'vy': velocity.dy,
        },
      );
    } catch (_) {
      return null; // Not on Android.
    }
  }

  /// The blob has landed: the lens shows itself, with the give of something just caught.
  /// Finishes once the lens has been drawn, so the blob can be taken away then and not before.
  /// (Never waits long: if nothing answers, it finishes anyway.)
  Future<void> landed() async {
    try {
      await _device
          .invokeMethod<void>('landed')
          .timeout(const Duration(milliseconds: 400));
    } catch (_) {
      // Not on Android, or no answer in time.
    }
  }

  /// The blob that was let go among Prism's own has been drawn there: the lens can go.
  void taken() {
    _device.invokeMethod<void>('taken').catchError((Object _) {});
  }

  /// How large the lens is, in real pixels. Null away from a phone.
  Future<double?> lensSize() async {
    try {
      return (await _device.invokeMethod<num>('lensSize'))?.toDouble();
    } catch (_) {
      return null;
    }
  }

  /// The timer in the floating sheet was tapped ('pause'), or one of the things it offers when
  /// held was chosen ('reset', 'off'). Set by the workout page.
  void Function(String what)? onTimer;

  /// The workout was stopped from the floating sheet. Set by the workout page.
  VoidCallback? onStop;

  /// For the long test: starts a rest of this many seconds, as finishing a set does. Set by
  /// the workout page.
  void Function(int seconds)? testRest;

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
      case 'lensAt':
        final List<Object?>? at = call.arguments as List<Object?>?;
        onLensAt?.call(
          at == null
              ? null
              : Offset((at[0]! as num).toDouble(), (at[1]! as num).toDouble()),
        );
      case 'returnedAt':
        final List<Object?> at = call.arguments as List<Object?>;
        final Offset where = Offset(
          (at[0]! as num).toDouble(),
          (at[1]! as num).toDouble(),
        );
        if (onReturned == null) {
          setPin(null);
          taken();
        } else {
          onReturned!(where, at.length > 2 ? (at[2]! as num).toDouble() : 0);
        }
      case 'stop':
        onStop?.call();
      case 'timerPause':
        onTimer?.call('pause');
      case 'timerReset':
        onTimer?.call('reset');
      case 'timerOff':
        onTimer?.call('off');
      case 'pinned':
        onPinned?.call(call.arguments as String?);
      case 'launched':
        onLaunched?.call(call.arguments as String);
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

  /// Tells Android which of Prism's pages is showing. A lens that holds that page then has
  /// nowhere to take the person, and a tap on it opens its menu.
  void tellTab(int tab) {
    _device.invokeMethod<void>('tab', tab).catchError((Object _) {});
  }
}
