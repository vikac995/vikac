# Flutter UI/UX Showcase: Research Findings and Build Brief

Compiled 12 November 2026. This file is a handoff: it contains everything needed to continue the project in a new chat without the original conversation.

## 1. The project

**Goal:** an Android APK that showcases the most modern, beautiful and innovative UX/UI elements possible in Flutter today. It is a demo of craft, not a product: every pixel of every control and the smoothness of every animation matters.

**Process agreed so far:**

1. Research the current state of UX/UI design and Flutter (done, sections 2 to 4).
2. Owner comments on the findings and the proposed concept (section 5).
3. Build the APK and send it for testing on a real phone.
4. Iterate based on feedback from the device.

**Constraints:**

- Target: Android, tested on a 120 Hz phone. Exact model and chipset not yet known (ask, because it decides how heavy the shaders can be).
- The owner is not a developer. He has a product owner background, so he judges the result as a user. He needs a ready-to-install APK, not build instructions.
- Feedback comes back as screen recordings from the phone.

## 2. Design findings: where UI design is in late 2026

### 2.1 Two dominant languages, slowly converging

- **Apple Liquid Glass** (introduced with iOS 26, refined in iOS 27): a translucent material that bends and refracts the content behind it and reacts to touch. Calm, restrained, depth through light.
- **Google Material 3 Expressive** (introduced with Android 16): bold color, large and varied shapes, emphasized type, springy physics-based motion. Loud, playful, clear.
- **They are converging.** Android 17 and its QPR1 update spread translucent blur across system UI (volume panel, power menu, app folders, context menus), themed with dynamic color. Blur is not yet part of the Material guidelines for apps, only system UI.
- Commentary consensus: Liquid Glass has more visual "wow" and influences cross-platform trends more; M3 Expressive travels better across devices and is backed by more usability research.

### 2.2 Rules for glass

- Glass belongs on the **navigation and controls layer**, never on content itself.
- Use a more opaque (regular) variant behind text-heavy floating UI; reserve the clear variant for controls over photos and video.
- Add a dimming layer when the content behind is bright.
- Legibility is the known weak point (criticised in sunlight and over busy backgrounds). iOS 27 responded with a user slider from ultraclear to fully tinted.
- Must respect Reduce Transparency and Increase Contrast in both light and dark mode.

### 2.3 Rules for motion

- **Springs have replaced duration-and-curve animation.** M3 Expressive defines motion by stiffness and damping, not milliseconds and bezier curves.
- Motion tokens come in two families: **spatial** (position, size, layout; may overshoot) and **effects** (opacity, color; should not bounce). Each has fast, default and slow variants.
- Expressive springs (visible overshoot) are for hero moments: a FAB expanding, a shape morph. Standard springs (little or no overshoot) are for utilitarian feedback: lists, tooltips, validation.
- Larger elements get slower motion; small ones get faster.
- Motion must be **interruptible**: a gesture can grab an element mid-animation and the spring continues from the current velocity. This is the main practical advantage of springs over curves.
- **Shape morphing** is a signature effect: buttons and loaders change geometry between states (M3 Expressive ships a library of about 35 shapes with built-in morphs).
- **Haptics are part of the animation.** Fire them at the key moment (the overshoot or the settle), and match intensity to the importance of the change.
- Reduced motion: cut to roughly 10 to 20 percent of normal or replace with a fade.

### 2.4 Research backing

- Google ran 46 studies with more than 18,000 participants for M3 Expressive.
- Reported result: users spotted key UI elements up to four times faster in expressive layouts than in standard Material 3.
- Users in that research preferred the more playful designs.

### 2.5 Other patterns worth building

- Bento grids (mixed-size card layouts).
- Progressive blur (blur that fades in gradually, for example under a header).
- Shared-element and view transitions (a card becomes the next screen).
- Variable typography (font weight and width animate continuously).
- Prompt bars and trust states for AI output.
- Dark-first color tokens.
- Calm design (less noise, motion only when it has a job).
- Accessibility-first component states.
- Predictive back: the screen follows the finger during the back gesture and previews the destination. Android 17 QPR1 extended this to more system surfaces.

## 3. Technical findings: where Flutter is in November 2026

### 3.1 Version state

