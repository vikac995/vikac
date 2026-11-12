import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

import 'springs.dart';

enum GlassQuality { auto, full, medium, low }

/// App-wide preferences. One instance, listened to at the root.
class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _reduceMotion = false;
  bool _reduceTransparency = false;
  bool _showFps = true;
  GlassQuality _quality = GlassQuality.auto;
  GlassQuality _autoTier = GlassQuality.full;

  ThemeMode get themeMode => _themeMode;
  bool get reduceMotion => _reduceMotion;
  bool get reduceTransparency => _reduceTransparency;
  bool get showFps => _showFps;

  /// What the user picked (may be [GlassQuality.auto]).
  GlassQuality get quality => _quality;

  /// What is actually rendered right now; never [GlassQuality.auto].
  GlassQuality get effectiveQuality =>
      _quality == GlassQuality.auto ? _autoTier : _quality;

  set themeMode(ThemeMode v) => _set(() => _themeMode = v);
  set reduceTransparency(bool v) => _set(() => _reduceTransparency = v);
  set showFps(bool v) => _set(() => _showFps = v);
  set quality(GlassQuality v) => _set(() => _quality = v);
  set reduceMotion(bool v) => _set(() {
    _reduceMotion = v;
    Motion.reduced = v;
  });

  /// Called by the frame governor when frames are being missed. Returns the
  /// new tier, or null if there was nothing to drop.
  GlassQuality? dropAutoTier() {
    if (_quality != GlassQuality.auto || _autoTier == GlassQuality.low) {
      return null;
    }
    _set(
      () => _autoTier = _autoTier == GlassQuality.full
          ? GlassQuality.medium
          : GlassQuality.low,
    );
    return _autoTier;
  }

  void resetAutoTier() => _set(() => _autoTier = GlassQuality.full);

  void _set(VoidCallback fn) {
    fn();
    notifyListeners();
  }
}

final AppSettings settings = AppSettings();
