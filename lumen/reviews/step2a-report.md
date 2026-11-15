# Step 2a report: the Sidekick's settings move to Android (build 176)

Brief: `tasks/STEP2a.md` (saved as given). Plan: `tasks/STEP2-plan.md`. Branch
`claude/flutter-ui-showcase-ngzfru`, based on `9eae84c`. Two commits: `dedd41e` (the code, the APK, the
changelog, the handover, the lessons, the brief, this report) and the one after it, which only adds the
checked link here. Step 2b (the panel) not started: where it sits
and the way back are still the owner's to decide. **Nothing should look different.**

**What has only run in the preview:** the Prism side, and only where it doesn't need Android.
- **The preview has no Android,** so none of these has run anywhere yet:
  - the move;
  - Android keeping the settings;
  - the round trips;
  - the colours reaching Android;
  - the keyboard measurement.
- **The new checks** are in the button test's part 5, which needs a phone. In the preview it stops
  before part 5, as always.
- **The Kotlin** compiles, and that is all that can be said for it.

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickSettings.kt` | **New.** The Sidekick's settings, kept by Android: in this app, over other apps, the two distances, labels, icons, colours, look; Prism's panel colours. The one-time move from Prism's old files. Applies them to the Sidekick (and, for the two switches and the distances, to the timer, exactly as Prism's messages did). |
| `android/.../MainActivity.kt` | Loads them before Prism's engine can speak. `sidekickSet`, `sidekickSettings`, `sidekickPalette` replace Prism's `floating`, `sideSpots`, `blobNames`, `blobLook`, `blobVivid`. The test state carries them. The test driver's `keyboardProbe`. `Floater.redraw()`. |
| `lib/fit/bubble.dart` | `RestBubble`: no more files for these. A read-only copy (`floatIn`, `floatOut`, `sideGap`, `sideTuck`, `sideNames`, `sidePrismIcons`, `sideVivid`, `sideLook`, `sideMoved`, `sideKnown`, `sideChanged`), set only from Android's answers (`took`). Every change goes through `sidekickSet`. Prism's old files are deleted once Android says it has moved them. `tellPalette`. The old `tellNames`, `tellLook`, `tellVivid`, `tellFloating` are gone. |
| `lib/fit/apps.dart` | The Sidekick's labels, look and colours are no longer kept here (`sideNames`, `sideLook`, `sideVivid` and their files are gone). `sideOwnIcons`: the apps' own icons are held when the Sidekick's Icons is Regular. |
| `lib/fit/shell.dart` | The panel's Sidekick part reads the copy and writes through Android. Its Icons picker is the Sidekick's own. The Sidekick's pictures follow its own Icons. The panel colours are sent. Android's settings message is handled, and every copy is written in the recorder. SETTINGS lines. The button test's new checks and the keyboard measurement. |
| `lib/fit/diag.dart`, `lib/fit/main.dart` | The test's text field (only during the measurement). Build 176. |
| `lib/core/theme.dart` | (In `bc55710`, shipped in this APK: optical size and width stepped too.) |
| `pubspec.yaml` | `0.137.0+204`. |
| `LESSONS.md` | The three agreed rules. |
| `tasks/STEP2a.md` | The brief. |
| `CHANGELOG.md`, `HANDOVER.md` | Build 176; the settings are Android's. |
| `releases/prism-build-176.apk` | The build. |

## 1. The settings move to Android

**Where they live now:** `SidekickSettings` (Kotlin):
- In `prism_sidekick`, the same preferences as the Sidekick's menu.
- One key each: `inApp`, `overApps`, `gap`, `tuck`, `names`, `icons`, `vivid`, `look`. Plus `settingsOwn`
  (the move is done), `settingsMoved` (what it found), and `palette.*`.

**When they are read:** in `configureFlutterEngine`, right after the recorder starts. That's before
Prism's engine can send or ask anything. They are put in force there:
- the Sidekick's labels, look and colours;
- the two switches and the distances, on both floating things, as the old `floating` and `sideSpots`
  messages did. The timer is unchanged, as asked.

**The one-time move** (only if `settingsOwn` is not set):
- **Where it looks:** Android reads Prism's files itself, in the app's files folder, then its cache and
  code-cache folders (Dart's temporary folder, Prism's fallback).
- **Each value,** exactly as Prism worked it out:
  - `prism_floating`, `prism_side_spots` (clamped to 0–36 and 8–40, as Prism's own clamps);
  - Labels: `prism_blob_names_side`, else Prism's `prism_blob_names`;
  - Icons: `prism_icons_blobs` (the shared one);
  - Look: `prism_side_look` if not empty, else Prism's `prism_blob_look`, with builds 134–138's old Vivid
    looks read as Prism reads them;
  - Colours: `prism_side_vivid`, else Prism's `prism_blob_vivid` (or vivid from those old looks).
- **Saved** with `commit()` before anything else happens.
- **The recorder line:** "Sidekick settings moved from Prism, and kept here from now on: …", with every
  value and every file it read and where. On a phone with no files: "nothing (the defaults)".
- **Then:** Prism hears `moved` in Android's answer and deletes its five old Sidekick files, in both
  folders.
  - Prism's own Labels, Colours, Look and Icons files stay: they are Prism's.
  - The move doesn't run again, whatever is on disk.

**Prism's copy:**
- **Asked for** once Prism's shell is up (`sidekickSettings`). Both ends write it in the recorder:
  - Android: "Prism #n asked for them".
  - Prism: "Prism #n: Sidekick settings asked: …", with every value.
- **Every change** from the panel's Sidekick part goes to Android (`sidekickSet`):
  - Android puts it in force, saves it, writes "Sidekick settings changed by Prism's panel: …", and
    answers with all of them.
  - Prism takes the answer as its copy and writes "Sidekick settings changed: …".
- **A slider being dragged** is put in force at once but not saved (`keep: false`), as before. Let go,
  it is saved.
- **Away from a phone** (the preview), the copy shows what Prism last did to it. The SETTINGS line
  then says "not told yet".
- **The SETTINGS lines** in every test report now read the copy: "Sidekick (kept by Android): in Prism
  …, over other apps …, distance …, tucked …, labels …, icons …". Prism's own labels have a line of
  their own.

**What Prism still uses the copy for:**
- `canFloat`: a blob dragged onto Prism's button floats only if something may;
- the panel's Sidekick part;
- the SETTINGS lines.

## 2. The Icons split

- **Before:** one file, `prism_icons_blobs`, decided Prism's blobs and the Sidekick's pictures.
- **Now:**
  - The panel's Icons picker shows and sets Prism's own in Prism's part, and the Sidekick's own in the
    Sidekick's part.
  - The Sidekick's pictures are drawn in its own choice (`_blobMap(…, prismIcons:)`).
  - When it is Regular, the apps' own icons are held (`Apps.sideOwnIcons`), as they are when Prism's
    own is.
  - Changed, the Sidekick's pictures are sent again.
- **Not as in the plan:** the plan said Android would draw Regular icons itself. I kept Prism drawing
  them, in the Sidekick's choice, through the same one-way pictures as today. That makes them exactly
  what they were, which this build promises. Android drawing them can come with the Sidekick's own app
  list (step 3), if wanted.

## 3. Prism's panel colours

- **What is sent:** surface, raised surface, hairline, ink, muted ink, faint ink, accent and
  on-accent, for light and for dark. Plus which of the two is in force: 17 numbers.
- **When:** whenever they change (at start, and when the theme or the look changes), in the same place
  Prism already sends the Sidekick its accent.
- **On Android:** kept, saved, and written in the recorder when they change.
- **Nothing uses them yet:** they are for the Sidekick's own panel.

## 4. The keyboard measurement (test only)

What it measures, and how. It runs in the button test's part 5, after the Sidekick's settings:

1. **The keyboard comes up.** A small text field appears under the test banner (`Diag.typingShown`),
   and Prism gives it the focus. Android brings up the keyboard for it, as for any app's field. Prism
   waits up to 3 s for the keyboard (its window's bottom inset above 0). If it doesn't come, both probes
   are SKIPPED with that reason.
2. **A, the control.**
   - Android adds a 2 × 2 pixel, see-through window over everything for 2 s that never takes the focus
     (`FLAG_NOT_FOCUSABLE`). That's how the Sidekick's menu is made today.
   - The keyboard must stay up. This is a check, right or wrong: if it fails, the measurement itself
     can't be trusted.
3. **B, the candidate.**
   - The same window, but one that takes the focus and can never type (`FLAG_ALT_FOCUSABLE_IM`, given
     the focus with `requestFocus`). That's the kind of window that would hear Back.
   - This is a measurement, not a check: it is written down, and "measured" counts as right.
4. **Read from both sides,** during each probe.

| Who reads | What | When |
|---|---|---|
| Android | whether the keyboard is up on Prism's window, and how tall (`WindowInsets.Type.ime()`, Android 11 and later) | before, at 250, 500, 1000, 2000 ms, and 600 ms after the window has gone |
| Android | whether Prism's window has the focus (`hasWindowFocus`) | the same |
| Android | whether the keyboard is still connected to Prism's field (`InputMethodManager.isActive`) | the same |
| Android | whether the probe window got the focus | the same |
| Prism | how tall the keyboard is on its own window | every 100 ms |
| Prism | whether Prism was told it lost the focus (`inactive`) | every 100 ms |
| Prism | whether its field still had the focus | at the end |

5. **In the report:** one note per probe, starting "KEYBOARD PROBE A" or "KEYBOARD PROBE B". Each note
   gives the Android version and Prism's own reading: the keyboard up the whole time, or down at n ms;
   the focus kept or lost; the field kept or lost. Then every one of Android's readings. The same goes
   into the flight recorder.

**What it decides (as agreed):**
- **B keeps the keyboard up and connected:** the Sidekick's panel is B. Back closes it.
- **B loses the keyboard:** the panel is A. Back goes to the app underneath.

**What it doesn't measure:**
- whether typing would still reach the field while B is up (nothing types in the test);
- how other apps behave when they lose the focus. Prism is "the app underneath" here, so it shows what
  Android does with the keyboard, not what every app does with losing the focus.

## 5. The button test's new checks (part 5, phone only)

While the Sidekick's part of the settings is open, after the distances:
- **"kept by Android, moved over from Prism once":** Android's state has `moved`, written into the
  check.
- **"the distances just put back are kept by Android":** Android's `gap` and `tuck` equal what the test
  put back.
- **Labels, Icons, Colours,** each in turn:
  - changed with its picker: Android has the new value, Prism's copy has it, and **Prism's own
    choice hasn't changed**;
  - changed back: Android and the copy have it again.
- **Look:**
  - another look tapped: Android has it, the copy has it, Prism's own look hasn't changed;
  - its own put back.
- **"Prism's panel colours have reached Android":** at least 16 colours kept.
- **The two keyboard probes** (§4).
- **Missing answers count, as LESSONS.md says:** if Android doesn't say what it keeps, each check is
  SKIPPED with that reason, never ok. A picker that can't be found is WRONG. Pickers out of sight are
  scrolled into sight first.
- **The existing checks** for the two switches and the distances now run through Android without any
  change to the checks themselves.

## Where I could be wrong

1. **The move might read the wrong values, or none.**
   - Prism wrote its files from Dart, at `Directory.systemTemp.parent/files` (or the temporary folder).
     I expect that to be Android's `filesDir`, but haven't seen it on the phone.
   - If it isn't, the Sidekick comes up with the defaults: both switches on, distance 8, tuck 22, labels
     on, Prism icons, mellow, the first look. The owner would see a changed Sidekick.
   - The recorder line says exactly which files it found and where. Please send the flight recorder with
     the first report.
2. **Prism's copy before Android's answer.**
   - Until Android answers, the copy has the defaults. Prism uses it for `canFloat` and for the panel.
   - If the answer were lost, a panel opened at once could show the defaults, and a blob dragged onto the
     button could float when floating is off. Android's own values would still be the right ones.
   - The recorder shows the "asked" line. The button test reads Android's state directly.
3. **The keyboard probe may not be what the panel would do.**
   - A 2-pixel window given the focus by `requestFocus` may behave differently from a full panel
     window that a finger has touched. (The old pinned sheet in `MainActivity` is a real window that
     takes the focus, but without "can't type", and it was never measured with a keyboard up.)
   - If B keeps the keyboard here, the panel's first build should repeat the measurement with the panel
     itself.

## Results (preview, on the final code)

```
button test:  CHECKS: 68 right, 1 wrong, of 69
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(...))]
long test:    CHECKS: 65 right, 4 wrong, of 69 (the usual 4, on its first run)
  WRONG  app list: the flick wakes neither the magnifying glass nor a card
  WRONG  Home, nothing open / blobs out / app list open: measured  [no answer (MissingPluginException(...))]
