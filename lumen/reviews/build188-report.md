# Build 188 report: the dials, and one menu at a time

Brief: `tasks/BUILD188.md`. The owner's feedback on 187 (videos 19:00, S25 probably, Prism in front),
from the review chat (18:05): "better but still not good". Built and pushed straight away; the owner
skips the full 187 test.

**Three changes, as asked:**
1. the dials vanishing while held (found by reading, fixed, and now checked by the pixels);
2. the dials' ticks overflowing their pills;
3. only one menu open at a time.

The Hovering range moves to 189, and dismissing at the top to 190 (the queue is renumbered).

**Only the preview has run it.** Everything Android draws or does (the panel, the Sidekick's menu)
runs only on a phone. The preview ran Prism's side, including its half of the menu swap.

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickPanel.kt` | The panel's outline in its own rectangle (`outline`), not the shared one the controls draw with: the fix for the vanishing dials. The ticks clipped to the pill's rounded outline, 10 points above its bottom and clear of its rounded ends; the pill grows at a large text size (`pillH`). `testPixels`: the section read from its pixels. |
| `android/.../MainActivity.kt` | One menu at a time: Prism is told when the Sidekick's menu or panel opens (`tellOpened`); a tap on Prism's button, caught by the Sidekick's open menu, closes it and is handed to Prism (`buttonTap`); Prism's blobs coming out close the Sidekick's menu. `guest` readable. Test: the press can read the pixels, a `pixels` step, the menu's `button` step, and counts in the state. |
| `lib/fit/bubble.dart` | `sidekickOpened` and `buttonTap` from Android. |
| `lib/fit/shell.dart` | Prism closes its blobs when the Sidekick's menu or panel opens, and takes a tap handed on from it. The button test: the swap checks (parts 1, 4 and 5), the held check from the pixels, and the ticks check. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 188, "The dials, and one menu at a time", `askedTest = 'button'`; `0.149.0+216`. |
| `DESIGN.md` | §6: one menu at a time; a dial's ticks stay inside its pill. |
| `tasks/BUILD188.md`, `tasks/QUEUE-after-186.md`, `CHANGELOG.md` | The brief; the queue renumbered (189 the Hovering range, 190 dismiss at the top); build 188. |
| `releases/prism-build-188.apk` | The build. |

## 1. Why the dials vanished while held, found by reading

**The cause:**
- The panel's code uses one scratch rectangle, `rr`, for several things:
  - **the panel's own outline:** set at the start of each frame;
  - **each switch and each segment row:** they set `rr` to their own shape as they draw (`drawSwitch`,
    `drawPicker`).
- The solid "Where it rests" pass (186's held dial, 187's whole section) is drawn after all the
  contents. It clipped itself to the panel's outline by reading `rr`, but by then `rr` held the last
  switch's knob ("Over other apps", near the bottom of the contents).
- **So the solid section was clipped to a knob-sized spot elsewhere, and nothing of it showed.**
- **Meanwhile the see-through pass left the section out on purpose,** since it was to be drawn solid on
  top. So while a dial was held, the section was simply gone: the faint panel and the app behind, as in
  the owner's video.
- **186 had the same bug for the one held dial:** "the dials turn transparent".

**The fix:** the outline has its own rectangle (`outline`), set once per frame and never touched by the
controls. The solid pass clips to it.

**Why the check passed:**
- 187's check read `panelSolidParts`, a note the code wrote just after asking for the section to be
  drawn.
- It proved the code went that way, not that anything reached the screen.

**The new check reads the pixels** (`testPixels`):
- **How:** at the moment a dial is held (the press answers while the finger is still down), the panel
  draws itself in software three times onto clear pixels: as it is, without the ticks, and without the
  numbers. The differences are exactly the ticks' and the numbers' pixels.
- **The check passes only if:**
  - **the section's own area** (a 9 × 5 grid from its title to under the dials, clear of its corners)
    is fully opaque, as opaque as the panel's colour (255);
  - **a point of the rest of the panel** (on the Labels row) is at about 0.4 of that (about 102);
  - **both dials' numbers have pixels** (at least 30) and every one of them is fully opaque.
- **With 187's bug,** the section's area would read about 102 and the numbers 0 pixels, so the check
  would fail, as it should have.

## 2. The ticks inside their pills

**The cause:** the ticks were clipped to the pill's square box, not to its rounded outline.
- A pill is 52 points tall with fully rounded ends, and the ticks ran down to 5 points from its bottom
  edge.
- Near the ends, that's outside the rounded outline, so the outer ticks poked out past it.

**Now:**
- **Height:** the ticks end 10 points above the pill's bottom, 8 points tall, 6 points under the
  number.
- **Width:** they spread only as far as stays 6 points clear of the rounded ends at the height of the
  lowest tick.
- **Clipped** to the pill's rounded outline, 4 points in.
- **At a large text size:** the pill grows (52 points up to text size about 1.4; at 2, 60 points), so
  the number, the 6 points, the ticks and the 10 points under them always fit, with room at the top.
- **At text size 1 nothing else moves:** the number is where it was, and the dials' fit on the S25
  (187) is unchanged.

**Checked by the pixels** too, with the panel open and no dial held:
- "the dials' ticks sit inside their pills, with room under them";
- for each dial: tick pixels found, none outside the pill (its rounded outline, 2 points in), and at
  least 6 points under the lowest. It prints the text size.

## 3. Only one menu open at a time

**The owner's rule:**
- **With Prism's blobs out, a tap on the Sidekick** closes them and opens the Sidekick's, in one tap.
  A hold on it (its panel) closes them too.
- **With the Sidekick's blobs out, a tap on Prism's triangle** closes them and opens Prism's, in one tap.

**How:**
- **The Sidekick opens its menu or its panel:** Android tells Prism (`sidekickOpened`). If Prism's
  blobs are out, Prism closes them. The triangle follows its rule (`_setOpen` → `_signSync`).
- **A tap on Prism's button while the Sidekick's blobs are out:**
  - The Sidekick's menu covers the whole screen, so the tap reaches it, not Prism. Until now, it only
    closed the Sidekick's menu.
  - Now, if Prism is in front and the tap lands within 40 points of Prism's button (where Prism said it
    is), the menu closes and hands the tap to Prism (`buttonTap`).
  - Prism does what a tap on its button does (`_doTap(_tapOutcome())`): its blobs open.
  - A blob of the Sidekick's lying over Prism's button is still that blob: a tap on it uses it.
- **A safety net:** whenever Prism says its blobs are out (`fan`), the Sidekick's menu closes if it
  is open. So the two are never left open together, however they were opened.

**Checks:**
- **Part 1 (runs in the preview too):** Prism's side, as Android tells it. Told the Sidekick's menu
  opened, Prism's blobs close and the triangle points up; given a tap from the Sidekick's menu, they
  open and the triangle points down. **Passes in the preview.**
- **Part 4 (phone):**
  - with the Sidekick's blobs out, one tap on Prism's button: the Sidekick's closed, Prism's open,
    Prism given exactly one tap, the triangle down;
  - then one tap on the Sidekick: its blobs open, Prism's closed, Prism told, the triangle up.
- **Part 5 (phone):** with Prism's blobs out, holding the Sidekick opens its panel and closes them.
- **Each check prints** whose blobs are out and which way the triangle points.

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 81 right, 1 wrong, 1 skipped, of 83 (the usual Android-only miss and phone-only skip; the new Prism-side swap check passes)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.

**Build 188:**
- `Prism build 188`, `0.149.0+216`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- Its `classes.dex` has `sidekickOpened`, `buttonTap`, `pixBlockLeast`, `pixSurfaceAlpha` and
  `TickOutside`. Its `libapp.so` has "Prism build 188", the one-menu checks and the ticks check.
- sha256 `c92653745147093202cb0017a5a054b3e9f5a987826ec47b03a51485ece488d2`, 18,878,922 bytes.
- Link (checked: answers 200, same sha256): https://github.com/vikac995/vikac/raw/250e46d9ed8a3629f82bcc8ea8fe5c61bd9d8a49/lumen/releases/prism-build-188.apk

## Where I could be wrong

1. **None of the Android side has run.** The fix for the vanishing dials is certain by reading: the
   clip read a rectangle the switches had just overwritten. But only the phone's pixels prove it, and
   the check now reads them.
2. **The software drawing in the check is not the phone's GPU drawing.** It runs the same `onDraw`, so
   it would have caught this bug, but a GPU-only difference would not show in it.
3. **Prism's button is found by where Prism said it is,** within 40 points. If Prism's view is ever
   offset from the screen (not edge to edge), the tap could be missed, and it would only close the
   Sidekick's menu, as before.
4. **The swap waits for the Sidekick's menu to be gone:** a second tap on the Sidekick within its
   closing moment (about 0.3 s) after handing a tap to Prism does nothing.
5. **The swap is for the Sidekick only.** The workout timer's lens keeps its own menu as before.

## On the phone

**What to look at:**
- Hold a dial: "Where it rests" stays fully solid, with its title, both numbers and the ticks.
- At rest: the ticks inside their pills, clear of the bottom and the rounded ends.
- **With Prism's blobs out:**
  - tap the Sidekick: Prism's close, the Sidekick's open;
  - hold the Sidekick: its panel opens and Prism's close.
- **With the Sidekick's blobs out:** tap Prism's triangle: the Sidekick's close, Prism's open.

**In the button test's report:** the new checks above, each with its figures.