- **Flutter 3.50** is the current stable (released 11 November 2026) with **Dart 3.14**.
- Release cadence in 2026: 3.41 (Feb), 3.44 (May), 3.47 (Aug), 3.50 (Nov).
- **Material and Cupertino have left the SDK.** They are now standalone packages, `material_ui` and `cupertino_ui` (1.0 since Flutter 3.47). The old imports `package:flutter/material.dart` and `package:flutter/cupertino.dart` are formally deprecated in 3.50 but still work.
- New projects from `flutter create` use `package:material_ui` by default. Import: `package:material_ui/material_ui.dart`.
- Existing code migrates with `dart fix --apply --code=migrate_design_widgets`.
- Gotcha: types from the old library and the new package are different types even with the same name (for example `ColorScheme`). Any dependency that still imports the old library can cause type conflicts. There is a compatibility bridge, but for a new project it is cleaner to pick only dependencies that have already migrated.
- The design packages now release on their own schedule, much faster than the SDK.
- Android toolchain expectations have moved up (Java 17, Android Gradle Plugin 9.x, Gradle 9.x as of 3.47; check the 3.50 notes for current values).

### 3.2 Rendering

- **Impeller is the default renderer on Android and Skia has been removed** (since 3.44). On modern phones it runs on Vulkan, with OpenGL ES as fallback.
- Flutter 3.41 improved fragment shader support.
- Impeller is what makes real glass possible: a fragment shader can be used as a backdrop filter (`ImageFilter.shader` inside a `BackdropFilter`), which lets a widget distort the live pixels behind it.

### 3.3 Liquid Glass in Flutter