```

- **The preview's SETTINGS line** reads "Sidekick (kept by Android, not told yet): in Prism on · over
  other apps on · distance 8.0, tucked 22.0 · labels on · icons Prism". No Android there, so no answer.
- **Analyser:** the same 4 old notes. `dart format` clean.
- **Kotlin:** compiles.

**Build 176:** `Prism build 176`, `0.137.0+204`, built from the final code. NAME-OK. The move's and the probe's
recorder lines are in its `classes.dex`, and "KEYBOARD PROBE" is in its `libapp.so`. sha256
`47d331b087f3cc83ad5e02b10d3d2f5b4d37a7d3d35898dd6d74df4b05ec0743`, 18,649,338 bytes. Link: https://github.com/vikac995/vikac/raw/dedd41ef1734f78dc090145903e24d75d726426e/lumen/releases/prism-build-176.apk
(pinned to `dedd41e`, the commit that added the APK). Checked after the push: it answers 200, and the
downloaded file has the same sha256 as the one built.

## For the owner on the phone

1. **Install 176.** Your Sidekick should look and sit exactly as before. If anything about it has
   changed (labels, look, colours, where it rests), say so: the move got something wrong.
2. **Run the button test** and send the report, then the flight recorder.
   - In part 5 a small text field appears under the banner, and the keyboard comes up for about 10
     seconds. That is the measurement. Leave it alone.
3. **Change something in the Sidekick's part of Prism's settings**, close Prism fully from the recent
   apps, and open it again. It should still be as you set it: the Sidekick keeps it now.
