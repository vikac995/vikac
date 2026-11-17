# Build 196 report: Dismiss under the Sidekick

Brief: `tasks/BUILD196.md` (the review chat, 17 November, 07:17: "GO", the owner's decision).
- 196 is small, ahead of the list: the dismiss pill leaves the panel's header and sits just under the
  Sidekick, reading "Hold to dismiss" in full, with no bubble.
- Renumbered: 197 is the app list (held, to be moved onto 196), 198 the test's own store (F02 + F34), and
  199 search.

**Only the preview has run it.** The panel and the pill are Android's.

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickPanel.kt` | **The header:** only "Sidekick" and the ✕. Gone: the pill there, its own line at a large text size, and the bubble. **The pill:** drawn by the panel's window, over everything it draws (`pillAt`, `pillTouchAt`, `drawPill`); its touch comes before the panel's; it's kept from Back near an edge. **Unchanged:** 195's hold. **Test state:** `pill` (its box and touch, over or under, the glass, the screen, its floor and ceiling, kept from Back, how much lies over the panel). |
| `lib/fit/shell.dart` | Part 5: the header check, the pill's place at opening and at four places, and 195's six hold checks at the new place (below). |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 196, 17 November, "Dismiss under the Sidekick", `askedTest = 'button'`; `0.157.0+224`. |
| `DESIGN.md` | §6: the pill under the Sidekick; the header. |
| `tasks/BUILD196.md`, `CHANGELOG.md` | The brief; build 196. |
| `releases/prism-build-196.apk` | The build. |

## The pill

**Where:**
- Centred on the Sidekick's x, 10 points under its glass.
- **Above it instead,** 10 points over the glass, where it wouldn't fit below. Its lowest is 12 points
  above Android's bar and, in Prism, 8 above Prism's.
- **Always fully on the screen,** 12 points from each side and never under the status bar. At Hovering
  −48, where the glass's middle is at or past the screen's edge, it slides inward.

**How:**
- **Size:** 36 points tall, as wide as its widest label ("Hold to dismiss", 141 points), so it never
  changes size.
- **Look:** on the panel's own ground, with a hairline round it, because it lies over whatever is there:
  the app behind, or the panel's edge.
- **Showing and going:** with the panel's opening and closing, growing a little as it shows. It goes
  while a dial is held, when the rest of the panel goes too.
- **Following:** it's worked out from where the Sidekick is in each frame, so it follows a drag with the
  panel open and the Sidekick's glide after.

**Its touch:**
- The pill and 6 points round it, at least 48 points tall.
- Never in the Sidekick's own touch (its glass and 6 points round it): what it can't take on that side,
  it takes on the far side.
- It's tested before the panel's own parts.
- Near an edge, it's kept from Android's Back, besides the Sidekick's spot (194).

**Hold to dismiss, as in 195:**
- **Held:** a 1.2 s fill, light ticks at 25, 50 and 75%, a heavy one at 100%, the growing shake, never
  two haptics within 28 ms.
- **Ended early** (let go, slid off, scrolled or cancelled): it drains (k 90, c 19), and nothing happens.
- **At 100%:** a pop (k 420, c 10), then the panel closes after 0.42 s, and the Sidekick is sent away
  0.28 s after that.
- **Its own label** now says what to do: "Hold to dismiss", "Keep holding…" while held, "Dismissed" at
  the end.

## The checks (part 5)

1. **"the header has no Dismiss: only its title and the X".**
2. **"'Hold to dismiss' under (or over) the Sidekick, fully on the screen, as it opens"**, and the same
   **high and low, at Hovering 8 and −48** (four checks).
   - **How:** with the panel open, the Sidekick is carried to the top, then the bottom (it stops 48
     points from each), and at each its Hovering is set as its dial would.
   - **Each check needs:**
     - over or under the glass by at least 10 points;
     - centred on it, unless slid in from the side;
     - fully on the screen, between its ceiling and floor;
     - its touch at least 48 tall and clear of the Sidekick's touch, and kept from Back near an edge;
     - the label "Hold to dismiss".
   - **Each prints** where it is and how much of it lies over the panel.
   - **Afterwards:** Hovering and the Sidekick's height are put back.
3. **195's six, at the new place:**
   1. "pressed: the fill sweeps across it, and it says 'Keep holding…', still where it should be";
   2. "pressed for 0.6 s and let go: nothing happens, and the fill drains back within 0.5 s" (under 3%
      at 0.5 s, as in 195);
   3. "slid off at 0.8 s: nothing happens, and the fill drains back" (now slid toward the middle of the
      screen);
   4. "a tap on 'Hold to dismiss' does nothing, and it still says so";
   5. "held for 1.3 s: 'Dismissed', with a light tick at 25, 50 and 75% and a heavy one at 100%";
   6. "held to the end sends it away, and the panel closes".

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 81 right, 1 wrong, 1 skipped, of 83 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.
- **The new checks are all Android's,** so the preview doesn't reach them.

**Build 196:**
- `Prism build 196`, `0.157.0+224`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- **Its `classes.dex` has:** "Hold to dismiss", "Keep holding", "Dismiss, held to the end" and `overPanel`,
  and no `holdBubbleBox`.
- **Its `libapp.so` has:** "Prism build 196", "Dismiss under the Sidekick" and the new checks.
- sha256 `27b8f76d7b57cd5dd754c87552b28921d83548456e56169f7dbfc911c3b49c80`, 18,878,922 bytes.
- Link (checked: answers 200, same sha256): https://github.com/vikac995/vikac/raw/5abcbfbb10c03f6c6dd8ac3db23d67c6c6214ffc/lumen/releases/prism-build-196.apk

## Where I could be wrong

1. **None of it has run on a phone.**
2. **The pill lies over the panel's edge.**
   - **Why:** the panel leaves the Sidekick a column of about 107 points, but the pill is 141 wide, and
     the panel lies beside the Sidekick at its height.
   - **By arithmetic, on the S26** (411 wide, at Hovering 8): the pill runs from about 258 to 399, and
     the panel to about 304.
   - **Effect:** about 46 points of the pill lie over the panel's side nearest the Sidekick. Whatever the
     panel has there, under the pill (the end of a row of choices, a look, a dial's end), is hidden and
     can't be touched.
   - **The check prints the figure** ("over the panel W × H points").
   - **If it gets in the way:** the panel could keep clear of the pill (about 46 points narrower: 250, its
     least), or the pill could be smaller.
3. **Low on the screen it goes over the Sidekick,** so the eye looks for it in two places, depending on
   where the Sidekick rests.
4. **Its ground is the panel's own colour,** so where it lies over the panel it reads as part of it; the
   hairline is its edge.
5. **The 2.2-point shake, the drain and the pause before closing** are as in 195.

## On the phone

**What to look at:**
- **Where:** hold the Sidekick. The panel opens, and "Hold to dismiss" sits just under the Sidekick.
- **Moving it:** drag the Sidekick with the panel open, and the pill comes along. Low down it goes above
  the Sidekick; at Hovering −48 it stays fully on the screen.
- **Holding it:** "Keep holding…", the fill, three light ticks, a heavy one, "Dismissed", the panel
  closes, and the Sidekick shrinks away.
- **The header:** only "Sidekick" and the ✕.