- There is **no official implementation yet**. The Flutter team has said official Liquid Glass and M3 Expressive implementations are in progress.
- Community packages exist and are active: `liquid_glass_widgets`, `fluid_glass`, `g1455`, `liquiglass`, `just_liquid_glass`, `liquid_glass_lens_navbar`, `liquid_glass_fx`.
- Common technique: a blur pass by the engine, then a shader pass that does refraction (displacing the backdrop along a bevel), chromatic dispersion, edge highlights and tint. Some add press and drag deformation with spring-back.
- **Performance lessons from these packages:**
  - Refraction is the expensive part: a shader over the element every frame it changes.
  - A naive approach reads the backdrop once per glass surface per frame. Better: one shared backdrop capture for all glass on screen (Flutter's `BackdropGroup` or a package-level host).
  - Ship quality tiers: full (refraction, dispersion, highlights), medium (weak refraction, no dispersion), low (blur and tint only).
  - Fall back to a plain frosted `BackdropFilter` when the shader path is unavailable or when Reduce Transparency is on.
  - Preload shaders before the first frame to avoid a visible pop.
  - Test on real GPUs; emulators mislead.

### 3.4 M3 Expressive in Flutter

- Also no official implementation yet.
- Community package `material_3_expressive` implements the component set on top of `material_ui`, requires Flutter 3.44 or newer, and uses helper packages: `motor` (spring motion), `material_new_shapes` (morphable polygon shapes) and `dynamic_color` (wallpaper-based color).

### 3.5 Flutter building blocks to use (verify against 3.50 docs before relying on them)

- Springs: `SpringSimulation`, `SpringDescription`, `AnimationController.animateWith`.
- Shaders: `FragmentProgram.fromAsset`, `FragmentShader`, shaders declared in `pubspec.yaml`.
- Glass: `BackdropFilter`, `ImageFilter.blur`, `ImageFilter.shader`, `BackdropGroup`.
- Shape: rounded superellipse (the "squircle" corner the engine now draws natively), custom `ShapeBorder` with path interpolation for morphs.
- Haptics: `HapticFeedback` (light, medium, heavy, selection). Finer control needs a plugin.
- Navigation: `Hero` for shared elements, predictive back page transitions on Android.
- Type: variable fonts via `FontVariation`.
- Accessibility flags: `MediaQuery.disableAnimations`, `MediaQuery.highContrast`.

## 4. Design principles for this build

Distilled from the research; treat these as the acceptance criteria.

1. Every animation is a spring and every spring is interruptible.
2. Nothing moves without a reason. Motion explains where something came from or where it went.
3. Glass only on controls, with a guaranteed legible fallback.
4. Haptics land on the settle, not on the touch-down, and are used sparingly.
5. Hold 120 fps. If an effect cannot, it drops a quality tier rather than dropping frames.
6. Touch targets at least 48 dp; press states respond within one frame.
7. One global switch for reduced motion and reduced transparency, and the app still looks good with both on.
8. Light and dark themes both designed, not derived.

## 5. Proposed showcase concept (awaiting owner comments)

One app, six "rooms", each proving one idea. A home screen in a bento grid leads into them.

1. **Glass.** A floating navigation bar with a draggable refracting lens as the selection indicator, over a colorful scrolling feed. Includes a clear-to-tinted slider.
2. **Springs.** The same control animated with a classic curve and with a spring, side by side. The user can grab and throw it mid-flight to feel the difference.
3. **Shape morph.** Buttons, toggles and a loading indicator that morph between shapes on press and state change, with a haptic on the settle.
4. **Shared-element flow.** A bento card expands into a full screen, and the back gesture drags it back under the finger.
5. **Shader playground.** Touch-reactive gradients, progressive blur, ripple distortion.
6. **Micro-details.** Variable-font headline that reacts to scroll, a prompt bar, a pull-to-refresh with character.

Rooms 1 to 4 are proven patterns executed carefully. Rooms 5 and 6 are where the experiments go.

**Recommendation:** write the glass shader, spring system and shape morphs by hand rather than depending on community packages. It avoids the `material_ui` type-conflict risk, and a showcase of craft should not be a package demo. The packages in 3.3 remain useful as reference.

## 6. Open questions and risks

- Phone model and chipset are unknown. Needed to set the default shader quality tier.
- Shader performance and haptic feel cannot be verified without a real device. Expect two or three test rounds.
- Flutter 3.50 is one day old. If a dependency breaks on it, fall back to 3.47 and say so.
- The owner has not yet commented on the six-room concept. Get that before building.
- App name, visual identity and color direction are undecided.

## 7. Sources

- Flutter 3.50 announcement: https://flutter.dev/blog/whats-new-in-flutter-3-50
- Flutter 3.50 release notes: https://docs.flutter.dev/release/release-notes/release-notes-3.50.0
- Migration to material_ui and cupertino_ui: https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui
- Breaking changes list: https://docs.flutter.dev/release/breaking-changes
- Flutter 3.41 announcement (release windows, shader improvements): https://flutter.dev/blog/whats-new-in-flutter-3-41
- Flutter 3.44 overview (Impeller default on Android): https://www.cmarix.com/blog/latest-flutter-version/
- Very Good Ventures on 3.50: https://verygood.ventures/blog/flutter-3-50-dart-3-14/
- material_ui migration guide for app owners: https://qorinx.com/blog/flutter-material-ui-migration-before-flutter-3-50
- Glass packages: https://pub.dev/packages/liquid_glass_widgets , https://pub.dev/packages/fluid_glass , https://pub.dev/packages/g1455 , https://pub.dev/packages/liquiglass , https://pub.dev/packages/just_liquid_glass , https://pub.dev/packages/liquid_glass_lens_navbar , https://github.com/hucong730/flutter_liquid_glass
- M3 Expressive for Flutter: https://github.com/paadevelopments/material_3_expressive/wiki
- UI trends for 2027: https://medium.com/design-bootcamp/10-ui-ux-design-trends-for-2027-7958bbc434e4
- UI trends 2026: https://www.wavespace.agency/blog/ui-design-trends , https://www.gleamstudio.design/blog-post/ui-design-trends-2026 , https://www.uxstudioteam.com/ux-blog/ui-trends-2019
- Liquid Glass vs M3 Expressive: https://mantlr.com/blog/liquid-glass-vs-material-expressive , https://orangeloops.com/blog/liquid-glass-vs-material-3-expressive-next-gen-ui-design-compared/
- M3 Expressive research: https://www.dezeen.com/2025/05/28/google-ushers-in-age-of-expressive-interfaces-with-material-design-update/amp/
- Android 17 blur and predictive back: https://9to5google.com/2026/01/25/android-17-blur/ , https://androidauthority.com/android-17-qpr1-rollout-3711654
