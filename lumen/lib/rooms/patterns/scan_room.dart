import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';
import 'inputs_room.dart' show DragDial;

/// Room 32. Scanning a barcode, as an interface: a frame that closes on the
/// code when it is found, a result that rises as a sheet, the portion set
/// with a dial, one button to add. (The camera picture here is drawn; no
/// real camera is used.)
class ScanRoom extends StatefulWidget {
  const ScanRoom({super.key});

  @override
  State<ScanRoom> createState() => _ScanRoomState();
}

class _ScanRoomState extends State<ScanRoom> with TickerProviderStateMixin {
  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final SpringValue _lock = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _sheet = SpringValue(this, spring: Motions.expressive);
  bool _found = false, _torch = false, _added = false;
  double _grams = 150;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _line.dispose();
    _lock.dispose();
    _sheet.dispose();
    super.dispose();
  }

  void _scan() {
    setState(() {
      _found = false;
      _added = false;
    });
    _lock.animateTo(0);
    _sheet.animateTo(0, spring: Motions.spatialFast);
    // Three sweeps, then it "finds" the code. Nothing runs after that.
    _line.repeat(reverse: true, count: 3);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2600), _find);
  }

  void _find() {
    if (_found || !mounted) {
      return;
    }
    _timer?.cancel();
    _line.stop();
    setState(() => _found = true);
    _lock.animateTo(1);
    Haptics.thud();
    Timer(const Duration(milliseconds: 220), () {
      if (mounted) {
        _sheet.animateTo(1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final int kcal = (_grams * 3.72).round();
    return Scaffold(
      backgroundColor: const Color(0xFF07080B),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // The "camera" view.
          GestureDetector(
            onTap: _found ? null : _find,
            child: ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[_line, _lock]),
              builder: (BuildContext context, Widget? _) => CustomPaint(
                painter: _CameraPainter(
                  _line.value,
                  _lock.value,
                  _found,
                  _torch,
                  c.accent,
                ),
              ),
            ),
          ),
          Positioned(
            top: safe.top + 44,
            left: 16,
            right: 16,
            child: Theme(
              data: lumenTheme(LumenColors.night),
              child: const RoomHeader(number: 32, title: 'Scan'),
            ),
          ),
          Positioned(
            top: safe.top + 52,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() => _torch = !_torch);
                Haptics.tick();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: ShapeDecoration(
                  color: _torch ? Colors.white : const Color(0x33FFFFFF),
                  shape: const CircleBorder(),
                ),
                child: Icon(
                  _torch
                      ? Icons.flashlight_on_rounded
                      : Icons.flashlight_off_rounded,
                  color: _torch ? Colors.black : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.sizeOf(context).height * 0.5 + 120,
            child: Text(
              _found ? 'Found' : 'Hold the code inside the frame.\nTap anywhere to pretend it was read.',
              textAlign: TextAlign.center,
              style: LumenType.text(14.5, weight: 560, color: Colors.white70),
            ),
          ),
          // The result rises over the camera; the camera stays visible above it.
          ListenableBuilder(
            listenable: _sheet,
            builder: (BuildContext context, Widget? child) {
              final double v = _sheet.value;
              return Positioned(
                left: 8,
                right: 8,
                bottom: 8 + safe.bottom - 380 * (1 - v),
                child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
              );
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              decoration: ShapeDecoration(
                color: c.surfaceHigh,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(34),
                  side: BorderSide(color: c.hairline),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: ShapeDecoration(
                        color: c.ink.withValues(alpha: 0.25),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Oat granola, honey',
                    style: LumenType.display(24, weight: 700, color: c.ink),
                  ),
                  Text(
                    'Example brand · 372 kcal per 100 g',
                    style: LumenType.text(14, color: c.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'PORTION, G',
                              style: LumenType.label(color: c.inkFaint),
                            ),
                            const SizedBox(height: 6),
                            DragDial(
                              value: _grams,
                              step: 10,
                              fineStep: 1,
                              min: 0,
                              max: 1000,
                              unit: 'g',
                              onChanged: (double v) =>
                                  setState(() => _grams = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            '$kcal',
                            textScaler: TextScaler.noScaling,
                            style: LumenType.display(
                              40,
                              weight: 700,
                              color: c.ink,
                              height: 1,
                            ),
                          ),
                          Text(
                            'kcal',
                            style: LumenType.text(13.5, color: c.inkMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Pressable(
                        onTap: _scan,
                        child: Container(
                          height: 54,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            shape: StadiumBorder(
                              side: BorderSide(color: c.inkFaint),
                            ),
                          ),
                          child: Text(
                            'Scan again',
                            style: LumenType.text(
                              15,
                              weight: 640,
                              color: c.ink,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Pressable(
                          onTap: _added
                              ? null
                              : () {
                                  setState(() => _added = true);
                                  Haptics.settle();
                                },
                          child: Container(
                            height: 54,
                            alignment: Alignment.center,
                            decoration: ShapeDecoration(
                              color: _added
                                  ? const Color(0xFF2FA84F)
                                  : c.accent,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              _added ? 'Added to today' : 'Add',
                              style: LumenType.text(
                                16,
                                weight: 660,
                                color: _added ? Colors.white : c.onAccent,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPainter extends CustomPainter {
  const _CameraPainter(
    this.line,
    this.lock,
    this.found,
    this.torch,
    this.accent,
  );
  final double line, lock;
  final bool found, torch;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height * 0.4);
    // A table and a packet, out of focus.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = torch ? const Color(0xFF2A241C) : const Color(0xFF14110D),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.08);
    final Rect pack = Rect.fromCenter(
      center: Offset.zero,
      width: 250,
      height: 330,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pack, const Radius.circular(18)),
      Paint()
        ..color = torch ? const Color(0xFFE9C46A) : const Color(0xFF8A6F35),
    );
    final Rect label = Rect.fromCenter(
      center: const Offset(0, 40),
      width: 190,
      height: 96,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(label, const Radius.circular(8)),
      Paint()..color = Colors.white.withValues(alpha: torch ? 0.95 : 0.7),
    );
    final math.Random r = math.Random(5);
    double x = label.left + 12;
    while (x < label.right - 12) {
      final double w = 1.5 + r.nextInt(3) * 1.5;
      canvas.drawRect(
        Rect.fromLTWH(x, label.top + 12, w, label.height - 30),
        Paint()..color = Colors.black,
      );
      x += w + 1.5 + r.nextInt(3) * 1.5;
    }
    canvas.restore();
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // The frame: four corners that close on the code when it is read.
    final double w = 260 - 54 * lock, h = 170 - 60 * lock;
    final Rect f = Rect.fromCenter(
      center: c.translate(-4 * lock, 40 * lock),
      width: w,
      height: h,
    );
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(Colors.white, accent, lock.clamp(0.0, 1.0))!;
    const double k = 26, rad = 14;
    for (final (double sx, double sy) in <(double, double)>[
      (-1, -1),
      (1, -1),
      (1, 1),
      (-1, 1),
    ]) {
      final Offset corner = Offset(
        sx < 0 ? f.left : f.right,
        sy < 0 ? f.top : f.bottom,
      );
      final Path path = Path()
        ..moveTo(corner.dx, corner.dy - sy * k)
        ..lineTo(corner.dx, corner.dy - sy * rad)
        ..quadraticBezierTo(
          corner.dx,
          corner.dy,
          corner.dx - sx * rad,
          corner.dy,
        )
        ..lineTo(corner.dx - sx * k, corner.dy);
      canvas.drawPath(path, p);
    }
    if (!found) {
      final double y =
          f.top + 10 + (f.height - 20) * Curves.easeInOut.transform(line);
      canvas.drawLine(
        Offset(f.left + 14, y),
        Offset(f.right - 14, y),
        Paint()
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..color = accent,
      );
    }
  }

  @override
  bool shouldRepaint(_CameraPainter old) =>
      old.line != line ||
      old.lock != lock ||
      old.found != found ||
      old.torch != torch;
}
