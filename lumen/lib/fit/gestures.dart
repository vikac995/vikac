import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// What the two-finger swipes do. Four of them: down, up, left, right. Each holds the same
/// kind of thing a blob holds ('action:2', 'screen:1', 'app:com.whatsapp'), or the
/// notifications ('phone:shade'), or nothing ('empty:'). Kept in a small file of its own.
class GestureSlots extends ChangeNotifier {
  GestureSlots._();
  static final GestureSlots instance = GestureSlots._();

  static const List<String> names = <String>['down', 'up', 'left', 'right'];

  /// As Prism starts: down for the notifications, up for the scanner, the sides for nothing.
  final List<String> keys = <String>[
    'phone:shade',
    'action:2',
    'empty:',
    'empty:',
  ];

  File get _file {
    final Directory files = Directory(
      '${Directory.systemTemp.parent.path}/files',
    );
    return File(
      '${files.existsSync() ? files.path : Directory.systemTemp.path}/prism_gestures_v1',
    );
  }

  void load() {
    try {
      final List<String> lines = _file.readAsLinesSync();
      for (int i = 0; i < keys.length && i < lines.length; i++) {
        if (lines[i].trim().isNotEmpty) {
          keys[i] = lines[i].trim();
        }
      }
    } catch (_) {
      // Nothing has been changed yet.
    }
  }

  void put(int i, String key) {
    keys[i] = key;
    try {
      _file.writeAsStringSync(keys.join('\n'));
    } catch (_) {
      // Not saved: they are as Prism starts with next time.
    }
    notifyListeners();
  }

  /// Puts the notifications away again. Only the test needs this.
  static Future<void> shadeClose() async {
    try {
      await const MethodChannel('lumen/device')
          .invokeMethod<void>('shadeClose');
    } catch (_) {
      // Not on Android.
    }
  }

  /// Pulls Android's notifications down. False where that cannot be done.
  static Future<bool> shade() async {
    try {
      return await const MethodChannel('lumen/device')
              .invokeMethod<bool>('shade') ??
          false;
    } catch (_) {
      return false;
    }
  }
}

/// Two fingers down and moved. With one finger it takes no part at all: it only notes that a
/// finger is down, so taps, drags and scrolling go on exactly as if it were not there. When a
/// second finger comes down, and [wanted] says a swipe would mean something just now, the
/// first finger is taken away from whatever had it (nothing beneath scrolls on or is pressed),
/// the second is followed, and it says once which way it went: 0 down, 1 up, 2 left, 3 right.
class TwoFingerSwipe extends OneSequenceGestureRecognizer {
  TwoFingerSwipe({required this.onSwipe, required this.wanted});

  final void Function(int way) onSwipe;
  final bool Function() wanted;

  int? _first, _second;
  Offset _from = Offset.zero;
  bool _done = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_first == null && _second == null) {
      // The first finger: only watched, to know when it leaves.
      _first = event.pointer;
      GestureBinding.instance.pointerRouter.addRoute(event.pointer, _watch);
      return;
    }
    if (_first != null && _second == null && wanted()) {
      super.addAllowedPointer(event);
      _second = event.pointer;
      _from = event.position;
      _done = false;
      resolve(GestureDisposition.accepted);
      GestureBinding.instance.cancelPointer(_first!);
    }
  }

  void _watch(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      GestureBinding.instance.pointerRouter.removeRoute(event.pointer, _watch);
      if (_first == event.pointer) {
        _first = null;
      }
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _second) {
      return;
    }
    if (event is PointerMoveEvent) {
      final Offset moved = event.position - _from;
      if (!_done && moved.distance > 44) {
        _done = true;
        onSwipe(
          moved.dy.abs() > moved.dx.abs()
              ? (moved.dy > 0 ? 0 : 1)
              : (moved.dx < 0 ? 2 : 3),
        );
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
      _second = null;
      _done = false;
    }
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {}

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void dispose() {
    if (_first != null) {
      GestureBinding.instance.pointerRouter.removeRoute(_first!, _watch);
      _first = null;
    }
    super.dispose();
  }

  @override
  String get debugDescription => 'two-finger swipe';
}
