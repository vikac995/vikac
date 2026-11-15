# Step 1d report: one Prism, and counting what memory holds (build 173)

Asked for by the review of build 172's phone run (485 of 485). Branch
`claude/flutter-ui-showcase-ngzfru`, based on `2d28c13`. Two commits: `6725ea9` (the code, the APK, the
changelog, the handover, this report) and the one after it, which only adds the checked link here. Step 2 not started. No look or motion changed.

**What has only run in the preview:** everything. Nothing in this build has run on a phone. All of
A is Android code (only compiled), and the memory counts on Android's side read nothing in the
preview.

## Files changed

| File | What changed |
|---|---|
| `android/.../PrismScreen.kt` | **New.** `PrismScreen`: the one Prism screen alive, and `bringForward()`, the single way Prism brings itself forward. `PrismLauncher`: the app icon / installer "Open", with no screen of its own. |
| `android/.../MainActivity.kt` | Each screen records whether it was opened as the home screen. A second screen is closed at once (see A). `opened()` hands a request to the screen that is there. `onNewIntent` takes Prism's own home-type launches (extra `PRISM_OPEN`) as requests, not as the home button. `openPrism`, `openAction` and the test's `front` and return from `away` go through `PrismScreen`. The test report's `state` has Android's cache counts. `Trail.size()`. |
| `android/.../SidekickMenu.kt` | `state` reports how many pictures it holds. |
| `android/app/src/main/AndroidManifest.xml` | The LAUNCHER intent-filter moves from `MainActivity` to `.PrismLauncher` (translucent, no history, not in recents). |
| `lib/fit/apps.dart` | Codecs, image descriptors and buffers disposed on every path (cut-out glyphs, `IconEngine.decode`, `fromPixels`, the unused old decoder). |
| `lib/fit/shell.dart` | `_iconPng` disposes its recorded picture, its text layout, and the image even if PNG encoding fails. The test's memory readings carry every cache's count and size. |
| `lib/core/glass.dart` | The start-up warm-up disposes its recorded picture. |
| `lib/fit/drawer.dart` | `appListTexts()`: how many text layouts the app list keeps (for the report only). |
| `lib/fit/long_test.dart` | `framesKept`; the CACHES BY PART table. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 173, `0.134.0+201`. |
| `CHANGELOG.md`, `HANDOVER.md` | Build 173 entry; the one-screen rule. |
| `releases/prism-build-173.apk` | The build. |

## A. Never a second Prism screen

**Which launch made #2, from the code and the engine history.**
- `MainActivity` had both intent-filters: LAUNCHER (app icon, the installer's "Open":
  `getLaunchIntentForPackage`) and HOME. It is `singleTask`, `taskAffinity=""`.
- Android keeps a launch of the home screen (activity type *home*) in its own task. Any other launch
  of the same activity (activity type *standard*) does not reuse that task. It makes a second task
  with a second instance, so a second engine.
- In 172's run, #1 was made at 19:19:33 when Prism was opened after installing it. That is the
  installer's "Open" or the app icon: a standard launch.
- #2 was made 5 s later. Only the home gesture makes a home-type screen without any action of
  Prism's, so #2 is the home screen the gesture asked for.
