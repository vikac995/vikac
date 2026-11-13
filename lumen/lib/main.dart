import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'core/expand_route.dart';
import 'core/frame_stats.dart';
import 'core/glass.dart';
import 'core/haptics.dart';
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
import 'rooms/screens/settings_screen.dart';
import 'rooms/patterns/numpad_room.dart';
import 'rooms/patterns/scan_room.dart';
import 'rooms/patterns/widgets_room.dart';
import 'rooms/patterns/lists_room.dart';
import 'rooms/patterns/celebrate_room.dart';
import 'rooms/patterns/theme_room.dart';
import 'rooms/patterns/notify_room.dart';
import 'rooms/patterns/calendar_room.dart';
import 'rooms/screens/workout_screen.dart';
import 'rooms/patterns/nav_room.dart';
import 'rooms/patterns/reorder_room.dart';
import 'rooms/screens/summary_screen.dart';
import 'rooms/patterns/wheels_room.dart';
import 'rooms/patterns/plates_room.dart';
import 'rooms/screens/progress_screen.dart';
import 'rooms/screens/nutrition_screen.dart';
import 'rooms/patterns/video_room.dart';
import 'rooms/patterns/swap_room.dart';
import 'rooms/patterns/session_room.dart';
import 'rooms/patterns/flude_room.dart';
import 'rooms/patterns/lens_room.dart';
import 'rooms/patterns/bud_room.dart';
import 'rooms/play/toss_room.dart';
import 'rooms/play/pack_room.dart';
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
            'settings' => const SettingsScreen(),
            'numpad' => const NumpadRoom(),
            'scan' => const ScanRoom(),
            'widgets' => const WidgetsRoom(),
            'lists' => const ListsRoom(),
            'celebrate' => const CelebrateRoom(),
            'theme' => const ThemeRoom(),
            'notify' => const NotifyRoom(),
            'calendar' => const CalendarRoom(),
            'workout' => const WorkoutScreen(),
            'nav' => const NavRoom(),
            'reorder' => const ReorderRoom(),
            'summary' => const SummaryScreen(),
            'wheels' => const WheelsRoom(),
            'plates' => const PlatesRoom(),
            'progress' => const ProgressScreen(),
            'nutrition' => const NutritionScreen(),
            'video' => const VideoRoom(),
            'swap' => const SwapRoom(),
            'session' => const SessionRoom(),
            'flude' => const FludeRoom(),
            'lens' => const LensRoom(),
            'bud' => const BudRoom(),
            'toss' => const TossRoom(),
            'pack' => const PackRoom(),
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
                child: _TwoFingerTap(
                  onTap: _flipTheme,
                  child: Stack(
                    children: <Widget>[
                      child!,
                      if (settings.showFps) const FpsMeter(),
                      const _ThemeQuick(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

void _flipTheme() {
  settings.themeMode = settings.themeMode == ThemeMode.dark
      ? ThemeMode.light
      : ThemeMode.dark;
  Haptics.tick();
}

/// A small sun or moon in the top right corner of every screen: one tap
/// switches between light and dark.
class _ThemeQuick extends StatelessWidget {
  const _ThemeQuick();

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Positioned(
      top: MediaQuery.paddingOf(context).top - 2,
      right: 2,
      child: Semantics(
        button: true,
        label: c.dark ? 'Switch to light' : 'Switch to dark',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _flipTheme,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: ShapeDecoration(
                  color: c.dark
                      ? const Color(0xE6101216)
                      : const Color(0xE6FFFFFF),
                  shape: CircleBorder(side: BorderSide(color: c.hairline)),
                ),
                child: Icon(
                  c.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 16,
                  color: c.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Calls [onTap] when two fingers tap the screen together, anywhere. It only
/// listens, so it never takes a touch away from what is underneath.
class _TwoFingerTap extends StatefulWidget {
  const _TwoFingerTap({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_TwoFingerTap> createState() => _TwoFingerTapState();
}

class _TwoFingerTapState extends State<_TwoFingerTap> {
  final Map<int, Offset> _down = <int, Offset>{};
  Duration _first = Duration.zero;
  bool _valid = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent e) {
        if (_down.isEmpty) {
          _first = e.timeStamp;
          _valid = false;
        }
        _down[e.pointer] = e.position;
        // Exactly two fingers, landing within a fifth of a second.
        _valid =
            _down.length == 2 &&
            e.timeStamp - _first < const Duration(milliseconds: 200);
      },
      onPointerMove: (PointerMoveEvent e) {
        final Offset? o = _down[e.pointer];
        if (o != null && (e.position - o).distance > 18) {
          _valid = false;
        }
      },
      onPointerCancel: (PointerCancelEvent e) {
        _down.remove(e.pointer);
        _valid = false;
      },
      onPointerUp: (PointerUpEvent e) {
        _down.remove(e.pointer);
        if (_down.isEmpty &&
            _valid &&
            e.timeStamp - _first < const Duration(milliseconds: 450)) {
          widget.onTap();
        }
        if (_down.isEmpty) {
          _valid = false;
        }
      },
      child: widget.child,
    );
  }
}
