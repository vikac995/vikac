import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A finger that is not there. It sends the app the same touch events a
/// real finger would, so an automatic test exercises exactly the code a
/// person does: the same hit testing, the same gestures, the same springs.
class Robot {
  Robot._();
  static int _next = 9000;
  static final Stopwatch _clock = Stopwatch()..start();

  static void _send(PointerEvent e) =>
      GestureBinding.instance.handlePointerEvent(e);
  static Future<void> wait(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  /// Touch and let go at [at], then pause so the result can play out.
  static Future<void> tap(Offset at, {int after = 450}) async {
    final int id = _next++;
    _send(
      PointerAddedEvent(pointer: id, position: at, timeStamp: _clock.elapsed),
    );
    _send(
      PointerDownEvent(pointer: id, position: at, timeStamp: _clock.elapsed),
    );
    await wait(50);
    _send(PointerUpEvent(pointer: id, position: at, timeStamp: _clock.elapsed));
    _send(
      PointerRemovedEvent(pointer: id, position: at, timeStamp: _clock.elapsed),
    );
    await wait(after);
  }

  /// Touch at [at], stay there for [ms] without moving, and let go.
  static Future<void> hold(Offset at, {int ms = 700, int after = 450}) async {
    final int id = _next++;
    _send(
      PointerAddedEvent(pointer: id, position: at, timeStamp: _clock.elapsed),
    );
    _send(
      PointerDownEvent(pointer: id, position: at, timeStamp: _clock.elapsed),
    );
    await wait(ms);
    _send(PointerUpEvent(pointer: id, position: at, timeStamp: _clock.elapsed));
    _send(
      PointerRemovedEvent(pointer: id, position: at, timeStamp: _clock.elapsed),
    );
    await wait(after);
  }

  /// Touch at the first point, travel through the others, let go at the last.
  /// The finger moves once per screen refresh, as a real one is reported.
  /// [legMs] is how long each stretch takes; [dwell] is a pause at each point.
  /// With [flick] the finger is still moving when it lets go, so a list coasts.
  static Future<void> drag(
    List<Offset> path, {
    int legMs = 320,
    int dwell = 0,
    int after = 500,
    bool flick = false,
  }) async {
    final int id = _next++;
    Offset at = path.first;
    _send(
      PointerAddedEvent(pointer: id, position: at, timeStamp: _clock.elapsed),
    );
    _send(
      PointerDownEvent(pointer: id, position: at, timeStamp: _clock.elapsed),
    );
    await wait(60);
    // The first few steps are small and come at once, as a real finger's do: what is picked
    // up is then picked up close to where it was touched, however slowly frames are coming.
    if (path.length > 1 && (path[1] - path[0]).distance > 40) {
      final Offset way = (path[1] - path[0]) / (path[1] - path[0]).distance;
      for (int n = 1; n <= 4; n++) {
        final Offset p = path.first + way * (6.0 * n);
        _send(
          PointerMoveEvent(
            pointer: id,
            position: p,
            delta: p - at,
            timeStamp: _clock.elapsed + Duration(milliseconds: 4 * n),
          ),
        );
        at = p;
      }
    }
    for (int i = 1; i < path.length; i++) {
      final Offset from = i == 1 ? at : path[i - 1], to = path[i];
      final int t0 = _clock.elapsedMilliseconds;
      while (true) {
        await SchedulerBinding.instance.endOfFrame;
        final double x = ((_clock.elapsedMilliseconds - t0) / legMs).clamp(
          0.0,
          1.0,
        );
        final double t = flick
            ? Curves.easeIn.transform(x)
            : Curves.easeInOut.transform(x);
        final Offset p = Offset.lerp(from, to, t)!;
        _send(
          PointerMoveEvent(
            pointer: id,
            position: p,
            delta: p - at,
            timeStamp: _clock.elapsed,
          ),
        );
        at = p;
        if (x >= 1) {
          break;
        }
      }
      if (dwell > 0) {
        await wait(dwell);
      }
    }
    _send(PointerUpEvent(pointer: id, position: at, timeStamp: _clock.elapsed));
    _send(
      PointerRemovedEvent(pointer: id, position: at, timeStamp: _clock.elapsed),
    );
    await wait(after);
  }

  /// Things the robot needs to find that are not at a fixed place.
  static final Map<String, GlobalKey> _spots = <String, GlobalKey>{};
  static GlobalKey key(String name) => _spots.putIfAbsent(name, GlobalKey.new);
  static Offset? spot(String name) {
    final RenderObject? r = _spots[name]?.currentContext?.findRenderObject();
    return r is RenderBox && r.attached
        ? r.localToGlobal(r.size.center(Offset.zero))
        : null;
  }
}