- #1 was let go 19 s later (swiped away, or closed by Android).
- Prism's own launches made the same kind of second screen when the screen alive was the home one.
  Those are `openPrism()` (the Sidekick's Change/Add/settings, the timer), `openAction()` (a
  Sidekick blob's action or page), and the test's `front` and return from `away`. All were explicit,
  hence standard. This fits the owner's first 172 run getting stuck over the calculator.

**What 173 does: one way forward, the same kind of launch as the screen that is there.**
1. **Prism's own starts.** `PrismScreen.bringForward(context, action, index, why)` is the only path.
   It reaches the screen alive with the kind of launch that made it:
   - If that screen is the home one, it sends the home intent for Prism alone (`ACTION_MAIN` +
     `CATEGORY_HOME` + `setPackage`, no component, so Android treats it as a home launch). It
     carries the request in the extra `PRISM_OPEN`. Android hands it to that same home screen
     (`onNewIntent`), which does the request and does not treat it as the home button: no jump to
     Home.
   - If the screen alive is an ordinary one, it sends the explicit intent as before. Android hands
     that to the ordinary screen that is there.
   - With no screen alive, it starts one as the home screen if Prism is the default home
     (`resolveActivity` of the home intent). Otherwise it starts it by name.
2. **The app icon and the installer's "Open".** These go to `PrismLauncher`, a translucent activity
   with no screen, no history and no recents entry. It calls `bringForward` and finishes. The
   LAUNCHER intent-filter is now on it, not on `MainActivity`.
3. **The safety net**, in `MainActivity.onCreate`, should Android make a second screen all the same:
   - If the new one is the home screen, the other one is closed (`finishAndRemoveTask`). The home
     gesture always finds the home one.
   - Otherwise the new one closes itself at once, and the one there is reached and given the
     request.
   - Either way a line goes to the engine history ("a second Prism screen was made by …"). The
     second engine is still made (Flutter makes it before `onCreate` can decide), so the history
     would show it.
4. **Android's line to Prism** (172) still follows the screen in front and leaves one that is let
   go. That is unneeded with one screen, and harmless.
5. **The `device` field.** It is not static: each `MainActivity` has its own (`private var
   device`). It is used only by that screen, in `onNewIntent` and `opened()`, so it always leads to
   that screen's own engine, which is alive while the screen is. Everything else Android tells
   Prism goes through `Floater.channel`, which 172 already made follow the live engine. No sender
   can reach a dead engine through `device`.

**I first wrote it to move Prism's task to the front**, but changed it before building.
- `ActivityManager.AppTask.moveToFront`, with a fall-back to `moveTaskToFront` and the
  `REORDER_TASKS` permission.
- The home screen's task is not among an app's own recent tasks, so the first would not find it, and
  I couldn't check the second here.
- The launch-of-the-same-kind way needs no permission and is what Android itself does for the home
  button.

**Proof on the phone:**
- The report's top: "PRISM'S ENGINES: 1 made".
- The history lines name how each screen was opened: "opened by the home button or gesture", "an
  app icon", "Prism itself, as the home screen".
- The flight recorder: "Prism brought forward (why): the home screen that is there (engine #1)".

**Not checked:** all of it. Whether Android hands a `setPackage` home intent to the existing home
screen on this phone is the point to watch. If it doesn't, the safety net closes the extra screen
(and the history shows it).

## B. Native growth

**From 172's run** (one engine): native grows about 57 MB a round, and is the same "after gc".
- **Where it grows, every round:**
  - "labels hidden and shown": about +17 MB;
  - "Sidekick, then Prism, chosen": about +18 MB after collection;
  - part 6 to the next part 1: about +17 MB;
  - "a swipe's list, and back": about +5 MB.
- **What these steps share:** each rebuilds Prism's settings panel, or the app list. The labels and
  the Prism | Sidekick choice also make Prism re-send the Sidekick's names, look and pictures. The
  look previews are plain painters that keep nothing (`BlobSignPreview`), so they aren't a cache.

**Correction to my 172 reading:**
- The "after gc" column collects *Java's* garbage. Prism's own objects (Dart) that hold memory
  outside Dart (text layouts, recorded pictures, decoded images and their codecs) are freed only
  when they are let go by hand, or when Dart collects its own garbage, which Java's collection
  doesn't trigger.
- So "after gc" equal to native shows the growth isn't Java's. It doesn't show that Prism's side
  couldn't give it back.

**Fixed now (safe, as asked):** everything that makes such objects lets them go by hand, on every
path.
- `IconEngine.decode` disposes its codec.
- The cut-out glyphs and `fromPixels` dispose codec, descriptor and buffer, as Flutter's own
  `decodeImageFromPixels` does.
- `_iconPng` disposes its recorded picture, its text layout, and the image even if PNG encoding
  throws.
- The glass warm-up disposes its picture.
- None of these runs in the growing steps (they run when icons are made). They are fixed because
  they were leaks in principle, not because they explain the growth.

**Counted now, for the next run to name the culprit.** A second table in the report, CACHES BY
PART, at every memory reading (each part, and each step of part 4):
- **pngs:** `_imagePngs` + `_markPngs`, count and KB. Pictures made into PNG files for Android. Up
  to 60 kept, keyed by the image itself, so they also keep those images alive.
- **cache:** Flutter's `ImageCache`, images and KB.
- **apps:** every app picture held (`AppTile` glyph/picture/own, `BlobApp` glyph/icon/picture),
  count and KB.
- **texts:** the app list's text layouts (names + letters + numbers). Never evicted. The names'
  key includes the cell width and the density factor (to 2 decimals), which change during the
  list's own animations, so this one can grow. It is my first suspect for the app-list step, not
  proven.
- **frames:** how many frames' timings the test itself keeps. It keeps every one, in Dart memory.
- **icons:** Android's decoded blob pictures (`Floater.icons`), count and KB (`allocationByteCount`).
- **sk pics:** the Sidekick's pictures (`SidekickMenu.pictures`).
- **trail:** the flight recorder's lines (at most 400).

In the preview (no Android, no phone apps) the table works. Nothing grows there across part 4:
texts 20+8+5 after the app list first opened, unchanged after "a swipe's list, and back".

**Not fixed, because not proven:** the app list's text cache, and the PNG map's hold on images.
The next run's table shows whether either grows in step with native.

## Results (preview, on the final code)

```
button test:  CHECKS: 68 right, 1 wrong, of 69
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(...))]
long test:    CHECKS: 65 right, 4 wrong, of 69
  WRONG  app list: the flick wakes neither the magnifying glass nor a card
  WRONG  Home, nothing open / blobs out / app list open: measured  [no answer (MissingPluginException(...))]
```

- **No rerun needed:** the long test had the usual 4 misses on its first run this time.
- **Analyser:** the same 4 old notes. `dart format` clean.
- **Kotlin** compiles.
- **The APK's manifest** (`aapt dump xmltree`): the LAUNCHER filter is on `.PrismLauncher`, the
  HOME filter on `.MainActivity`. The other LAUNCHER entry is the `<queries>` block, as before.

**Build 173:** `Prism build 173`, `0.134.0+201`, built from the final code. NAME-OK.
`PrismLauncher` is in its `classes.dex`. sha256
`ff59727821f24ef9bb84f91c27309b03711ddd11fdc56942b510d3392553d657`, 18,583,802 bytes. Link: https://github.com/vikac995/vikac/raw/6725ea9acf98d69b390d7c7ff2d944a5899cd183/lumen/releases/prism-build-173.apk
(pinned to `6725ea9`, the commit that added the APK). Checked after the push: it answers 200, and the
downloaded file has the same sha256 as the one built.

## For the owner on the phone

1. Install 173. **Open it once from the installer's "Open"**, then use the Home gesture, then
   Prism's icon in the app drawer if there is one, then edit the Sidekick over another app. Each
   time there should be one Prism: one in the task manager, the same one with the Home gesture.
2. Run the button test and send the report: "PRISM'S ENGINES" should say "1 made". Send the
   CACHES BY PART table, and right after, the flight recorder.
3. Note: the app icon is now a different part of Prism (`PrismLauncher`). A shortcut to Prism on
   another launcher's screen may need adding again.
