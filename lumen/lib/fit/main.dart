import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/frame_stats.dart';
import '../core/glass.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../widgets/fps_meter.dart';
import '../core/haptics.dart';
import 'look.dart';
import 'bubble.dart';
import 'diag.dart';
import 'journal.dart';
import 'recorder.dart';
import 'robot.dart';
import 'shell.dart';

/// Prism: a fitness app prototype built from Lumen's parts. A second app
/// from the same project; see android/app/build.gradle.kts for how it gets
/// its own name and id.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  final AccessibilityFeatures a11y =
      PlatformDispatcher.instance.accessibilityFeatures;
  if (a11y.disableAnimations) {
    settings.reduceMotion = true;
  }
  if (a11y.highContrast) {
    settings.reduceTransparency = true;
  }
  settings.showFps = false; // on from the settings sheet
  await GlassShaders.load();
  FrameStats.instance.start();
  // On Auto, glass steps down by itself if frames are being missed.
  FrameStats.instance.governorEnabled = true;
  // Follows the phone's own light or dark setting unless the person has chosen otherwise.
  settings.themeMode = ThemeMode.system;
  Look.instance.load();
  await Diag.instance.start();
  // The diary: every stretch of use, the battery, and anything that goes wrong.
  Journal.instance.start();
  // The flight recorder: quietly keeps the last few hundred things that happened.
  Recorder.instance.start();
  RestBubble.instance.start();
  Diag.instance.tail = Journal.instance.report;
  runApp(const PrismApp());
}

