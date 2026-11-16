# Build 195 report: hold to dismiss

Brief: `tasks/BUILD195.md` (the review chat, 21:45 and 21:59: the owner's own request, small). The app list
moves to 196 and search to 197.

- **The one behaviour change:** the Sidekick's "Dismiss" is held, not tapped. It's modelled on the
  owner's prototype exhibit "I-05 Hold to confirm", with their numbers.
- **Where its words go:** the review chat's choice (c), 22:02, after I reported they don't fit beside the
  title.

**Only the preview has run it.** The panel is Android's.

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickPanel.kt` | **Hold to dismiss:** the fill, ticks, shake, drain, pop and close (`startHold`, `letGoHold`, `stepHold`, `drawDismiss`), and the bubble under the pill (`drawHoldBubble`). A tap on the pill no longer sends the Sidekick away. **Test state:** `holdFill`, `holdMost`, `holdEnded`, `holdAt500`, `holdDrainMs`, `holdBuzzes`, `holdLabel`, `holdBubble`, `holdBubbleBox`, `closeBox`. |
| `android/.../MainActivity.kt` | The test's `panel` step gains `hold` (held still for a time, then lifted) and `holdSlide` (held, then slid away and lifted). |
| `lib/fit/shell.dart` | Part 5: the old "Dismiss" tap check replaced by six hold checks (below). |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 195, "Hold to dismiss", `askedTest = 'button'`; `0.156.0+223`. |
| `DESIGN.md` | §6: hold to dismiss, and its bubble. |
| `tasks/BUILD195.md`, `CHANGELOG.md` | The brief and the choice of (c); build 195. |
| `releases/prism-build-195.apk` | The build. |

## The pill

**Place and size are 194's:** "Dismiss", 12 points after the title, its touch 48 points tall and short of
the ✕'s. At a large text size it goes on its own line under the title, as before.

**Held:**
- A fill sweeps across it from left to right over 1.2 s, in the accent. The word "Dismiss" turns to the
  accent's ink where the fill has reached.
- Haptics: a light tick at 25%, 50% and 75%, and a heavy one at 100%. Never two within 28 ms.
- It shakes a little, more as it fills: sideways by sin(t / 14 ms) × p² × 2.2 points, and 1 − 0.035 × p
  smaller.
  - The prototype's "px" are taken as points, since the prototype is a web page.

**Let go, slid off its touch, scrolled, or taken away by Android before the end:**
- The fill drains back on the owner's spring (k 90, c 19), and nothing happens.
- A plain tap does the same: the fill starts and drains back.

**At the end:**
1. A pop (0.88 to 1 on the owner's spring, k 420, c 10), and the bubble says "Dismissed".
2. 0.42 s later the panel closes into the Sidekick.
3. 0.28 s after that the Sidekick shrinks away, exactly as in 194, and comes back when the next app is
   opened from Prism.

If the panel was closed some other way during those 0.42 s (Home, say), the Sidekick is still sent away:
it was held to the end.

## The bubble (choice (c))

**Why:**
- Measured with the app's own font (Inter 600, 15 points), the pills would be 141 points wide for "Hold to
  dismiss", 140 for "Keep holding…" and 106 for "Dismissed".
- "Dismiss" was 88.
- On the S26 the room beside the title is about 100 points.

**What it is:**
- A small dark bubble just under the pill, pointing up to it, 13-point text.
- It says "Hold to dismiss" at rest, "Keep holding…" while held, and "Dismissed" at the end.

**When it shows:**
- while the pill is pressed;
- for 1.2 s after a let-go (so a short tap shows "Hold to dismiss" for a moment);
- at the end, until the panel closes.

It fades and grows in a little.

**Where:**
- inside the panel: it's drawn within the panel's clip, and kept 10 points from its sides;
- below the title's row, so it never covers the ✕;
- over the "Labels" section for that moment.

## The checks (part 5)

1. **"'Dismiss' pressed: the fill sweeps across it, and a bubble under it says 'Keep holding…', inside
   the panel and clear of the X".** Read 0.3 s into a 0.6 s press. It prints the bubble, panel and ✕
   rectangles.
2. **"pressed for 0.6 s and let go: nothing happens, and the fill drains back within 0.5 s".**
   - It must have filled 40 to 75%, ended "let go", and gone back to 0, with no heavy haptic.
   - **"Drained within 0.5 s" is read as under 3% of the fill at 0.5 s.** The owner's spring is
     critically damped: from half full it is about 2.5% at 0.5 s, and under 1% at about 0.6 s. The check
     prints both figures.
3. **"slid off at 0.8 s: nothing happens, and the fill drains back".** Held 0.8 s, then slid 180 points
   sideways in 0.12 s and lifted there. It must have filled 60 to 90%, ended "slid off", and gone back
   to 0.
4. **"a tap on 'Dismiss' does nothing; its bubble says 'Hold to dismiss' for a moment, then goes".**
   - 0.3 s after the tap: the bubble is shown, with those words.
   - 1.6 s later it's gone, and the panel is still open.
5. **"held for 1.3 s: 'Dismissed', with a light tick at 25, 50 and 75% and a heavy one at 100%".** Read
   just after the lift, while the panel is still up: the haptics must be exactly those four, in order.
6. **"held, its panel's 'Dismiss' held to the end sends it away, and the panel closes".** 1.5 s later:
   - it's gone, and the panel closed;
   - `sideGone` is set, and one dismissal from the panel was counted.

   Then, as before, "sent away from its panel, it comes back when brought back".

**The header check** ("'Dismiss' right after the title…") is unchanged.

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 81 right, 1 wrong, 1 skipped, of 83 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.
- **The new checks are all Android's,** so the preview doesn't reach them.

**Build 195:**
- `Prism build 195`, `0.156.0+223`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- **Its `classes.dex` has:** "Hold to dismiss", "Keep holding", "Dismissed", "Dismiss, held to the end",
  `holdBubbleBox` and `holdAt500`.
- **Its `libapp.so` has:** "Prism build 195", "Hold to dismiss" and the new checks.
- sha256 `69a61f8aa3e69483d7de0706da43bfbc99aff71e25719ca72590a029e2cfd078`, 18,878,922 bytes.
- Link (checked: answers 200, same sha256): https://github.com/vikac995/vikac/raw/94a1735694dc749c15e343c604e0aedfd0c98c35/lumen/releases/prism-build-195.apk

## Where I could be wrong

1. **None of it has run on a phone.**
2. **The drain:** "drained to 0 within 0.5 s" and the spring (k 90, c 19) don't quite agree. From half
   full the fill is about 2.5% at 0.5 s and under 1% at about 0.6 s. I kept the owner's spring and made
   the check read "under 3% at 0.5 s". A stiffer spring would meet 0.5 s exactly, if wanted.
3. **The bubble covers the top of "Labels"** for the moment it shows. It's dark and small, and goes 1.2 s
   after a let-go.
4. **The shake's size:** 2.2 is taken as points, not pixels (on the S26 that's about 6 pixels at most).
   If the prototype meant device pixels, it would be about a third of this.
5. **The pause before the panel closes** (0.42 s, so the pop and "Dismissed" are seen) is my choice.

## On the phone

**What to look at:**
- Hold the Sidekick for its panel. Press and hold "Dismiss":
  - the accent fills it from the left over about a second;
  - three light ticks, then a heavy one;
  - it shakes a little, more near the end;
  - the bubble under it says "Keep holding…", then "Dismissed";
  - then the panel closes and the Sidekick shrinks away.
- Let go halfway: the fill runs back, nothing happens.
- A quick tap: the bubble says "Hold to dismiss" for a moment.
