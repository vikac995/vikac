# Build 189 report: the Hovering range

Brief: `tasks/BUILD189.md`. The review chat's GO (18:38), after the owner tried 188 by hand ("works fine
now"); the plan from `tasks/BUILD185.md` and `tasks/QUEUE-after-186.md`.

- **The one behaviour change:** the Hovering range: closest 75% past the edge, farthest 36, the default 8.
  With it:
  - Tucked in's minimum;
  - the grab area for a Sidekick resting past the edge.
- **One number from the owner:** while a dial is held, the rest of the panel is drawn at 0.2 (was 0.4).

**Only the preview has run it.** Everything here is Android's (where the Sidekick rests, its grab area,
the panel), so the phone run is what proves it.

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickSettings.kt` | `GAP_MIN` 0 → −60, `TUCK_MIN` 8 → 18. Saved values outside are brought in when read, as before. |
| `android/.../MainActivity.kt` | `edgeGap()`: below 0, past the edge, scaled with the Sidekick's size. The tuck-on-release threshold beyond the resting place. The grab area: `fitGrip`, `regrip`, `dropHoverGrip`; `openGrip` takes a side and a width. The grip in the test state; a test step `panel`/`tuck`. |
| `android/.../SidekickPanel.kt` | `REST_SEE` 0.6 → 0.8 (the rest at 0.2). The dial shows a true minus sign below 0. Comments. |
| `lib/fit/bubble.dart` | Prism's copy of the ranges: −60 to 36, and 18 to 40. |
| `lib/fit/shell.dart` | The checks: Hovering at its closest and farthest, the grab area, the thresholds for 0.2. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 189, "The Hovering range", `askedTest = 'button'`; `0.150.0+217`. |
| `DESIGN.md` | §6: the two ranges, the grab area, the rest at 0.2. |
| `tasks/BUILD189.md`, `CHANGELOG.md` | The brief; build 189. |
| `releases/prism-build-189.apk` | The build. |

## 1. The Hovering range

**Hovering (`gap`) now goes from −60 to 36 points.** The default stays 8.

**Below 0, it rests past the edge.**
- **At −60, 75% of its glass is past the edge.**
  - Its window is its glass plus 5 points round it. At the standard size that's 84 points: a glass of 74.
  - So −60 puts the glass's edge 55 points past the screen's edge. 55 ÷ 74 ≈ 75%.
- **Below 0 the points are at its standard size and scale with it,** as the tucked sliver already does.
  So a Sidekick made larger or smaller with two fingers still rests 75% past the edge at −60.
- **0 and above are unchanged:** points from the edge, whatever its size.

**The dial shows "−60"** with a true minus sign. One tick is still a point, so −60 to 36 is 96 points of
travel.

**Pushing it into the side still tucks it:**
- **Before:** letting go a quarter of the way past the edge tucked it.
- **The problem:** resting at −60 is already well past that, so the slightest drag would have tucked it.
- **Now:** it tucks only when pushed 15% of its width further past than where it rests (still at least
  a quarter of the way, as before).

**Farthest:** 36, as today.
- The panel's width rule (185) already keeps it clear of the Sidekick at 36.
- Below 0 the Sidekick is only further from the panel.

## 2. Tucked in's minimum

- **18 points now (was 8):** 10 points more of the Sidekick shows, about 13.5% of its glass, within the
  owner's 10–15%.
- **Kept values below 18** come up to 18 when they're read, as any value outside the range always has.
- The maximum stays 40.

## 3. The grab area, adapting per setting

**When it applies:** resting past the edge, the Sidekick may show only about 24 points of its window (at
−60), less than a thumb takes hold of easily, right in Android's back-gesture zone.

**What it does:**
- **When less than 56 points of it shows,** a strip 56 points wide, from the edge, at its height (8
  points taller above and below) takes its touches.
  - It's the same kind of strip as the tucked Sidekick's grip (`Grip`): every touch on it is handed to
    the Sidekick, as if on the Sidekick itself (tap, hold, drag).
  - It's kept out of Android's back gesture (`systemGestureExclusionRects`).
- **At Hovering −28 and above** (standard size), 56 points or more of it shows, so no strip is added. The size of the
  strip follows the setting: none, or just enough to make 56.
- **It follows the Sidekick:**
  - when the Sidekick moves by itself (a dial, a glide), the strip goes at once;
  - once it has been still for 0.15 s, the strip is fitted where it rests;
  - while a finger has it, the strip stays until the finger lifts, as the tucked grip does. Taking it
    away mid-touch would cancel the drag.
- **Never over its own menu:** the strip would sit above the menu and take its touches. It comes back
  when the menu closes.

**The back-gesture limit (200 points per edge):** the strip is the Sidekick's height plus 16 (100 at the
standard size). With the Sidekick's own window, that's well inside the limit.

**On "a short measurement first"** (the plan in BUILD185):
- I couldn't measure on a phone, so the size rests on Android's own guidance: touch targets at least 48
  points, with 8 more for an edge where the thumb comes in at an angle.
- The tucked grip (76 points) stays as it was.
- The new check prints how much of the Sidekick shows and how wide the strip is, so the phone run gives
  the real figures.

## 4. The rest of the panel at 0.2

- **`REST_SEE` 0.6 → 0.8:** while a dial is held, the rest of the panel is drawn at 0.2 (80%
  see-through). "Where it rests" stays solid at 1.0.
- **Solid again after a let-go:** the panel passes 0.97 about 0.23 s after the let-go (0.1 s wait, then
  0.13 s of spring). That's inside the 0.3 s check.

## The tests

**Changed for 0.2:**
- **"touched":** the rest at 0.2 (within 0.06).
- **The pixel check:** the rest at 0.2 of the panel's opacity (about 51, within 0.08).
- **The 1.5 s drag and the two strokes:** ≤ 0.25 while the finger is down (was ≤ 0.45, for 0.4). The
  same margin over the level.

**Changed for the range** ("distance from the edge … it rests there"): at −60, the distance expected is
−60 scaled by its size.

**New:**
- **"Hovering at its closest, 75% of it past the edge":** from where the glass really is on the screen
  (`lensMid`, `lensRadius`), within 4%.
- **"resting past the edge, a grab area at least 56 points wide beside it, at the edge, kept from the back
  gesture":** the strip is open, is the one for resting past the edge, is at least 56 wide, starts at
  the screen's edge, and spans the Sidekick's height. It prints how much of the Sidekick shows.
- **"Hovering at its farthest, wholly on the screen, no grab area added."**
- **Tucked in at 18:** the existing "tucked, N points showing" check runs at the new minimum.

**Test area:** badge 189, "The Hovering range", `askedTest = 'button'`.

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 81 right, 1 wrong, 1 skipped, of 83 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.

**Build 189:**
- `Prism build 189`, `0.150.0+217`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- Its `classes.dex` has `gripHover`, `gripBox` and the grab area's trail line. Its `libapp.so` has "Prism
  build 189", "The Hovering range" and the new checks.
- sha256 `a2c54ce943ee185e5620ee3f8e3991167dd81ebdf105daf2b6d01b5d97cf5adf`, 18,878,922 bytes.
- Link (checked: answers 200, same sha256): https://github.com/vikac995/vikac/raw/7b9c0e2d1703433bd00231cae2cf9d7db0b7c293/lumen/releases/prism-build-189.apk

## Where I could be wrong

1. **None of it has run on a phone.** Where the Sidekick rests, its strip, and the back gesture are all
   Android's.
2. **A Sidekick resting far past the edge opens its blobs around its middle, which is past the edge.**
   The blobs fan into the screen, so they show. But the Sidekick itself in the middle of them is mostly
   off the screen, so a tap "on the Sidekick" there has little to aim at. If that matters, its menu
   could open from a point brought in onto the screen.
3. **The strip takes touches over the app beside the Sidekick:** up to 32 points of app next to a −60
   Sidekick, at its height. The tucked grip already does this (76 points).
4. **Some phones might not honour the back-gesture exclusion** in the bottom part of the screen (Android
   ignores it near the bottom, where Home is). A Sidekick resting low and past the edge may then lose
   some edge swipes to Back.
5. **The 15% beyond the resting place before a tuck** is my choice. If pushing in to tuck feels too
   long a push at −60, it can be smaller.

## On the phone

**What to look at:**
- Hovering down to −60: three-quarters of the Sidekick past the edge, still easy to grab, tap and drag
  from the edge without Back.
- Tucked in down to 18.
- The rest of the panel much fainter (0.2) while a dial is held, "Where it rests" solid.
