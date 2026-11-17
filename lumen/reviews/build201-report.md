# Build 201 report: the test's own store

Brief: `tasks/BUILD201.md` (the plan agreed with the review chat on 16 November, after the outside review's
F02 and F34; numbered 201 on 17 November).
- **The one change:** while one of Prism's own tests runs, nothing it changes is ever saved over what the
  person keeps.
- 202 is search.

**The preview has run the Dart half, including a test killed half way.** The Android half (the Sidekick's
menu and settings) is by reading.

## Why (F02, F34, confirmed by reading)

**Before 201:**
- The tests changed the person's own menu, swipes, labels and look, and saved each change to the person's
  own files at once.
- On Android they did the same to the Sidekick's menu and settings.
- Everything was written back only at the very end of the test.
- **A test killed half way never wrote anything back:** swiped away, a crash, the phone reclaiming memory,
  a reboot, a flat battery overnight. The person was left with the test's menu (action:0 to action:4),
  the test's swipes, its Sidekick menu and its settings.

## What changed

| File | What changed |
|---|---|
| `lib/fit/test_store.dart` (new) | **`TestStore`:** while a test runs, every store asks it for its file and is given a file of the test's own beside it (`….test`), never the person's. **`begin`** writes a marker, `end` removes it and the test's files. **`unfinished`** (at the next start) says a test never ended, and clears its files. **`snapshot`** gives the person's files' bytes, for the checks. |
| `lib/fit/apps.dart`, `gestures.dart`, `look.dart`, `diag.dart`, `bubble.dart` | **Through `TestStore.file`:** Prism's menu, its labels, the swipes, the look, Auto's glass level, Prism's icons (app list and blobs), the app list's density and scrolling, the button's look and vivid, the settings hint, the pinned thing, the timer's count up or down, the timer's style. **`reload()`** for the menu, swipes, look and Auto's level: read again from the person's own files. |
| `lib/core/settings.dart` | `AppSettings.testing`, set while a test runs. Glass quality, reduce transparency, the lights and the glass style aren't kept anywhere yet. Anything that comes to keep them must keep nothing while this is set (F34). The test still puts them back in memory as it ends. |
| `android/.../SidekickMenu.kt`, `SidekickSettings.kt` | **`testing`:** while a test runs, changes are in force but never saved. **`testEnded`:** read again from what's saved, put in force, and Prism told. **Test state:** what's saved now. |
| `android/.../AppChoices.kt` | The Sidekick's "most used" open counts aren't counted during a test. |
| `android/.../MainActivity.kt` | **`testStore`** (from Prism): a test begins or ends. Also sent "ended" each time Prism starts, in case a test ended unfinished while this process lived on. |
| `lib/fit/shell.dart` | **At the test's start:** the person's files read, then `TestStore.begin`, and Android told. **In its `finally`:** `TestStore.end`, every store read again from the person's own files (instead of writing back what the test remembered), and Android told. **At Prism's start:** an unfinished test is noted in the flight recorder, and Android is told no test runs. **The checks** below. |
| `DESIGN.md` | §10: the tests never touch what the person keeps. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 201, "The test's own store", `askedTest = 'button'`; `0.162.0+229`. |
| `tasks/BUILD201.md` (was `NEXT-test-store.md`), `CHANGELOG.md` | The brief; build 201. |
| `releases/prism-build-201.apk` | The build. |

**Found while building, beyond the brief's menu, swipes and labels:** the test also changes the look,
Auto's level (its heavy scenes can step the person's glass down for good), the pin, the timer's mode,
Prism's icons and the app list's density, each saved to a file. All of them are kept apart now.

**Not kept apart:** the Sidekick's own position and size (Android remembers where it was left). After a
test, the Sidekick stays where the test left it, as before.

## The checks

**New, in the button test and the long test** (they run in the preview too):
1. **"the test's own menu is kept apart: your menu's file is as it was"**: right after the test puts in
   its own menu (action:0 to action:4).
2. **"the test's swipes are kept apart: your swipes' file is as it was"** (the long test's swipe step).
3. **"at the end, your menu, labels, swipes, look and glass Auto files are exactly as they were"**:
   byte for byte.
4. **"at the end, your menu, labels, swipes and look are back in force"**.
5. **On the phone: "at the end, the Sidekick's saved menu and settings are exactly as they were, and in
   force again"**. It compares what Android has saved, at the start and the end, and checks that the
   test mode is off.

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 84 right, 1 wrong, 1 skipped, of 86 (the usual Android-only miss and phone-only skip; 3 new, all right)
long test:    CHECKS: 68 right, 3 wrong, of 71 (the usual 3, all "measured: no answer", Android-only; 4 new, all right)
```

**A test killed half way, in the preview:**
1. The person's files' checksums were taken.
2. The button test was started, and killed (`kill -9`) 50 seconds in.
3. **At that moment:** the test had written its own menu to `prism_blobs_v1.test`, and the marker was
   there.
4. **After the kill:** all six of the person's files were byte for byte as before: the menu, labels,
   swipes, Auto's level, the pin and the density.
5. **The next normal start:** cleared the marker and the test's files, and the person's menu file was
   still the same.

**Also:**
- **Analyser:** the same 4 old notes. Kotlin compiles.

**Build 201:**
- `Prism build 201`, `0.162.0+229`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- **Its `classes.dex` has:** `testStore`, `sidekickSavedKeys`, `sidekickSettingsSaved` and "a test ended,
  its own menu is as saved".
- **Its `libapp.so` has:** "Prism build 201", "The test's own store", `prism_test_running` and the new
  checks.
- sha256 `64c8b95a989bfe8fce4ef2e88771e77d33474a6dd8def216e40fcfb98f35e0b6`, 18,960,842 bytes.
- Link (checked: answers 200, same sha256): https://github.com/vikac995/vikac/raw/f6200ae7161d772bcdd47ffab66ed0c020cd077f/lumen/releases/prism-build-201.apk

## Where I could be wrong

1. **The Android half hasn't run.**
   - The Sidekick's menu and settings aren't saved during a test, and are read again from what's saved as
     it ends. Check 5 shows it on the phone.
   - If Prism's engine dies but Android's process lives on, Android keeps not saving until Prism starts
     again. Prism tells it to stop at each start. Until then, a change the person makes to the Sidekick
     works but isn't saved.
2. **The Sidekick's position and size aren't kept apart.** After any test, the Sidekick is where the test
   left it, as before 201.
3. **Settings read only at Prism's start** (Prism's icons, density, the timer's mode) come back from the
   person's file at the next start after a killed test. Within a test that ends normally, the test puts
   their values back in memory itself, as before.
4. **The "ended unfinished" note** goes to the flight recorder, not to a screen, so the person won't see
   it unless they look there.
5. **The preview's files live in `/tmp`, the phone's in Prism's own files folder.** The code is the same
   either way, but the phone's run is the real proof.

## On the phone

**What to look at:**
- **A normal run:** run the button test. At its end, the five "test store" checks are right, and your
  menu, swipes, look and Sidekick are as they were.
- **A killed run (if you like):** start the test, swipe Prism away from the recent apps half way, open
  Prism again. Your own menu is there, not action:0 to action:4.