class PrismApp extends StatelessWidget {
  const PrismApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[settings, Look.instance]),
      builder: (BuildContext context, Widget? _) => MaterialApp(
        title: 'Prism',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: PointerDeviceKind.values.toSet(),
        ),
        theme: lumenTheme(Look.instance.day),
        darkTheme: lumenTheme(Look.instance.night),
        themeMode: settings.themeMode,
        home: const Shell(),
        navigatorObservers: <NavigatorObserver>[PanelWatch.instance],
        builder: (BuildContext context, Widget? child) {
          final LumenColors c = LumenColors.of(context);
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: const Color(0x00000000),
              systemNavigationBarColor: const Color(0x00000000),
              systemNavigationBarContrastEnforced: false,
              statusBarIconBrightness: c.dark
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarIconBrightness: c.dark
                  ? Brightness.light
                  : Brightness.dark,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                children: <Widget>[
                  child!,
                  if (settings.showFps) const FpsMeter(),
                  // While a guided test runs, a small banner says which setting is being tried.
                  ValueListenableBuilder<String?>(
                    valueListenable: Diag.instance.banner,
                    builder: (BuildContext context, String? text, Widget? _) =>
                        text == null
                        ? const SizedBox.shrink()
                        : Positioned(
                            top:
                                MediaQuery.paddingOf(context).top +
                                (settings.showFps ? 38 : 4),
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: const ShapeDecoration(
                                    color: Color(0xF02E7BFF),
                                    shape: StadiumBorder(),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        text,
                                        textAlign: TextAlign.center,
                                        textScaler: TextScaler.noScaling,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                      ),
                                      // The long test and the button test: the round, the part,
                                      // about how long is left, and a thin bar that fills.
                                      ValueListenableBuilder<(String, double)?>(
                                        valueListenable: Diag.instance.progress,
                                        builder:
                                            (
                                              BuildContext context,
                                              (String, double)? p,
                                              Widget? _,
                                            ) => p == null
                                            ? const SizedBox.shrink()
                                            : Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: <Widget>[
                                                    Text(
                                                      p.$1,
                                                      textAlign:
                                                          TextAlign.center,
                                                      textScaler:
                                                          TextScaler.noScaling,
                                                      style: const TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 10.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xE6FFFFFF,
                                                        ),
                                                        height: 1.2,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    SizedBox(
                                                      width: 180,
                                                      height: 3,
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              1.5,
                                                            ),
                                                        child: Stack(
                                                          children: <Widget>[
                                                            const ColoredBox(
                                                              color: Color(
                                                                0x40FFFFFF,
                                                              ),
                                                              child:
                                                                  SizedBox.expand(),
                                                            ),
                                                            FractionallySizedBox(
                                                              widthFactor: p.$2
                                                                  .clamp(
                                                                    0.0,
                                                                    1.0,
                                                                  ),
                                                              heightFactor: 1,
                                                              child:
                                                                  const ColoredBox(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                      ),
                                      // The leak test's text that changes weight (see Diag.probe).
                                      ValueListenableBuilder<(double, bool)?>(
                                        valueListenable: Diag.instance.probe,
                                        builder:
                                            (
                                              BuildContext context,
                                              (double, bool)? p,
                                              Widget? _,
                                            ) => p == null
                                            ? const SizedBox.shrink()
                                            : Text(
                                                'Show  Hide',
                                                textScaler:
                                                    TextScaler.noScaling,
                                                style: p.$2
                                                    // (Exactly as LumenType.text drew a moving
                                                    // weight before build 175.)
                                                    ? TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 13,
                                                        color: Colors.white,
                                                        fontVariations:
                                                            <FontVariation>[
                                                              FontVariation(
                                                                'wght',
                                                                p.$1,
                                                              ),
                                                              const FontVariation(
                                                                'opsz',
                                                                14,
                                                              ),
                                                            ],
                                                      )
                                                    : LumenType.text(
                                                        13,
                                                        weight: p.$1,
                                                        color: Colors.white,
                                                      ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  // While a test runs: Stop, at the top left, clear of everything the test touches.
                  // Only a real finger presses it; the test's own touches pass it by.
                  ListenableBuilder(
                    listenable: Listenable.merge(<Listenable>[
                      Robot.running,
                      Diag.instance.progress,
                    ]),
                    builder: (BuildContext context, Widget? _) =>
                        !Robot.running.value
                        ? const SizedBox.shrink()
                        : Positioned(
                            top:
                                MediaQuery.paddingOf(context).top +
                                (settings.showFps ? 38 : 4) +
                                44 +
                                // (Lower while the banner has its progress line.)
                                (Diag.instance.progress.value == null ? 0 : 40),
                            left: 12,
                            child: Listener(
                              // (Translucent: the test's own touches go on to what is beneath.)
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: (PointerDownEvent e) {
                                if (Robot.mine(e.pointer)) {
                                  return;
                                }
                                Haptics.thud();
                                Robot.stoppedWhile =
                                    Diag.instance.banner.value ?? '';
                                Diag.instance.banner.value =
                                    'Stopping the test, putting things back…';
                                Robot.stop();
                              },
                              // (The button itself takes no touch, so that the test's own touches
                              // really do pass it by, on to whatever is under it: its coloured box
                              // used to stop them there. On a phone, where the status bar puts it
                              // lower, it lay over the settings' Prism | Sidekick picker.)
                              child: IgnorePointer(
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: const ShapeDecoration(
                                    color: Color(0xF0E5484D),
                                    shape: StadiumBorder(),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        Icons.stop_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Stop test',
                                        textScaler: TextScaler.noScaling,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          height: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  // Tap the readout to copy the test report.
                  if (settings.showFps)
                    Positioned(
                      top: MediaQuery.paddingOf(context).top,
                      left: 60,
                      right: 60,
                      height: 40,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          await Diag.instance.copy();
                          Haptics.settle();
                          FrameStats.instance.note('Test report copied');
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Counts the panels open in Prism (sheets and dialogs over the pages), and tells Android
/// whenever there come to be some or none: the side Blob steps aside while there are.
class PanelWatch extends NavigatorObserver {
  PanelWatch._();
  static final PanelWatch instance = PanelWatch._();
  int _open = 0;

  /// Whether any panel is open just now.
  bool get anyOpen => _open > 0;

  void _set(int n) {
    final bool was = _open > 0;
    _open = math.max(0, n);
    if ((_open > 0) != was) {
      RestBubble.instance.tellCovered(_open > 0);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      _set(_open + 1);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      _set(_open - 1);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      _set(_open - 1);
    }
  }
}
