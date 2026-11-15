# Step 1e report: the leak test (build 174, test only)

Asked for by the review of build 173's phone run (485 of 485, one engine). Branch
`claude/flutter-ui-showcase-ngzfru`, based on `43ffe04`. Two commits: `531ea68` (the code, the APK, the
changelog, the handover, this report) and the one after it, which only adds the checked link here. Step 2 not started. **No change to how Prism
behaves:** every change is in the tests, the test report or the testing panel's list of runs.

**What has only run in the preview:** everything. Nothing in this build has run on a phone. In the
preview the leak test runs, but only its "process" column has numbers (no Android: no native,
after-gc or graphics readings), its step f is left out (Prism may not float there), and it draws in
software, not on the phone's GPU.

## Files changed

| File | What changed |
|---|---|
| `lib/fit/shell.dart` | `_longTest(leak: true)`, the leak test (steps a–f and the four variants, restored in the test's `finally`); `Diag.leakTest`; the testing panel's "Run the leak test (about 8 min, hands off)"; `PRISM_LEAK_TEST` for the preview; the report header says no "0 rounds" for it. |
| `lib/fit/long_test.dart` | `leakRows` and the LEAK TEST table. The frame list is bounded: frames are kept only while a scene is recorded, phases count with a running total. `framesKept` counts what is held. |
| `lib/fit/diag.dart` | `leakTest`; `Prism build 174`. |
| `pubspec.yaml` | `0.135.0+202`. |
| `tools/preview/test.sh`, `README.md` | `test.sh leak`. |
| `CHANGELOG.md`, `HANDOVER.md` | Build 174 entry; the leak test. |
| `releases/prism-build-174.apk` | The build. |

## 1. The leak test

- **How it runs.** It is a mode of the existing test (`rounds: 0, leak: true`), so it has the same
  set-up, banner and Stop button, and the same restore at the end.
- **Each step:** everything closed; the step's set-up; a reading; the step 20 times, with a reading
  after every 5; the step's tidy-up.
- **A reading** is the `memory` step with collection: native, native after Java's collection,
  graphics, Java, total, plus Prism's own `ProcessInfo.currentRss`.

| Step | Set-up | Done 20 times | Tidy-up |
|---|---|---|---|
| a. Prism's settings opened and closed | none | hold the button, tap the X | none |
| b. Labels Hide and Show, in the settings | settings opened | tap Hide, tap Show | X |
| c. Prism \| Sidekick and back, in the settings | settings opened | tap Sidekick, tap Prism (each half by its own key) | X |
| d. the app list opened and closed | none | flick up from the button (or opened directly if the flick misses), tap the button | none |
| e. the blobs opened and closed | none | tap the button twice | none |
| f. the Sidekick's blobs opened and closed, over Prism | the Sidekick shown | tap the Sidekick, tap beside its blobs | none |
| b, the glass solid | "reduce transparency" on, settings opened | as b | X, reduce transparency as it was |
| c, the glass solid | the same | as c | the same |
| b, the Sidekick switched off | "In this app" and "Over other apps" off, settings opened | as b | X, both on again |
| c, the Sidekick switched off | the same | as c | the same |

- **Restored either way:** the test's `finally` already puts back reduce transparency (`solidWas`) and
  where the Sidekick may float (`inWas`/`outWas`). So both are restored even if the test is stopped
  mid-step.
- **The progress line** reads "Leak test · step k of 10 · about n min left".
- **The table.** For each step, and for each of native, after gc, graphics and process, two numbers:
  - **"first 5 repeats":** MB added between the reading before and the one after 5 repeats. A first
    use makes things that are then kept once: fonts, shaders, layouts.
  - **"per repeat after":** MB per repeat from 5 to 20. A leak shows here.
- **Every reading** is listed under the table too.
- **Why two numbers:** in the first preview run, one "first to last" figure was dominated by
  warm-up jumps (+18 MB in the first five repeats, then flat).

**Preview run** (`tools/preview/test.sh leak`, 5 min 8 s; the phone will be slower per step,
hence "about 8 min" on the button):

```
step                                                       native       after gc       graphics        process
a. Prism's settings opened and closed                           -              -              -    +18 | +0.17
b. Labels Hide and Show, in the settings                        -              -              -  +8.08 | +0.64
c. Prism | Sidekick and back, in the settings                   -              -              -    +13 | -0.02
d. the app list opened and closed                               -              -              -    +16 | -0.64
e. the blobs opened and closed                                  -              -              -  -2.31 | +0.22
b, the glass solid (reduce transparency)                        -              -              -    -40 | +0.77
c, the glass solid (reduce transparency)                        -              -              -    +10 | -0.40
b, the Sidekick switched off                                    -              -              -    +25 | +1.07
c, the Sidekick switched off                                    -              -              -    +16 | -0.83
```

- **In the preview,** after the first five repeats no step keeps memory: the slopes are −0.83 to +1.07
  MB per repeat, both signs, with readings that wander ±5 MB. That's noise.
- **What this rules out:** a steady per-repeat leak in Prism's own Dart and drawing logic, as drawn in
  software.
- **What it doesn't say anything about:** Android's side, the phone's GPU drawing, and native memory
  as Android counts it. Those need the phone run.
- **No fix,** as asked: the cause isn't proven in the preview.

## 2. The test's own frame list, bounded

- **Before:** `TestRun._frames` kept every `FrameTiming` the test ever saw (25,652 by the end of 173's
  four rounds) only so that each scene could cut its own frames out of it.
- **Now:**
  - Frames are kept only while a scene is being recorded (from the moment the scene starts counting
    to the moment it takes its frames), then let go.
  - Every frame is still counted (`_counted`), and phases use that running count instead of the list's
    length. Their frame counts are the same as before.
  - Scenes keep their own frames, as before: those are the report's data (smoothness, the per-scene
    table, percentiles), so every number in the report is computed from exactly the same frames.
