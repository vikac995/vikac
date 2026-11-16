# Step 2b fix 2 report: the test's two misses, and no blink (build 181)

Brief: `tasks/STEP2b-fix2.md`. Branch `claude/flutter-ui-showcase-ngzfru`, based on `db6a14f`. Exactly the
three items. The panel's place, size and look are untouched.

**What has only run in the preview:** the Prism side; the button test's part 5 doesn't run there. The
stand-in is Android's: compiled, not run.

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickPanel.kt` | No raise. `standIn()`: while the panel's rectangle covers the Sidekick, it draws the Sidekick's own drawing over itself, with recorder lines "stand-in drawn" and "stand-in stopped". A touch in the hole is "a tap on the Sidekick". `lensChanged()` redraws the panel when the Sidekick redraws or moves. Test: `panelHole`, `panelStandIn`, `panelStandIns`, and `testSample`. |
| `android/.../MainActivity.kt` | Removed: `raise()`, `raiseWhenUp`, `raisedFor`, `raisedAt`, `fingerOn()`, the Dot's `raising`, the 400 ms guard. New: `drawLensInto()`. The Dot's `onDraw` tells the panel, and doesn't count its frame when drawn as the stand-in. Every `updateViewLayout` of the Dot tells the panel too. `lensAdds` and `lensRemoves` count its window. The test op `panel`/`sample`. |
| `lib/fit/shell.dart` | Part 5's fresh baseline; "the Sidekick at its spot, its window never taken off"; the stand-in pixel check; `seenTap` (on screen or WRONG) for Bring back and the list's first choice; Bring back scrolled into sight first. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 181, `0.142.0+209`. |
| `tasks/STEP2b-fix2.md`, `CHANGELOG.md` | The brief; build 181. |
| `releases/prism-build-181.apk` | The build. |

## 1. The test's baseline

- **Before:** `forwardsWas`, `wasTucked`, `closedWas` and `openedWas` were read from a state taken before
  the Change/Add round trips.
- **Why that miscounted:** the round trips bring Prism forward on purpose, 4 times plus the closing
  `front`. That's the 5 forwards in 180's report.
- **Now:** `s = await where()` comes right before them. The window counters (`lensAdds`, `lensRemoves`) are
  read there too.

## 2. Bring back, and taps that could land off the screen

- **Bring back:** the line is brought into sight (`Scrollable.ensureVisible`, centred), then tapped
  through `seenTap`.
- **`seenTap`:** taps only if the point is on the screen. Otherwise it records "WRONG: … on the screen to
  be tapped: off screen at x,y (the screen is w × h)".
- **Part 5's other taps, looked through:**
  - The button (`_home`) is always in sight.
  - The list's first choice (`choice0`, three places) now goes through `seenTap` too.
  - The panel's own parts are tapped by Android, which scrolls them into sight first (`testSpot`).
  - Prism's settings panel's ✕ goes through `closePanel()`, which already scrolls it into sight (177).

## 3. No raise: the stand-in

**How:**
- **The Sidekick's window is never touched for its panel.** No `removeViewImmediate`/`addView`, so
  there's no blink and no lost touch.
- **Beside the open panel,** the Sidekick shows through the shade's hole (it already followed the
  Sidekick).
- **While the panel's rectangle covers the Sidekick,** at the end of each of the panel's frames
  `standIn()` calls the Sidekick's own `draw(canvas)`. That's while it grows out of the Sidekick, goes
  back in, or, on a narrow screen or at a large Hovering, lies over it. The drawing is placed at the
  Sidekick's place on the screen, with its scale and alpha. Recorder: "Sidekick: stand-in drawn (the
  panel covers it, n% open)" and "… stopped (… is clear of it)".
- **Kept in step:**
  - each time the Sidekick draws (its sign turning, a badge changing, its tuck), it asks the panel to
    draw again;
  - each time its window moves (`updateViewLayout`), even without drawing, the same;
  - drawn as the stand-in, it neither counts that frame nor asks again (no loop).
- **Touches:** the panel's window is above the Sidekick's, so a touch at the Sidekick's spot reaches the
  panel: within the Sidekick's radius plus 6 points, it is "a tap on the Sidekick" and closes it. The
  dials still move the real Sidekick, and the hole and the stand-in follow it.
- **The 400 ms guard and every raise field are gone:** nothing else used them.

**What the stand-in copies, and what it can't:**
- **Copied:** the Dot is drawn with plain Canvas calls (paths, gradients, shadow layers, its own
  `saveLayerAlpha` for fading in). Its window shows it with a scale, a pivot of its own and an alpha (its
  press and come-in animations). The pivot is in the place `getLocationOnScreen` gives, so translating
  there and scaling copies its transform exactly.
- **Nothing it can't:** it uses no `setLayerType`, `RenderEffect`, elevation, outline clipping, rotation
  or window alpha, so there's no layer or RenderNode effect the stand-in would miss.
- **Two limits:**
  - The stand-in is drawn in the panel's window, under the panel's own frame timing. If the Sidekick
    animated on its own while covered, the stand-in would be redrawn on the panel's next frame, at most
    one frame later.
  - The real Sidekick is still there underneath, so where the panel's surface is see-through (never, in
    this solid panel) both would show.

## 4. The new checks

- **"Still open 1.5 s after the hold is let go, never closed, the Sidekick at its spot, the panel
  unchanged":** the 1.5 s check, with `lensAbove` replaced by two things:
  - its window was never added or taken off (`lensAdds` and `lensRemoves` unchanged since just before
    the hold);
  - the shade's hole is at the Sidekick's middle, within 4 points, and the Sidekick is shown.
- **"The Sidekick stays in sight at its spot, its window never taken off":** the same two, in the
  opening's checks.
- **"Where it covers the Sidekick, the panel draws the Sidekick (its stand-in)":**
  - The test op draws the panel as it is 12% open (a moment of its growing, when it covers the Sidekick)
    into a 3 × 3 software bitmap at the Sidekick's middle, three ways: with the stand-in, without it,
    and the Sidekick alone.
  - The check: the first differs from the second and matches the third (each channel within 24).
  - SKIPPED, with why, if that moment doesn't cover the Sidekick, or if the Sidekick's middle happens to
    be the panel's colour (then it can't tell).
  - It doesn't touch the screen, and leaves the panel as it was.

## Where I could be wrong

1. **`View.draw()` into another window's canvas.** I expect the Sidekick's plain Canvas drawing to copy
   exactly. But I haven't seen it on the phone's GPU. The pixel check reads a software drawing, not the
   screen. If the stand-in differed on screen, the owner would see the Sidekick change for the moment
   the panel grows.
2. **Touches at the Sidekick now reach the panel first.** That's intended: a tap closes the panel. But a
   finger that starts a drag on the Sidekick while the panel is open now does nothing, where before it
   would have reached the Sidekick and also done nothing. Same result, different window.
3. **The hole and the stand-in follow the Sidekick only when it draws or moves its window.** If it ever
   changed place another way (none that I found), the hole would lag until its next frame.

## Results (preview, on the final code)

```
button test:  CHECKS: 67 right, 1 wrong, of 68
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(...))]
long test:    CHECKS: 62 right, 4 wrong, of 66 (the usual 4)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.

**Build 181:** `Prism build 181`, `0.142.0+209`, built from the final code. NAME-OK. "stand-in" is in
its `classes.dex`, and "put above its own settings panel" no longer is. sha256
`f2272d8db0b5780b85af589f266c7518353e0419c2ec288ea38d8dbd005e66e1`, 18,665,722 bytes. Link (checked: answers 200, same sha256): https://github.com/vikac995/vikac/raw/8db28c07a2a73f2461f093f0eeb8435240d2370c/lumen/releases/prism-build-181.apk

## For the owner on the phone

1. Install 181.
2. Hold the Sidekick, let go, and watch the Sidekick while the panel grows and stays: no blink, no halo,
   nothing redrawn. Close it with the ✕ and watch it go back in.
3. Run the button test on both phones and send the reports.
