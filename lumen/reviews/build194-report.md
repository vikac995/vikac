# Build 194 report: safe from Back, and quicker blobs

Brief: `tasks/BUILD194.md` (the review chat, 20:56 and 21:02). 193 was already pushed when these came, so
they are 194, and the app list becomes 195.
1. The "Dismiss" pill right after the "Sidekick" title.
2. The Sidekick's spot kept from Android's Back swipe at all times (the owner's video of 192).
3. Its blobs back sooner after a drag.

**Only the preview has run it.** All three are Android's.

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickPanel.kt` | "Dismiss" right after the title (`dismissBox`, `dismissTouch`: 12 points after it, a 48-point touch that stops short of the ✕'s). The panel keeps the Sidekick's spot from Back too (`excludeDials`). The header's geometry in the test state. |
| `android/.../MainActivity.kt` | **The menu:** keeps the Sidekick's spot from Back (`keepSpotFromBack`), following it during a handed-on drag (`followSpot`, at most every 50 ms). **At let-go:** its blobs open at once round where it is going (`reopenSoon`, `openMenu(centre)`, `restTarget`). A closing menu only ever removes itself. Test state: `menuExcluded`, `menuReopenLagMs`, `menuReopenAt`. |
| `lib/fit/shell.dart` | The checks below. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 194, "Safe from Back, and quicker blobs", `askedTest = 'button'`; `0.155.0+222`. |
| `DESIGN.md` | §6: the header; the blobs at let-go; the spot kept from Back. |
| `tasks/BUILD194.md`, `CHANGELOG.md` | The brief; build 194. |
| `releases/prism-build-194.apk` | The build. |

## 1. "Dismiss" right after the title

**The header:** [Sidekick] [Dismiss] … [✕].
- The pill begins 12 points after the title.
- Its touch is the pill and 6 points round it: 48 points tall. It's cut off before the ✕'s touch,
  which reaches 50 points in from the right.
- At a large text size, if it doesn't fit there, it goes on a line of its own under the title, at the
  left.

**Check:** "'Dismiss' right after the title, its touch 48 tall and clear of the X's": at least 11.5 points
after the title (or on its own line), the touch at least 47.5 tall and ending before the ✕'s.

## 2. The Sidekick's spot kept from Back, at all times

**Why Back won in the owner's video, by reading:**
- Android honours a window's request to keep its area from Back only where no touchable window lies
  over it.
- The Sidekick's own window (and, past the edge, its strip) asks for its spot. But with its blobs out,
  its menu covers the whole screen and takes every touch.
- So while the blobs were out, the Sidekick's own request counted for nothing, and the menu asked for
  nothing: a grab at the edge went to Back.
- The same was true with its panel open, which also covers the whole screen.
- The review chat's guess was right.

**Now** the spot is the Sidekick's window and 24 points above and below it, from the edge, at least 80
points wide (as its strip):
- **Resting:** its own window asks (all of it, at Hovering 0 to 15, as before), or its strip does when
  it is past the edge (as in 190).
- **With its blobs out:** the menu window asks for the spot.
- **While it is dragged with its blobs out:** the spot follows it, at most every 50 ms.
- **With its panel open:** the panel asks for the spot, on its side, besides the two dials on the far
  side (186).

**Android's 200 points per edge:**
- Only the window on top counts where windows overlap.
- So one request of 132 points (the standard Sidekick, 84, and 48) is in force on that edge at any time.

**Check** (part 5, gesture navigation only; on button navigation "not applicable"): "at Hovering −48 with
its blobs out, on each side, its spot is kept from Back (its glass and 24 points above and below)".
- **How:** the Sidekick is carried to each side, its blobs opened.
- **The menu's request must:** start at the edge, reach across its glass, and run from 24 points above
  the glass to 24 below.
- **It prints** both spans.

## 3. Its blobs back at once after a drag

**192:** let go after a drag with its blobs out, they came out again only once the Sidekick was still (up
to about 0.6 s).

**Now** (`reopenSoon`):
- **At let-go,** the Sidekick's resting spot is decided at once (`throwIt`'s target).
- **Its blobs open straight away round that spot:** the new fan grows out of where it's going while it
  glides there, and is out about as it arrives.
  - Where that is on the screen is found from where the Sidekick was just before the let-go, plus how
    far its window is going. This doesn't depend on the window-to-screen offset that misled earlier
    checks.
- **A short glide is the same:** they open at once, and only the glide is shorter.
- **The exceptions stay:** tucked (or sent away, no longer possible by a drag): they stay in. A drag
  Android cancels glides back to where it began, and then, as in 192, they come out once it's still.

**The old menu goes at the let-go** (its blobs are in by then, after 0.15 s), so the new one can open. A
closing menu now only ever takes itself away: before, its last frame could have taken away whatever menu
was up, the new one included.

**Check** (part 4): "dragged with its blobs out, let go, its blobs come out again at once, round where it
comes to rest":
- opened again once, within 120 ms of the let-go;
- round a spot within 6 points of where it then rests.

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 81 right, 1 wrong, 1 skipped, of 83 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.

**Build 194:**
- `Prism build 194`, `0.155.0+222`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- Its `classes.dex` has `menuExcluded`, `menuReopenLagMs`, `dismissTouch`, `panelHeader` and "where it is
  going". Its `libapp.so` has "Prism build 194", "Safe from Back, and quicker blobs" and the new checks.
  The safe-zone check's name has a true minus sign, so it's stored as UTF-16, and was found that way.
- sha256 `4d48373cfeb61d314f77314d3ecdc8959560887d18799abb92037cfa8daec31e`, 18,878,922 bytes.
- Link (checked: answers 200, same sha256): https://github.com/vikac995/vikac/raw/fdb124498e287dbc064c615b82e7a0f4ec8b4a56/lumen/releases/prism-build-194.apk

## Where I could be wrong

1. **None of it has run on a phone.**
2. **Android may still cap or ignore the request near the very bottom of the screen** (where Home is
   swiped). A Sidekick resting low may still lose some edge swipes there.
3. **The blobs come out where it is going while it is still gliding there:** for a moment they fan from
   a spot the Sidekick hasn't reached yet. With its glide (about 0.35 s, with no overshoot) and the fan's
   opening (about 0.3 s), they should meet about together. A long glide could show them first.
4. **The old menu's blobs vanish at the let-go** if a very quick drag (under about 0.15 s) let go before
   they had folded in.

## On the phone

**What to look at:**
- With the blobs out, grab the Sidekick at the edge on either side: no Back arrow.
- Drag it with its blobs out and let go: they fan out again right away round where it lands.
- The panel's header: "Sidekick", "Dismiss" just after it, the ✕ on the right.
