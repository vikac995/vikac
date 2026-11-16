# Build 191 report: the fan and its names

Brief: `tasks/BUILD191.md` (the review chat, 19:23). The mock-up the owner chose from: "Away from the
Sidekick", plus the turned fan (https://claude.ai/artifact/7b5NvRHX4jVK8UVKfEQjoh).

**The owner's screenshot** (20:15, S26, Prism, the Sidekick high on the right, Pearls, labels on): the
blobs piled up near the top-right corner (Facebook on top of Scan), and the names, under their blobs,
covered the next blob and the chart.

**Also in 191** (the owner's decisions from trying 190, and the 189 S25 results):
- the Hovering range, now −48 to 15;
- the rest of the panel fully gone while a dial is held;
- the two 189 S25 puzzles ("the rest 0", the strip "beside it false");
- the navigation mode in every report.
These are in sections 3 to 6.

**Only the preview has run it.** The Sidekick's menu is Android's. The layout itself was also checked
with a faithful copy of its arithmetic (below), on both phones' screen sizes.

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickSettings.kt` | `GAP_MIN` −60 → −48, `GAP_MAX` 36 → 15. |
| `android/.../SidekickPanel.kt` | `REST_SEE` 1.0 (nothing of the panel drawn while a dial is held, the block still drawn). The "rest" sample point moved into the panel's margin. |
| `lib/fit/bubble.dart` | Prism's copy of the range. |
| `android/.../FanLayout.kt` (new) | The fan (`lay`), the names (`names`) and, for the test, how clear of each other everything is (`gaps`). |
| `android/.../MainActivity.kt` | `navMode()`, in the test state and the report's header; the Sidekick's window's place on the screen (`lensScreen`). The Sidekick's menu uses FanLayout: its fan, its seats' bounds, its names (on pills, drawn before every blob and badge), and a tap on a name where it is. Test steps: `menu`/`geometry` (the open menu) and `fan` (six places). `badgeHalf`. |
| `lib/fit/shell.dart` | Part 4: the fan at six places, and the open menu. Part 5: the range and 0-opacity checks, the strip measured against the Sidekick's place on the screen, "not applicable" without gesture navigation, the rest sample proven solid. The report's header gives the navigation. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 191, "The fan and its names", `askedTest = 'button'`; `0.152.0+219`. |
| `DESIGN.md` | §6: the Sidekick's fan and its names. |
| `tasks/BUILD191.md`, `CHANGELOG.md` | The brief; build 191. |
| `releases/prism-build-191.apk` | The build. |

## Why they piled up

**The old layout:**
- The fan turned up or down (up to 96°) to keep its seats inside the screen.
- If no turn fitted, it took the turn that overflowed least, and then pushed each seat onto the screen
  on its own (`coerceIn`). Two seats pushed into the same corner land on, or near, the same spot.

**At a corner no turn fits,** so the pile-up was certain there.
- With the Sidekick high on the right (S26), the seats must lie between about 92° and 187° round it to
  stay on the screen.
- The fan needs 112° (four gaps of 28°).

## 1. The fan

**The rule** (`FanLayout.lay`):
1. **Point straight in, else turn away from the corner,** in 4° steps up to 120°. The first turn where
   every blob is clear of the edges, the status bar and Prism's bar wins.
2. **If no turn fits, make the arc a little larger:** 10%, 20%, 30%, 40%. Its seats sit closer round it
   (a smaller angle between them), so the distance from one blob to the next stays exactly as usual.
3. **Smaller only as a last resort:** 90%, then 80%.

**Why larger, not smaller (the brief said "shrink"):**
- Keeping the usual spacing on a smaller arc needs a wider angle, so more room, not less.
- On the S26 with the Sidekick high on the right:

| Arc | Overflow at the best turn |
|---|---|
| usual | 5 points |
| 90% | 31 points |
| 80% | 51 points |
| 110% | none (turned 36°) |

**Where a blob's middle may be:**
- 45 points from the sides, below the status bar (78), and above the bottom (80).
- In Prism, also 45 points above Prism's bar (190 kept 66 there, for names under the blobs; names are
  beside them now).

## 2. The names

**The rule** (`FanLayout.names`), as in the mock-up:
- **Where:** on the far side of its blob, along the line from the Sidekick's middle through the blob,
  8 points past the blob's edge.
  - Its pill is anchored there by its near side: its right edge when the line points left, its left
    edge when it points right, centred when it points mostly up or down; the same up and down.
  - So on the right side: left of its blob, a little above or below for the outer ones.
- **On a soft dark pill** (45% black, as in the mock-up), Prism's lettering at 13.5 points. The shadow
  it had is gone.
- **At most 1.5 blobs wide** (93 points with the pill), ending in "…".
- **Pushed back onto the screen** (6 points from the sides, below the status bar) and above Prism's bar.
- **Never on a blob, a badge, the Sidekick or another name:**
  - each placement is measured against all of them;
  - if it would cover one, straight beside its blob (on the side away from the Sidekick) is tried;
  - then both again with the name cut to one blob's width;
  - the clearest wins.
- **Blobs and badges are drawn after every name,** so they always lie over the names.
- **A tap on a name is a tap on its blob,** wherever the name is now. Within 40 points of Prism's
  button, still Prism's (190).

## 3. The Hovering range: −48 to 15

The owner's choice after trying 190:
- −60 was too easy to flick away when grabbing it;
- 36 made the panel too narrow ("15 is plenty").

**The values:**
- `GAP_MIN` −48, `GAP_MAX` 15. The default stays 8.
- Kept values outside the range are brought into it when read, as always.

**At −48, 58.1% of its glass is past the edge:** its window is its glass (74 points at the standard
size) and 5 round it. So −48 puts 43 of the glass's 74 points past the edge. As before, below 0 the
points scale with its size, so the share is the same at any size.

**The panel is about 21 points wider:** its width rule leaves room for the furthest Hovering, now 15
instead of 36.

**The grab strip still comes at −48:** about 36 points of the Sidekick show, less than 80.

**Checks:**
- "Hovering at its closest (−48), 58.1% of it past the edge" prints the share measured.
- "at its farthest" uses 15.
- The panel's Hovering check is now at 0, 8 and 15, and its width check uses 15.

## 4. The rest of the panel gone while a dial is held

**What the owner sees:** while a finger is on a dial, nothing of the panel is drawn (`REST_SEE` 1.0):
no body, no edge, no hairline, no contents. Only the "Where it rests" block, solid on its own backing.
The same timing: the quick spring, and 0.1 s after a let-go.

**A trap avoided:**
- The panel used to stop drawing altogether when it was all but clear (`fade < 0.004`), and that
  would have taken the block with it.
- Now it skips only its own body and contents, and still draws the block.

**Checks:**
- "touched": the rest at ≤ 0.06;
- the pixel check: the rest at ≤ 6% of solid;
- the 1.5 s drag and the two strokes: ≤ 0.06;
- solid again after a let-go within 0.3 s (about 0.23 s: 0.1, then the spring to 0.97).

## 5. The two 189 S25 puzzles, by reading

**"the rest 0" (both dial checks, 4 of 4):**
- **The old sample point** for "the rest of the panel" was on the Labels row, near the top of the
  contents.
- **Earlier in part 5,** the test taps "In Prism" and "Over other apps", the two switches at the very
  bottom. Bringing them into sight scrolls the panel to its end (about 96 points on the S25), and
  nothing scrolls it back. The dials stay in sight, so their presses don't scroll either.
- **So on the S25 the Labels row** (82 points into the contents) was above the panel's top, over
  nothing: 0. On the taller S26 the scroll is smaller, and it stayed inside, as 188's pass there shows.
- **The fix:** the point is now in the panel's left margin, 5 points in, halfway down its height.
  - Only the panel's own body is ever drawn there (the block starts 10 points in, the contents 20).
  - It's inside the panel whatever the scroll.
- **A new check proves it isn't vacuous:** "with no dial held, the point read for 'the rest of the
  panel' is solid" (≥ 250 of 255). So the held check's 0 means the panel is gone there.

**The strip "beside it false" (4 of 4):**
- **190's placement is right; the check was wrong.**
- The strip and the Sidekick are the same kind of window with the same flags, and the strip is put 24
  points above the Sidekick's own window place (8 in 189). So on the screen it's beside it.
- The check compared the strip's real place on the screen with the Sidekick's `y`. That `y` is its
  window place plus a stored window-to-screen offset (`lensOffY`), and every report shows that offset
  missing the 39 points (`lensMid` against "the old figure"). So the Sidekick looked 39 points lower
  than it is, and the strip "not beside".
- **Now the check compares the strip with the Sidekick's own window as Android places it on the screen**
  (`lensScreen`, measured as the strip's is). It prints both spans in points.
- **What this means for the owner:** the strip wasn't misplaced in 189 or 190; it was too small (56 in
  189), which 190 changed to 80 and ±24.

## 6. The navigation mode

**Every report's header** now gives it beside the screen: "3-button", "2-button" or "gestures".
- It's Android's own setting (`config_navBarInteractionMode`, as the system bar is drawn for it).
- If that can't be read, it's a guess from the insets, marked "(from the insets)".

**Only gesture navigation has a Back swipe at the sides.** So the strip check is now two:
- "resting past the edge, a grab strip 80 points wide and 48 taller than it, at the edge, beside it":
  always;
- "resting past the edge, its grab strip kept from Back, within Android's 200 points per edge": on
  3-button or 2-button navigation it's SKIPPED, "not applicable: 3-button navigation (no Back swipe at
  the sides)".

**The bars:** nothing is hard-coded. The panel uses the real bottom inset (on the S25, the button bar's
height) and Prism's own bar top, as before.

## The checks (part 4, phone)

1. **"its fan at six places, high, in the middle and low on each side: no blob, name, badge or the
   Sidekick on another, nothing off the screen or on Prism's bar".**
   - **How:** with the person's own menu (its own names and badges), before the test puts its own in.
     The layout is worked out for the Sidekick resting at each side, at 15%, 50% and 80% of the screen's
     height, on this phone's real screen. Prism's bar counts if Prism is in front.
   - **For each place it prints** the smallest gap, how far the fan was turned, and how much larger it
     was made. It names any overlap ("name 2 on blob 3").
   - **It prints the smallest gap overall.**
2. **"its open menu: no blob, name, badge or the Sidekick on another, nothing off the screen or on
   Prism's bar".**
   - **How:** the real open menu (the test's own five), as it is laid out on the screen.
   - **It prints** the smallest gap of each kind (blob–blob, name–blob, name–badge, name–Sidekick, to
     the edge, to Prism's bar), and the names as shown.

**What I could check here:** a line-for-line copy of `lay`, `names` and `gaps` in Python, for the S25
(384 × 832) and the S26 (411 × 891), at all six places, in Prism and over other apps. The names were
"Facebook", "Scan", "Google Calendar", "WhatsApp" and "Instagram", with badges on two.
- **No overlaps anywhere,** and nothing off the screen or on the bar.
- **The smallest gap was 3.0 points** (S25, left side, low, a name to a badge). Most were 4 to 8.
- **In the corners** the fan turned 24° to 40° and was made 10% to 20% larger.
- "Google Calendar" was cut to "Google Ca…".

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 81 right, 1 wrong, 1 skipped, of 83 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.

**Build 191:**
- `Prism build 191`, `0.152.0+219`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- Its `classes.dex` has `fanCheck`, `lensScreen` and `config_navBarInteractionMode`. Its `libapp.so` has
  "Prism build 191", "The fan and its names", "its fan at six places", "not applicable" and the header's
  "navigation:".
- sha256 `0d5a41b58e555fc8074b8d0d99460d031c0f640620a1458b82b93f841db1a746`, 18,878,922 bytes.
- Link: in the next commit.

## Where I could be wrong

1. **The Python copy measured text with an average letter width,** not the real font. On the phone,
   names are measured with Prism's own lettering, and the checks print the real gaps.
2. **A larger arc puts the blobs further from the Sidekick** in a corner: about 20 to 35 points
   further. It keeps them apart and on the screen, but it's a longer reach for the thumb.
3. **A name can end up a little off its exact radial spot,** pushed onto the screen or beside its blob
   to stay clear. The mock-up does the same at the edges.
4. **The pills are new.** They make the names readable over any app, as the mock-up shows, but it's a
   visible change beyond where the names go.
5. **The person's own menu is what the six-place check uses.** With fewer blobs, or other names, the
   numbers differ from mine.

## On the phone

**What to look at:**
- With the Sidekick high on the right in Prism (the screenshot's case), its blobs fan down and left,
  evenly spaced, no pile-up.
- Each name beside its blob, away from the Sidekick, never over another blob or a badge; long names end
  in "…".