- **The CACHES table's "frames"** now counts what the test holds: the scenes' frames plus the scene
  being recorded.
- **In the preview** it stays at the scenes' 164 through part 4, where it was 459–500 before. The
  summary line says the same "164 frames".

## 3. What each step makes that lives outside Dart's own memory

From the code, to match against the phone's numbers. The deciding column is "native per repeat
after".

**a. Prism's settings opened and closed**
- **Flutter:**
  - A dialog route (`showGeneralDialog`) with `_SpringPanel`: a `Transform`, and an `Opacity` that is
    a layer (an offscreen texture: graphics) while the panel fades in and out.
  - The panel's content:
    - text for every label (each a native paragraph, freed when Dart collects its object);
    - icons drawn as text from the icon font;
    - four `Segmented` pickers with shadowed thumbs (blur);
    - the six look previews (`BlobSignPreview`: paths and gradient shaders made on each paint, not
      kept);
    - two switches and two sliders when the Sidekick is chosen;
    - the superellipse panel shape (paths).
  - No glass, `BackdropFilter`, `ImageFilter` or `FragmentShader` anywhere in the panel.
- **Android:**
  - Opening tells it the Sidekick is covered (`PanelWatch` → `covered`). The Sidekick's windows (the
    lens and its cross) are taken off the screen.
  - Closing makes them anew: two `WindowManager.addView`, each window with its own surface (graphics)
    and renderer (native, Android's own drawing).
  - The front-app listener is registered once only (`listenForFront` returns if it has one).
- **Not a leak:** `_designSide.addListener(_sideInSight)` on every opening is removed again when the
  panel closes (`whenComplete`).

**b. Labels Hide and Show**
- `BlobSlots.setNames`: a file write, then every listener.
  - `_blobsChanged`: a rebuild of the shell; `_sendPin` (one message); `_sendSidekick` (names, look,
    vivid and the Sidekick's pictures as PNG bytes, copied through native memory into Java on the
    way; Android decodes nothing again, the bytes being the same); `_reseat`/`_recentre` (springs).
  - The panel's builder, which listens to `BlobSlots`, so the whole panel content is rebuilt twice
    per repeat, with new text paragraphs.
- `_far.animateTo` (the blobs' distance), and `_tellFan` (a message; Android only stores it, Prism
  being allowed to float there).

**c. Prism | Sidekick and back**
- `_designSide` changes, so the panel content swaps between Prism's part (Icons picker, the four
  swipe blobs with icon text, Colours, Look) and the Sidekick's (two switches, two sliders, its own
  Look). That means new text paragraphs and widgets each time.
