# Step 2a fix report: two regressions in the Sidekick half (build 177)

Brief: `tasks/STEP2a-fix.md` (saved as given). Branch `claude/flutter-ui-showcase-ngzfru`, based on
`a3b5072`. Fixes only: no panel UI.

**What has only run in the preview:**
- **Fault 1:** a copy of the layout code in Python, at every height.
- **Fault 2:** the test's own Dart code is compiled, and the parts that need no Android ran. The
  Sidekick half didn't run: the preview has no Android.

**Nothing in this build has run on a phone.**

## Files changed

| File | What changed |
|---|---|
| `android/.../MainActivity.kt` | The Sidekick menu's `at()`: the nearest blob (or name) wins. `testLayout()`, and the test driver's `hold` answers with it. |
| `lib/fit/shell.dart` | The test's `closePanel()`: brings the ✕ into sight, checks that the panel closed, and closes it if not (WRONG). After the settings checks, the panel is scrolled back to the top. The blob-hold check's note carries the layout. `_showFloating`'s close: the Sidekick is shown again unless another panel is open. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 177, `0.138.0+205`. |
| `tasks/STEP2-plan.md`, `PRISM.md` | Back decided: A. PRISM.md's Back table has its row. |
| `tasks/STEP2a-fix.md` | The brief. |
| `CHANGELOG.md`, `HANDOVER.md` | Build 177; the fuse note for step 4. |
| `releases/prism-build-177.apk` | The build. |

## Fault 1: a hold on blob 1 brought blob 0's small menu

**What was found: a real fault, not the test's coordinates.**
- **What the test does:** it holds exactly at blob 1's middle, as Android itself reports it
  (`testSpot(1)` is `restX[1]`, `restY[1]`). So the touch was on blob 1.
- **What picks the blob:** the menu's hit test (`at()`) went through the blobs in order and returned
  the first one "near enough": within 40 points of its middle, or on its name, which is a box
  reaching 62 points below it.
- **Where that goes wrong:**
  - The fan (`fan()`) tries up to 88° each way to fit all five blobs on the screen. It can't when the
    Sidekick rests near the top or the bottom.
  - Then `seats()` clamps the blobs to the screen's margins, and neighbours come close. Blob 1's middle
    can then sit inside blob 0's name box, or within 40 points of blob 0.
  - So blob 0 won.
- **The proof:** I copied `fan()`, `seats()` and `at()` into Python and tried every height, every 10
  points, on both sides, with labels on and off, for a 384 × 832 and a 412 × 915 point screen.
  - **The old hit test:** about 50 Sidekick heights out of about 180 where a hold on a blob's middle
    picked another blob. That's within about 120 points of the top, or 130 of the bottom. Always blob
    1 or blob 4: the ones next to the ends.
  - **Nearest wins:** none, at any height.
- **Why it showed in 176 and not before:** nothing in 176 changed the fan or the hit test. The test
  doesn't place the Sidekick: it opens it wherever it was last left.
  - My reading is that the Sidekick sat near the top or bottom for this run. Each round then brought it
    back to the same place, hence 4/4.
  - **Not verified:** the 176 report doesn't give its height. From 177 the check's note says where the
    Sidekick was and where every blob sat, with the blob each spot gets.
- **The other wrong lines all follow from it:** Remove took blob 0; Prism was told the keys with blob
  0 gone; Change asked for place 0.

**The fix** (`at()`): every blob whose middle or name the finger is on is a candidate, and the nearest
one wins. Distance is measured to the blob's middle, or to where its name is drawn, 50 points below.
- Nothing about how it looks or moves changes.
- A finger exactly between two blobs gets the nearer one, as you'd expect.

**Not fixed, for a mock-up:** near the corners, clamped neighbours can come within about 15 points of
each other, almost on top of each other. How the fan should look there (smaller, flatter, or turned
further) changes what the owner sees, so it waits for design.

## Fault 2: Prism's settings left open after the new checks

**What was found: the test's own doing.**
- **Why the panel scrolls:** the Sidekick's part of the settings is taller than the screen, so it
  scrolls. 176's new checks scroll it down to the six looks (`Scrollable.ensureVisible`) to tap one.
