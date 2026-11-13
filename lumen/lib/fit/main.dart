import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/frame_stats.dart';
import '../core/glass.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../widgets/fps_meter.dart';
import '../core/haptics.dart';
import 'diag.dart';
import 'journal.dart';
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
  await Diag.instance.start();
  // The diary: every stretch of use, the battery, and anything that goes wrong.
  Journal.instance.start();
  Diag.instance.tail = Journal.instance.report;
  runApp(const PrismApp());
}

class PrismApp extends StatelessWidget {
  const PrismApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, Widget? _) => MaterialApp(
        title: 'Prism',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: PointerDeviceKind.values.toSet(),
        ),
        theme: lumenTheme(LumenColors.day),
        darkTheme: lumenTheme(LumenColors.night),
        themeMode: settings.themeMode,
        home: const Shell(),
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
                                  child: Text(
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
