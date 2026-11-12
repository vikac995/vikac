import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'settings.dart';

/// Reads the engine's own frame timings. Drives the on-screen readout and the
/// governor that drops glass quality instead of dropping frames.
class FrameStats extends ChangeNotifier {
  FrameStats._();
  static final FrameStats instance = FrameStats._();

  bool idle = true;
  double refreshRate = 60;
  double fps = 0;
  double worstMs = 0;
  int missed = 0;

  /// True while a screen with live glass is showing.
  bool governorEnabled = false;

  /// Set when the governor lowers the tier; screens show a notice.
  final ValueNotifier<GlassQuality?> lastDrop = ValueNotifier<GlassQuality?>(
    null,
  );

  int _strikes = 0;
  int? _prevVsync;

  void start() => SchedulerBinding.instance.addTimingsCallback(_onTimings);

  void resetCounters() {
    missed = 0;
    worstMs = 0;
    notifyListeners();
  }

  void _onTimings(List<FrameTiming> timings) {
    final Iterable<FlutterView> views = PlatformDispatcher.instance.views;
    if (views.isNotEmpty) {
      final double r = views.first.display.refreshRate;
      if (r > 1) {
        refreshRate = r;
      }
    }
    final double interval = 1e6 / refreshRate;
    double sum = 0;
    int count = 0;
    int late = 0;
    double worst = 0;
    for (final FrameTiming t in timings) {
      final int vsync = t.timestampInMicroseconds(FramePhase.vsyncStart);
      final int? prev = _prevVsync;
      _prevVsync = vsync;
      if (prev == null) {
        continue;
      }
      final int gap = vsync - prev;
      // Long gaps mean nothing was animating, not that frames were missed.
      if (gap <= 0 || gap > interval * 6) {
        continue;
      }
      sum += gap;
      count += 1;
      if (gap > interval * 1.5) {
        late += ((gap / interval).round() - 1).clamp(1, 5);
      }
      final double work =
          (t.buildDuration + t.rasterDuration).inMicroseconds / 1000;
      if (work > worst) {
        worst = work;
      }
    }
    if (count < 4) {
      if (!idle) {
        idle = true;
        notifyListeners();
      }
      return;
    }
    idle = false;
    fps = (1e6 / (sum / count)).clamp(0, refreshRate);
    worstMs = worst;
    missed += late;
    notifyListeners();

    if (governorEnabled && count >= 24) {
      if (late / (count + late) > 0.12) {
        _strikes += 1;
        if (_strikes >= 2) {
          _strikes = 0;
          final GlassQuality? tier = settings.dropAutoTier();
          if (tier != null) {
            lastDrop.value = tier;
          }
        }
      } else {
        _strikes = 0;
      }
    }
  }
}
