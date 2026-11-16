# Build 187 report: the dials, fixed again

Brief: `tasks/BUILD187.md`. The owner's feedback on 186 (video 18:12, by hand), from the review chat
(17:14).

- **The one behaviour change:** the Sidekick panel's dials. The panel is solid again right after a
  let-go, and the whole "Where it rests" section stays solid while a dial is held.
- **Added at the go:**
  - the dials fitting on the S25's screen (tighter spacing);
  - the "dragged by hand" check's exemption;
  - the test's untuck step reporting what it did.
- **No investigation.** One diagnostic line in the trail (below).

**Only the preview has run it.** The Sidekick's panel is Android's, so none of its checks run in the
preview.

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickPanel.kt` | `SETTLE_MS` 600 → 100 ms. Tighter spacing between sections (40 points saved above the dials). Its limits, and whether its contents fill them, in the test state. "Where it rests" (its title and both dials) drawn apart, solid, on its own backing, while a dial is held, and until the rest is solid again. The let-go timing record, the strokes carried on, and a trail line for each finger back on a dial. New test state. The header comment brought up to date. |
| `android/.../MainActivity.kt` | The test's `panel`/`drag` can make a second stroke (`again`) a set time (`gapMs`) after the first is let go. The `untuck` op says what it did (`did`). |
| `lib/fit/long_test.dart` | The floating-lens table: a step done every time but with nothing timed shows "done, not timed: …", not "NOT DONE: null". |
| `lib/fit/shell.dart` | Part 5's dial checks, for the new rule. The "dragged by hand" check's exemption, from the panel's own limits. The room under the dials in the "both dials" check. The untuck NOTE every time. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 187, "The dials, fixed again", `askedTest = 'button'`; `0.148.0+215`. |
| `DESIGN.md` | §6 and §7: the held section solid; let go, solid again right away; the panel's spacing. |
| `tasks/BUILD187.md`, `CHANGELOG.md` | The brief; build 187. |
| `releases/prism-build-187.apk` | The build. |

## 1. Solid again right after a let-go

**The rule:** let go of a dial, and the panel is solid again right away, on the quick spring. The
Sidekick goes back on the same timing.

**The spring:** the same `clear` spring as before, `effects` (stiffness 1600, ζ 1, no bounce). From
see-through (0.4) it passes 0.97 in about 0.12 s.

**The choice: `SETTLE_MS` = 100 ms** (186: 600).
- **Why not 0:** with no wait at all, a finger back on the dial after 0.1 s would find the panel already
  about 95% solid. That's the hard flash again, at the pace of an ordinary thumb stroke.
- **Why 100:**
  - **About the shortest delay anyone notices,** so the let-go still feels immediate.
  - **No dip for a finger back within 0.1 s:** it carries straight on.
  - **Solid again about 0.22 s after the let-go,** well inside the 0.3 s check. That's 0.1 s of wait,
    then 0.12 s of spring.
- **Why not 120:** it would buy a little more cover (up to 0.12 s), but take about 0.24 s to solid,
  with less margin for a slow frame on the phone.
- **What a finger back on the dial sees, by how long after the let-go:**

| Back after | The panel at its most opaque in between |
|---|---|
| up to 0.10 s | 0.4: no change at all, it carries on |
| 0.125 s | about 0.56: a slight dip |
| 0.15 s | about 0.76 |
| 0.175 s | about 0.88 |
| 0.2 s or later | about 0.95 and up: solid, as the rule asks |

- **The Sidekick** goes back at the same moment (`showSpot` in the same `settle`). Going back into a tuck
  is its own glide, 0.26 s.

## 2. "Where it rests" solid while a dial is held

**The rule:** while either dial is held, the whole "Where it rests" section stays fully solid: the title
"Where it rests, in points", both dials and their names (Hovering, Tucked in). Only the rest of the
panel goes to 0.4: its body, Labels, Icons, Colours, Look and the two switches.

**How:**
- **In the see-through pass,** the section is left out (`heldApart`).
- **Drawn again on top,** fully solid, on a backing of the panel's own colour: a rounded block from just
  above the title to just below the dials, 10 points wider than them at each side.
- **Its edge:** a thin line that shows only as the rest goes see-through, and goes as the rest comes
  back. At the start and the end, the block is the panel itself, so nothing pops in or out.

**One more cause of "the dials turn transparent,"** found while doing this, and fixed:
- **In 186, at the end of the hold,** the held dial stopped being drawn apart at the same moment the rest
  started back from 0.4.
- **So the dial dropped to 0.4 for an instant and came back up with the panel:** a visible dip of the one
  thing that was meant to stay solid.
- **Now the section stays drawn apart until the rest is solid again** (under 1% see-through), and only
  then rejoins the panel.

## 3. Both dials on the S25's screen

**The problem** (the 186 run on the S25, 4 of 4 times):
- The panel's box was [127.8, 56, 275.6, 692.7], so its bottom was at 748.7, 8 above Prism's bar.
- The dials reached down to 770.8, cut off by about 22 points. The S26, with its taller screen, passed.

**The fix: only the space between, nothing smaller, nothing moved:**

| Space | Before | Now |
|---|---|---|
| under the title "Sidekick" | 14 | 8 |
| from a section's name to its control (Labels, Icons, Colours, Where it rests) | 8 | 6 |
| from "Look" to its tiles | 10 | 6 |
| between sections (after Labels, Icons, Colours, Look) | 14, 16, 16, 16 | 10 each |
| after the dials, before the switches | 16 | 10 |

- **That's 40 points saved above the dials** (118 → 78). The Look tiles and the segment rows are as they
  were.

**Room left under the dials, at font scale 1:**
- **S25: about 18 points** (worked out: 692.7 tall, the dials now ending 674.8 into it).
- **S26: about 50 points.** Estimated: its panel may be about 34 points taller (in 185 the two allowed
  745 and 779). That fits 186, where it had about 12 to spare and passed.
- The check now prints the exact figure on each phone ("N points to spare under the dials").

## 4. The test kit: "dragged by hand", and untuck

**"Dragged by hand with the panel open, the Sidekick moves and the panel follows it"** failed on both
phones in 186, 4 of 4 times (the panel 0). The test was wrong; see "Fixed" under the tests below.

**"untuck x4 … NOT DONE: null"** in the floating-lens table of both 186 reports:
- **The step worked:** it answered "ok". Otherwise the report would have had a WRONG "untuck: Android
  could do it", and it didn't.
- **Why the table said NOT DONE:** it counts only steps that timed the frames drawn, and untuck times
  none.
- **Now:**
  - the step says what it did ("was tucked: yes, brought out (tucked now: no)", or "was tucked: no, left
    as it was");
  - the table shows a step done every time with nothing timed as "done, not timed: " and those words;
  - a NOTE says it every time, not only when it was tucked.

## The trail: how fast a thumb comes back

Each time a finger comes back on a dial, the trail gets "its panel's dial held again N ms after it was
let go" (and ", carrying on" when it was within the 0.1 s).
- After turning a dial by hand, "Send what just happened" then shows the owner's real gaps between
  strokes.
- That's the figure to tune `SETTLE_MS` by, if 0.1 s turns out wrong.

## The tests (part 5, Android only)

**Changed:**
- **"<dial> touched, the Sidekick goes there, the rest of the panel see-through, "Where it rests"
  solid":**
  - the rest at 0.4 (within 0.08);
  - the last frame drew the title and both dials apart, at 1.0, and each dial's alpha is 1.0
    (`panelSolidParts`, `panelSolidAlpha`, `panelDialsAlpha`).
- **"<dial> let go, the panel is solid again within 0.3 s, the Sidekick as it was":**
  - the panel's own record of how long after the let-go it first drew a frame over 0.97
    (`panelSolidAfterMs`) is 300 ms or less;
  - it's solid now, the section no longer drawn apart, and the Sidekick tucked or not as before.

**Kept as it was:** "a dial dragged for 1.5 s, the rest of the panel stays see-through the whole time"
(≤ 0.45 on every frame while the finger is down, over at least 3 frames).

**Retired:** "a second stroke straight after, it stays see-through in between." It started the second
stroke about 0.3 s after the first, where the new rule makes the panel solid in between.

**New:**
- **"a finger back on the dial 0.05 s after the let-go carries straight on, no dip":**
  - two strokes, the second 50 ms after the first is let go (timed on Android's side);
  - ≤ 0.45 over both, and the panel counts one stroke carried on (`panelCarriedOn`).
- **"let go after the last stroke, the panel is solid again within 0.3 s":** as above.

**Fixed (the 186 S26 run's one WRONG, 4 of 4 times):** "dragged by hand with the panel open, the
Sidekick moves and the panel follows it" [the Sidekick moved -119, the panel 0].
- **The test was wrong, not the panel. Confirmed by reading:**
  - The check lets a panel that is as tall as it may be stay where it is, since it can't move.
  - It decided "as tall as it may be" from a fixed figure: the screen less 56 + 42 + 60 points.
  - From 186 the panel ends above Prism's bar, so the space it may fill is shorter than that figure. On
    the S26, about 600 points: from 56 down to 8 above the bar.
  - Its contents (about 830 points) still fill all of it, so it rightly stays. But the check no longer
    saw it as "as tall as it may be", and wanted it to follow.
- **The fix:** the panel now reports its own limits and whether its contents fill them (`panelTopLimit`,
  `panelBottomLimit`, `panelFills`, worked out in `layoutBox`). The check uses those.
  - Its details now give the panel's height, its limits and whether it fills them, so a phone run shows
    which case it was.
  - A panel shorter than its space must still follow within 30 points.

**Test area:** badge 187, "The dials, fixed again", `askedTest = 'button'`.

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 80 right, 1 wrong, 1 skipped, of 82 (the same as 186: the panel's checks run only on a phone)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.

**Build 187:**
- `Prism build 187`, `0.148.0+215`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- Its `classes.dex` has `panelSolidParts`, `panelSolidAfterMs`, `panelCarriedOn`, `panelFills` and the
  untuck step's words. Its `libapp.so` has "Prism build 187", "The dials, fixed again", "done, not timed",
  the room under the dials and the new two-stroke check.
- sha256 `8378fcf7430b47cdfee2857594c71f740411f5110bb7fdd5b54cbbe45a3917de`, 18,797,002 bytes (the same
  size as 185 and 186 again: the APK's large parts are stored unpacked, padded to whole blocks).
- Link: in the next commit.

## Where I could be wrong

1. **None of it has run where it matters.** The panel is Android's; the first phone run proves or
   disproves each point.
2. **The owner's own strokes may be slower than 0.1 s apart.**
   - The 185 video's pattern (about 0.3 s solid, 0.3 s see-through) suggests gaps of 0.2 to 0.3 s.
   - At those gaps the panel is solid between strokes, which is what the new rule asks for.
   - If it still reads as a flash, the trail's gaps say by how much, and the choice is between a longer
     wait (which the owner just turned down) and accepting it.
3. **The timing on the phone:** 0.22 s to solid is worked out from the spring. A slow frame adds about
   0.01 to 0.02 s. The 0.3 s check has room for that, not for a long hitch.
4. **The block's backing is the panel's own colour.** In a dark look over a dark app, the block may
   read less clearly as "one block" than in a light one. The thin edge helps. If it isn't enough, the
   block could be a step lighter or darker than the panel.

## On the phone

**What to look at:**
- Let go of a dial: the panel solid again at once.
- While a dial is held, the whole "Where it rests" section solid: its title, both dials and their names.
- Turning a dial in quick strokes: no hard flash.

**In the button test's report:** the new checks above. After turning a dial by hand, "Send what just
happened" gives the gaps between strokes.
