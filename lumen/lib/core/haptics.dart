import 'package:flutter/services.dart';

/// Haptics are part of the animation: call these when a spring settles,
/// not when the finger goes down.
abstract final class Haptics {
  /// A selection landed (lens on a tab, segment chosen).
  static void tick() => HapticFeedback.selectionClick();

  /// A state change settled (toggle, panel).
  static void settle() => HapticFeedback.lightImpact();

  /// Refusal or a heavier landing.
  static void thud() => HapticFeedback.mediumImpact();

  static const MethodChannel _native = MethodChannel('lumen/haptics');

  /// A strong pulse played straight on the vibration motor, for rhythm. Falls
  /// back to the system haptic where the native side is missing.
  static void beat() {
    _native
        .invokeMethod<void>('beat')
        .catchError((Object _) => HapticFeedback.heavyImpact());
  }
}
