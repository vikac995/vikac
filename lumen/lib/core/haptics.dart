import 'package:flutter/services.dart';

/// Haptics are part of the animation: call these when a spring settles,
/// not when the finger goes down. They are played straight on the vibration
/// motor by native code, because the system's light haptics are too faint
/// (or silent) on some phones.
abstract final class Haptics {
  static const MethodChannel _native = MethodChannel('lumen/haptics');

  /// Set from Settings.
  static bool enabled = true;

  static void _play(String kind, Future<void> Function() fallback) {
    if (!enabled) {
      return;
    }
    _native
        .invokeMethod<void>('play', kind)
        .catchError((Object _) => fallback());
  }

  /// A notch or a selection (lens on a tab, a dial step).
  static void tick() => _play('tick', HapticFeedback.selectionClick);

  /// A state change settled (toggle, panel, screen closed).
  static void settle() => _play('click', HapticFeedback.lightImpact);

  /// A beat, an end stop or a refusal.
  static void thud() => _play('thud', HapticFeedback.heavyImpact);

  static void beat() => thud();
}