- The panel changes size: `_measure` → `setState` → a new transform.
- `_sideInSight` sends `covered` again. Android: its windows are already off, so nothing is done.

**d. The app list opened and closed**
- **Flutter:** the list's own drawing (`_GridPainter`: app pictures drawn from images already held;
  text from its caches, flat at 108+0+3 in 173's run; `saveLayer` for fading initials and pages).
- **Android, every opening:** `Apps.refresh()` → `names`: `queryIntentActivities` for every app, and
  `getPackageInfo` + `loadLabel` for each.
  - `loadLabel` loads that app's resources: native asset managers, which Android keeps in its own
    cache. That's about 150 apps on the owner's phone, every time the list opens.
  - Second suspect for d after the panels; the phone run will say.
  - (`icons`, which makes bitmaps, runs only for apps new or updated since the last time.)

**e. The blobs opened and closed**
- **Flutter:** five blob widgets (images already held, or icon text), the threads painter, the dim,
  and the button's sign (paths, gradients); springs.
- **Android:** `_tellFan` (stored). Nothing is made there.

**f. The Sidekick's blobs opened and closed, over Prism (Android only)**
- `openMenu`: a new full-screen `Menu` view in its own window. It has its own surface (graphics) and
  renderer (native).
- Its names' paint loads Prism's font, `Typeface.createFromAsset(…Inter.ttf)` (Android caches fonts
  made from assets), with a weight variation (`'wght' 650`) and a shadow layer.
- A close-system-dialogs listener is registered.
- Closing removes the window and unregisters the listener.

**What is common to the steps that grew in 173** (b, c, a's opening, part 6, and the app list less
so):
- They rebuild a lot of text and widgets in Prism's panel, and make Android remove and re-make the
  Sidekick's windows (a, and part 4/6's openings).
- The leak test separates the two: b and c with the Sidekick switched off remove Android's windows
  from the picture; b and c with solid glass remove the glass from the picture (the panel has none,
  but the pages behind it do).

## Noted for step 4, not done

- The review saw the recorder say "blob dropped on Prism's button: they fuse / floating workout:
  fused / unpinned" when the test dismisses the Sidekick at the bottom middle. The old fusion path
  (`fusing()` → `crossX/crossY` at Prism's button while Prism is in front) is still live.
- Left as is: this build changes no behaviour.

## Results (preview, on the final code)

```
leak test:    runs, 5 min 8 s (table above); CHECKS: 0 of 0 (it makes none)
button test:  CHECKS: 68 right, 1 wrong, of 69
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(...))]
long test:    CHECKS: 65 right, 4 wrong, of 69 (the usual 4: the flick timing check and 3 Android-only measurements)
```

- **The same results with the bounded frame list.** The button test's summary reads "164 frames",
  computed from the scenes' own frames as before.
- **Analyser:** the same 4 old notes. `dart format` clean.
- **Kotlin:** unchanged.

**Build 174:** `Prism build 174`, `0.135.0+202`, built from the final code. NAME-OK. "Run the leak test"
is in its `libapp.so`. sha256 `fe5b5a4fe40972cfb302751fb656bb3c64007f461fdab1010687558882556742`.
Link: https://github.com/vikac995/vikac/raw/531ea68c82a25c9340a0a3233441790a38d89659/lumen/releases/prism-build-174.apk
(pinned to `531ea68`, the commit that added the APK). Checked after the push: it answers 200, and the
downloaded file has the same sha256 as the one built.

## For the owner on the phone

1. Install 174.
2. In the testing panel, tap **Run the leak test (about 8 min, hands off)**. When it ends, copy the
   report and send it, then the flight recorder.
3. The button test is unchanged and doesn't need running again.
