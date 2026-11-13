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
