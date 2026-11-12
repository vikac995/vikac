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
}
