import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'core/expand_route.dart';
import 'core/frame_stats.dart';
import 'core/glass.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'home/home_screen.dart';
import 'rooms/access/access_room.dart';
import 'rooms/basics/contrast_room.dart';
import 'rooms/basics/forms_room.dart';
import 'rooms/basics/sheets_room.dart';
import 'rooms/basics/space_room.dart';
import 'rooms/basics/states_room.dart';
import 'rooms/basics/type_room.dart';
import 'rooms/colour/colour_room.dart';
import 'rooms/data/data_room.dart';
import 'rooms/details/details_room.dart';
import 'rooms/dials/dials_room.dart';
import 'rooms/disco/disco_room.dart';
import 'rooms/foil/foil_room.dart';
import 'rooms/pill/pill_room.dart';
import 'rooms/flow/flow_room.dart';
import 'rooms/flow/stories.dart';
import 'rooms/glass/glass_room.dart';
import 'rooms/patterns/blob_room.dart';
import 'rooms/patterns/dodont_room.dart';
import 'rooms/patterns/inputs_room.dart';
import 'rooms/patterns/launcher_room.dart';
import 'rooms/patterns/perf_room.dart';
import 'rooms/patterns/timer_room.dart';
import 'rooms/screens/assistant_screen.dart';
import 'rooms/screens/components_room.dart';
import 'rooms/screens/dashboard_screen.dart';
import 'rooms/screens/detail_screen.dart';
import 'rooms/screens/onboarding_screen.dart';
import 'rooms/shaders/shaders_room.dart';
import 'rooms/shapes/shape_room.dart';
import 'rooms/springs/springs_room.dart';
import 'widgets/fps_meter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  // Follow the system accessibility settings on first launch.
  final AccessibilityFeatures a11y =
      PlatformDispatcher.instance.accessibilityFeatures;
  if (a11y.disableAnimations) {
    settings.reduceMotion = true;
  }
  if (a11y.highContrast) {
    settings.reduceTransparency = true;
  }

  // Compile the glass shader before the first frame so it never pops in.
  await GlassShaders.load();
  FrameStats.instance.start();
  runApp(const LumenApp());
}

class LumenApp extends StatelessWidget {
  const LumenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, Widget? _) {
        return MaterialApp(
          title: 'Lumen',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: PointerDeviceKind.values.toSet(),
          ),
          theme: lumenTheme(LumenColors.day),
          darkTheme: lumenTheme(LumenColors.night),
          themeMode: settings.themeMode,
          themeAnimationDuration: settings.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 420),
          themeAnimationCurve: const SpringCurve(),
          home: switch (const String.fromEnvironment('START')) {
            'glass' => const GlassRoom(),
            'springs' => const SpringsRoom(),
            'shapes' => const ShapeRoom(),
            'flow' => const FlowRoom(),
            'story' => StoryPage(story: stories[0]),
            'shaders' => const ShadersRoom(),
            'details' => const DetailsRoom(),
            'disco' => const DiscoRoom(),
            'foil' => const FoilRoom(),
            'dials' => const DialsRoom(),
            'pill' => const PillRoom(),
            'colour' => const ColourRoom(),
            'data' => const DataRoom(),
            'access' => const AccessRoom(),
            'type' => const TypeRoom(),
            'space' => const SpaceRoom(),
            'contrast' => const ContrastRoom(),
            'states' => const StatesRoom(),
            'forms' => const FormsRoom(),
            'sheets' => const SheetsRoom(),
            'perf' => const PerfRoom(),
            'launcher' => const LauncherRoom(),
            'blob' => const BlobRoom(),
            'timer' => const TimerRoom(),
            'inputs' => const InputsRoom(),
            'dodont' => const DoDontRoom(),
            'components' => const ComponentsRoom(),
            'dashboard' => const DashboardScreen(),
            'detail' => const DetailScreen(),
            'assistant' => const AssistantScreen(),
            'onboarding' => const OnboardingScreen(),
            _ => const HomeScreen(),
          },
          builder: (BuildContext context, Widget? child) {
            final LumenColors c = LumenColors.of(context);
            if (const String.fromEnvironment('TEXTSCALE').isNotEmpty) {
              child = MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    double.parse(const String.fromEnvironment('TEXTSCALE')),
                  ),
                ),
                child: child!,
              );
            }
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
