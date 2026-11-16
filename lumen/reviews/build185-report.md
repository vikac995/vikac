# Build 185 report: the Sidekick's panel, simplified

Brief: `tasks/BUILD185.md` (the review chat's go, 15:07). The owner approved "New" from the mock-up
(https://claude.ai/artifact/SQYPHqVTK9WL2wjRXjnL1M).

- **The one behaviour change:** the Sidekick's panel.
- **Batched polish:** the carried magnifying glass is always at full quality.

**Only the preview has run it.** The panel is Android's, so it isn't in the preview, and none of its new
checks can run there.

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickPanel.kt` | The shade is gone. The panel's width, height and place are new (`layoutBox`), and it follows the Sidekick (`follow`). In `onDraw`, its body and contents never draw over the Sidekick's glass (a hole is cut out); it fades while small, and is half see-through while a dial is held. Records of what it drew. The stand-in is no longer drawn. Gestures that begin on the Sidekick are handed to it. New test state, and a new `testSample`. |
| `android/.../MainActivity.kt` | The Sidekick's touch with its panel open: a drag is now a drag (`pressAt`, the down's work from where the finger came down); a tap still closes the panel. `touchLens()`. Test ops `panel`/`gap` and `panel`/`dragLens`. |
| `lib/fit/shell.dart` | The carried glass is at `GlassQuality.full`. Part 5's panel checks are rewritten for the new rule. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 185, "The Sidekick's panel, simplified", `askedTest = 'button'`; `0.146.0+213`. |
| `DESIGN.md` | §6 (the Sidekick's panel) and §7 ("Seeing what you change"): the new rule. |
| `tasks/BUILD185.md`, `CHANGELOG.md` | The brief; build 185. |
| `releases/prism-build-185.apk` | The build. |

## What changed, point by point

1. **No shade.**
   - `onDraw` no longer draws the 40% layer with the hole. Nothing is drawn round the Sidekick or the
     panel.
   - `panelShade` is always 0, kept so the test can say so.
2. **Width and place** (`layoutBox`):
   - **Width:** the screen less 8 points at the far edge, less the Sidekick's furthest reach. That reach
     is `GAP_MAX` (36) + its window (its glass and 5 points round it, about 84) + 8 to spare. On a
     411-point screen that's about 275 points, worked out from the screen each time.
   - **A floor:** never under 250 points. Three looks in a row need about that. On a screen narrower
     than about 386 points, the furthest Hovering can then reach the panel's edge.
   - **Side:** the far side from the Sidekick.
   - **Height:** as tall as its contents, centred on the Sidekick's height and kept on the screen.
     - The contents are about 834 points tall, taller than either phone allows (745 and 779).
     - So on both phones the panel fills the height and scrolls, as before, and can't move up or down.
     - On a taller screen, or with less in it, it sits at the Sidekick's height.
   - **While a dial changes Hovering,** the panel is laid out again, and comes out the same: its width
     depends only on the screen and the Sidekick's size, so it stays put.
3. **Dragging the Sidekick with the panel open.**
   - A gesture that begins on the Sidekick (within its glass + 6 points) is handed to the Sidekick
     whole, as the grip hands on its touches (`touchLens`).
   - The Sidekick decides:
     - **a tap** (under 14 points of movement) closes the panel, as today;
     - **a movement of more than 10 points** becomes a drag. It's picked up where the finger came down
       (`pressAt`, the same work as a normal touch-down) and moves as at any other time.
   - **The panel follows:** each move of the Sidekick tells the panel (`lensChanged` → `follow`), which
     lays itself out again: up and down, and to the other side if the Sidekick crosses the middle.
   - **When let go,** the Sidekick does what it always does: it settles at the nearer side. Dropped on
     the cross, it's dismissed, and the panel closes.
4. **Half see-through while a dial is held.**
   - The panel's body and contents are drawn at `1 − 0.5 × clear`, on the `clear` spring (effects,
     1600, ζ 1), which is the one that lifted the shade before.
   - It's 0.5 while a finger is on a dial and 1 after. Nothing else changes.
5. **The Sidekick visible on every frame, opening and closing.**
   - **The choice:** of the options in the brief, the simplest that doesn't depend on anything unproven
     is a hole. The panel always cuts out a circle the size of the Sidekick's glass (`clipOutPath`,
     radius `sr`). So the Sidekick, in its own window under the panel's, shows through on every frame:
     - opening, open and closing;
     - while dragged across the panel;
     - including the moment the panel passes its edge.
   - **The stand-in is no longer drawn.** Its code paths are gone; the Sidekick's `drawLensInto` stays
     but is unused.
   - **No dark box:** while the panel is small, it fades (`smooth(open / 0.4)`, nearly clear below 15%
     open). So the panel's corners round the Sidekick, as it starts out of it or ends in it, are never
     a dark box.
   - **The records inside `onDraw`:** every frame counts itself (`draws`) and keeps its rectangle, the
     glass radius, whether it lay over the glass (`covers`), and how faded it was. They're in the test
     state as `panelDraws`, `panelRect`, `panelSr`, `panelCovers` and `panelFade`, and in each sample.
6. **The carried magnifying glass** is now `Glass(quality: GlassQuality.full)`, whatever the glass
   quality setting or Auto's level. `Glass` still makes it solid when Android's "reduce transparency"
   is on.

## The tests (part 5, Android only)

**Retired:**
- "where it covers the Sidekick, the panel draws the Sidekick (its stand-in)";
- "open, the panel never hides the Sidekick".

**Reworded:**
- "it ends before the Sidekick's furthest Hovering spot, on the side away from it": its width within 2
  points of the rule, and it doesn't reach the glass;
- "no shade: nothing is drawn around the Sidekick or the panel";
- the 1.5 s check: no shade;
- "<dial> touched, the Sidekick goes there, the panel half see-through": `panelAlpha` within 0.08 of
  0.5;
- "<dial> let go, the panel is solid again, the Sidekick as it was": over 0.97.

**New:**
- **"growing, shrinking and open, the panel never draws over the Sidekick's glass"**
  - **How:** the panel is drawn in software at 3, 6, 12, 25, 50, 80 and 100% open (closing passes
    through the same moments) into a picture of the glass and a little round it.
  - **The rule:** at every moment, the panel must have been drawn (`sampleDraws` ≥ 1), and draw nothing
    at the glass's middle and nothing (≤ 8 of 255) at 16 points round it.
  - **The report:** each moment is written in words, with "just beside" (where the panel is) as a
    control.
- **"at Hovering 0, 18 and 36, the panel never reaches the Sidekick's glass, and stays put"** (via
  `panel`/`gap`, then put back).
- **"dragged by hand with the panel open, the Sidekick moves and the panel follows it"**
  - **How:** a 120-point drag up, through the panel window (`panel`/`dragLens`), then back.
  - **Pass:** the panel stays open, and the Sidekick moves within 40 points of that.
  - **The panel:** follows within 30. If it's as tall as the screen allows (as on both phones), it may
    stay where it is.
- **Test area:** badge 185, `askedTest = 'button'`.

## What "processor" means in "THE GLASS, MEASURED" (asked for in this report)

- **The calculation:** the change in `android.os.Process.getElapsedCpuTime()` over a stretch, divided by
  the stretch's wall-clock time, times 100. `getElapsedCpuTime()` is the CPU time of every thread in
  Prism's process (UI, raster, platform, Dart).
- **So it's the whole process, measured against one core.** On the S26, 82–90% means Prism used about
  0.8–0.9 of one core's worth while things scrolled. The phone has 8, so that's about 11% of the chip.
- It can go over 100% when several threads are busy at once.

## Results (preview, on the final code)

```
button test:  CHECKS: 80 right, 1 wrong, 1 skipped, of 82 (the same as 184: the panel's checks run only on a phone)
long test:    CHECKS: 62 right, 4 wrong, of 66 (the usual 4)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.

**Build 185:**
- `Prism build 185`, `0.146.0+213`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- Its `classes.dex` has `panelAlpha`, `dragLens` and `sampleRing`. Its `libapp.so` has "Prism build
  185" and the no-shade check.
- sha256 `27acb58c62315d4b77d764f30994a97da0307f1e67197ed060bd64fb3991bfdd`, 18,797,002 bytes.
- Link (checked: answers 200, same sha256): https://github.com/vikac995/vikac/raw/e8004671187d862c395baea6f55bb6931194f7be/lumen/releases/prism-build-185.apk

## Where I could be wrong

1. **None of this has run where it matters.** The panel is Android's, and the preview can't show it.
   The first phone run proves or disproves each point.
2. **The hole's edge.** `clipOutPath` with a circle may not be smoothed on every phone's GPU. If its
   edge looks jagged against the Sidekick's glass, a soft-edged mask is the next step.
3. **The sample may hide the same mystery as 183/184:** its software drawing came out unlike the phone's
   own. This time `sampleDraws` shows whether the panel's `onDraw` ran at all inside the sample. If it
   says 0, the problem was in how the test draws the panel, never in the panel.
4. **A drag that crosses the middle** makes the panel jump to the other side while the finger is still
   moving. It never covers the Sidekick, but it's a jump. If it looks wrong, the panel could wait for
   the Sidekick to settle before changing sides.
5. **The panel can't follow up and down on these phones,** because it's taller than the screen allows.
   The owner will only see it follow if it gets shorter, for instance after the settings cleanup.

## On the phone

**What to look at:**
- No dark layer when the Sidekick's panel opens.
- The panel narrower, never reaching the Sidekick, even with Hovering at its furthest.
- The panel half see-through while a dial is held.
- The Sidekick never covered while the panel opens or closes.
- The Sidekick can be dragged with its panel open.

**In the button test's report:** the NOTES give each sampled moment of the panel in words.
