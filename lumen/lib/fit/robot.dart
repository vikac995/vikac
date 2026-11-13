import 'dart:async';

import 'package:flutter/gestures.dart';
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

  /// Touch at the first point, travel through the others, let go at the last.
  /// [legMs] is how long each stretch takes; [dwell] is a pause at each point.
  static Future<void> drag(
    List<Offset> path, {
    int legMs = 320,
    int dwell = 0,
    int after = 500,
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
    for (int i = 1; i < path.length; i++) {
      final Offset from = path[i - 1], to = path[i];
      final int steps = (legMs / 8).round();
      for (int k = 1; k <= steps; k++) {
        // Ease in and out, as a hand does.
        final double t = Curves.easeInOut.transform(k / steps);
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
        await wait(8);
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
}
