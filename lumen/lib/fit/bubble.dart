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
    // (Nothing is pinned any more: the floating blob is the Blob itself. What an older build
    // had pinned is not read back, or that blob would be missing from the menu.)
    try {
      countUp.value = _modeFile.readAsStringSync().trim() == 'up';
    } catch (_) {
      // Never chosen: a countdown.
    }
    // (The older lens, which took the look of the app on it, is gone with hand-placed blobs:
    // it is always the container now, whatever was once chosen.)
    // (The Sidekick's settings are Android's own from build 176: the shell asks for a copy.)
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

  /// Where the floating elements (the Sidekick, the workout's timer) may be seen: over Prism
  /// itself, and over other apps. A copy of the Sidekick's own settings: see [took].
  final ValueNotifier<bool> floatIn = ValueNotifier<bool>(true);
  final ValueNotifier<bool> floatOut = ValueNotifier<bool>(true);

  /// Tells Android where Prism's own button is on the screen (its middle, in real pixels).
  /// The side Blob dropped on it fuses with it.
  void tellButton(Offset at, {double? barTop}) {
    _device
        .invokeMethod<void>('button', <double>[at.dx, at.dy, ?barTop])
        .catchError((Object _) {});
  }

  /// Brings the side Blob out, as an app opened from Prism does. True if it could be shown.
  Future<bool> bringSide() async {
    if (!canFloat) {
      return false;
    }
    try {
      final bool ok = await _device.invokeMethod<bool>('side') ?? false;
      if (!ok) {
        // Android has not been told Prism may float: the person is taken to where that is granted.
        ask();
      }
      return ok;
    } catch (_) {
      return false; // Not on Android.
    }
  }

  /// The side Blob was dropped on Prism's button and is fusing with it. Set by the shell.
  VoidCallback? onFused;

  /// Whether there can be floating elements at all.
  bool get canFloat => floatIn.value || floatOut.value;

  // ---- The Sidekick's settings: kept by Android (SidekickSettings.kt) from build 176.
  // Prism keeps only this copy, to show them in the Sidekick's part of its settings panel and in
  // the test report. Prism asks for it when it starts ("sidekickSettings"); changed from that
  // panel, they are sent to Android ("sidekickSet"), which keeps them and answers with them all.
  // (Android may also tell them by itself, with "sidekickSettings": its own panel will.) Until
  // Android has answered (or away from a phone), the copy shows what Prism last did to it.

  /// The Sidekick's two places at a side of the screen, in points: how far from the edge it
  /// rests, and how much of it shows when it is tucked in.
  /// (Any distance between these: the sliders are smooth.)
  static const double gapMin = 0, gapMax = 36, tuckMin = 8, tuckMax = 40;
  double sideGap = 8, sideTuck = 22;

  /// Labels Show | Hide, Icons Prism | Regular, Colours Mellow | Vivid, and its look's id, for
  /// the Sidekick's blobs and sign.
  bool sideNames = true, sidePrismIcons = true, sideVivid = false;
  String sideLook = '';

  /// What Android took over from Prism's old files, the one time it did ("" until it is known).
  String sideMoved = '';

  /// Whether Android has said what they are (false away from a phone).
  bool sideKnown = false;

  /// Changes whenever the copy does.
  final ValueNotifier<int> sideChanged = ValueNotifier<int>(0);

  /// Told the Sidekick's settings (by Android, or by Prism changing them while away from a phone).
  /// Set by the shell: it logs them and sends the Sidekick's pictures again if Icons changed.
  void Function(Map<Object?, Object?> told, String how)? onSidekick;

  /// Android's answer or message: its settings as they are now.
  void took(Object? told, String how) {
    if (told is! Map) {
      return;
    }
    final bool iconsWere = sidePrismIcons;
    floatIn.value = told['inApp'] != false;
    floatOut.value = told['overApps'] != false;
    sideGap = ((told['gap'] as num?)?.toDouble() ?? sideGap).clamp(
      gapMin,
      gapMax,
    );
    sideTuck = ((told['tuck'] as num?)?.toDouble() ?? sideTuck).clamp(
      tuckMin,
      tuckMax,
    );
    sideNames = told['names'] != false;
    sidePrismIcons = told['prismIcons'] != false;
    sideVivid = told['vivid'] == true;
    sideLook = (told['look'] as String?) ?? sideLook;
    sideMoved = (told['moved'] as String?) ?? sideMoved;
    sideKnown = true;
    Apps.instance.sideOwnIcons(!sidePrismIcons);
    sideChanged.value++;
    if (sideMoved.isNotEmpty) {
      _forgetOldFiles();
    }
    onSidekick?.call(
      told,
      iconsWere != sidePrismIcons ? '$how (icons changed)' : how,
    );
  }

  /// Asks Android for them (at the start, and whenever Prism wants to be sure of them).
  Future<void> askSidekick() async {
    try {
      took(await _device.invokeMethod<Object?>('sidekickSettings'), 'asked');
    } catch (_) {
      // Not on a phone: the copy stays as it is.
    }
  }

  /// Changes some of them ([what]: any of inApp, overApps, gap, tuck, names, prismIcons, vivid,
  /// look). [show] ('rest' or 'tuck') puts the Sidekick in that place now, to be seen while it
  /// is chosen; [keep] false: in force but not saved yet (a slider still being dragged).
  Future<void> _set(
    Map<String, Object> what, {
    String? show,
    bool keep = true,
  }) async {
    try {
      final Object? told = await _device.invokeMethod<Object?>(
        'sidekickSet',
        <String, Object?>{...what, 'show': show, 'keep': keep},
      );
      if (keep) {
        took(told, 'changed');
      }
    } catch (_) {
      // Not on a phone: the copy is all there is.
      if (keep) {
        sideChanged.value++;
      }
    }
  }

  /// Where the Sidekick may be seen. Prism sets these only to bring it back when it has been
  /// switched off everywhere ("Bring back the Sidekick", in Prism's settings page), and in its
  /// tests. Everything else about the Sidekick is changed in its own panel, on Android.
  void setFloating({bool? inPrism, bool? overApps}) {
    floatIn.value = inPrism ?? floatIn.value;
    floatOut.value = overApps ?? floatOut.value;
    _set(<String, Object>{'inApp': floatIn.value, 'overApps': floatOut.value});
  }

  /// For the tests only: some of the Sidekick's settings put as the test needs them, and back
  /// afterwards (keys as in [_set]). [show] ('rest' or 'tuck') puts the Sidekick in that place.
  Future<void> testPut(Map<String, Object> what, {String? show}) =>
      _set(what, show: show);

  /// Prism's old files for the Sidekick's settings, which Android has taken over: deleted once
  /// it says it has. (Prism's own Labels, Colours, Look and Icons files stay: they are Prism's.)
  bool _forgot = false;
  void _forgetOldFiles() {
    if (_forgot) {
      return;
    }
    _forgot = true;
    for (final String name in <String>[
      'prism_floating',
      'prism_side_spots',
      'prism_blob_names_side',
      'prism_side_look',
      'prism_side_vivid',
    ]) {
      // (Where Prism wrote them: its files folder, or its temporary folder if that was missing.)
      for (final String dir in <String>[
        _styleFile.parent.path,
        Directory.systemTemp.path,
      ]) {
        try {
          final File f = File('$dir/$name');
          if (f.existsSync()) {
            f.deleteSync();
          }
        } catch (_) {
          // Left where it is: nothing reads it any more.
        }
      }
    }
  }

  /// Prism's panel colours, light and dark, for the Sidekick's own panel in a later step. Sent
  /// only when they have changed.
  Map<String, int>? _paletteSent;
  void tellPalette(Map<String, int> palette) {
    final Map<String, int>? was = _paletteSent;
    if (was != null &&
        was.length == palette.length &&
        palette.entries.every(
          (MapEntry<String, int> e) => was[e.key] == e.value,
        )) {
      return;
    }
    _paletteSent = palette;
    _device
        .invokeMethod<void>('sidekickPalette', palette)
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

  // ---- The Sidekick's menu. It is Android's own (SidekickMenu.kt): kept, saved and changed
  // there. Prism only draws its pictures, and lends its app list to choose from.

  /// Sends Android the pictures for the Sidekick's keys: the name, colour and picture of each.
  void tellSidekickPictures(List<Map<String, Object>> pictures) {
    _device
        .invokeMethod<void>('sidekickPictures', pictures)
        .catchError((Object _) {});
  }

  /// What the Sidekick's menu holds: its five keys. Null where Android has none of its own yet
  /// (before the one-time move), or away from a phone.
  Future<List<String>?> sidekickKeys() async {
    try {
      final List<Object?>? keys = await _device.invokeMethod<List<Object?>>(
        'sidekickKeys',
      );
      return keys == null ? null : <String>[for (final Object? k in keys) '$k'];
    } catch (_) {
      return null;
    }
  }

  /// The one-time move: the menu the Sidekick showed until now, for Android to keep from now
  /// on. Taken only if it has none of its own yet. Answers with the keys it has; null if no answer.
  Future<List<String>?> sidekickAdopt(List<String> keys) async {
    try {
      final List<Object?>? now = await _device.invokeMethod<List<Object?>>(
        'sidekickAdopt',
        keys,
      );
      return now == null ? null : <String>[for (final Object? k in now) '$k'];
    } catch (_) {
      return null;
    }
  }

  /// What was chosen in the app list for the Sidekick's place [slot] ([add]: to go right after
  /// it). Android puts it in the Sidekick's menu.
  void sidekickChosen({
    required int slot,
    required bool add,
    required String key,
  }) {
    _device
        .invokeMethod<void>('sidekickChosen', <String, Object>{
          'slot': slot,
          'add': add,
          'key': key,
        })
        .catchError((Object _) {});
  }

  /// Tells Android that a panel is open in Prism (true) or not. The side Blob, which Android
  /// draws over everything, steps aside meanwhile: a tap meant for the panel must not reach it.
  void tellCovered(bool covered) {
    _device.invokeMethod<void>('covered', covered).catchError((Object _) {});
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
      case 'timerUp':
        // Count up, from nothing.
        if (!countUp.value) {
          toggleMode();
        }
        onTimer?.call('reset');
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
      case 'fused':
        onFused?.call();
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