- **What that did:** the ✕ and the Prism | Sidekick picker went out of sight, above the panel's
  visible part.
- **Then two taps aimed at them:** the tap on Prism | Sidekick, and `closePanel()`'s tap on the ✕.
  Both landed where those controls had been scrolled to: on the panel's own padding and background,
  which takes the tap and does nothing.
- **So the panel stayed open** and the Sidekick stayed hidden under it. Every check after it found no
  lens.
- **"Under Prism's own settings it is hidden" was ok for the wrong reason:** the tap missed, but the
  Sidekick was hidden anyway, under the Sidekick's own settings.

**The fixes, in the test:**
- **After the settings checks,** the panel is scrolled back to the top (Prism | Sidekick in sight)
  before Prism | Sidekick is tapped. That check now tests what it says.
- **`closePanel()`** (used everywhere, the leak test too):
  - it brings the ✕ into sight first, then taps it;
  - if the panel is still open after that, it is WRONG ("settings: their X closes them", with where it
    tapped), and the panel is closed directly;
  - so what follows always starts with nothing open (LESSONS.md: a known state).
- **The check count:** a ✕ that works adds no check line, so the counts stay as before when all is
  well.

**And in Prism, so that a real panel can't keep the Sidekick hidden after it closes:**
- When the settings close, Prism tells Android "covered" = whether any panel is still open.
- `PanelWatch` already did this when the last panel closed. The new line covers anything said while
  this one was open (`_sideInSight`, a slider let go) arriving out of turn.
- I found no path that left the Sidekick hidden after a real close. This is a safety net, not a fix
  for a seen fault.

## The test's own frames

**The bound holds.**
- **What is kept:** frames are kept only while a scene runs (`scene()` clears its working list when the
  last scene ends), and each scene keeps its own frames as the report's data.
- **Why it still grows:** "0 → 7632" over 4 rounds is each round's scenes, about 1,900 frames a round
  on the phone.
- **What it means:** it grows with the number of rounds, by design, and nothing else adds to it.
- **Its size:** a frame's timing is about 100–150 bytes, so 7,632 frames are about 1 MB of Dart memory.
- **The native 9 MB a round is something else:** frames are Dart objects, not native memory.

## Where I could be wrong

1. **I haven't seen the Sidekick's height in 176's run.** If it was mid-screen, my mechanism isn't what
   happened there, and something else picked blob 0. 177's check note will show the height and the
   layout either way.
2. **Nearest wins could pick a different blob from the old code** where a finger is on one blob's name
   and very near another blob's middle. A touch on the name area now goes to whichever is nearer. That
   is what a person would expect, but the test only holds blob middles.
3. **A fixed `closePanel()` could hide a real fault.** If the ✕ failed in real use, the test now closes
   the panel directly after recording WRONG. The WRONG line still says it failed, so it isn't hidden.
   But everything after it passes as if nothing happened.

## Results (preview, on the final code)

```
button test:  CHECKS: 68 right, 1 wrong, of 69
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(...))]
long test:    CHECKS: 65 right, 4 wrong, of 69 (the usual 4, on its first run)
  WRONG  app list: the flick wakes neither the magnifying glass nor a card
  WRONG  Home, nothing open / blobs out / app list open: measured  [no answer (MissingPluginException(...))]
```

- No "settings: their X closes them" line in either: every ✕ the preview's tests tapped closed its
  panel.

- **Analyser:** the same 4 old notes. `dart format` clean.
- **Kotlin:** compiles.

**Build 177:** `Prism build 177`, `0.138.0+205`, built from the final code. NAME-OK. "their X closes
them" is in its `libapp.so`, and its Android code differs from 176's (the only Kotlin change is the hit
test and its test line; method names are shortened in a release build, so they can't be searched for).
sha256 `d6c9fbc3809c95525f92985214b13b01eb7eb9e0c53e1de661ee6aad67a8da61`, 18,649,338 bytes. Link:
LINK_RESULT

## For the owner on the phone

1. Install 177.
2. Run the button test and send the report, then the flight recorder.
3. If you can: put the Sidekick near the top of the screen, open its blobs, and hold the second one. Its
   own small menu (Change | Remove | Add) should come up beside it.
