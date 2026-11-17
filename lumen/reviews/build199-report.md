# Build 199 report: above the navigation bar

Brief: `tasks/BUILD199.md` (the review chat, the lead, 17 November, 12:24 and 12:50): part 2 of the owner's
low-Sidekick bug. The Sidekick could rest over the gesture bar.
- 198 fixed its fan there.
- The app list becomes 200, the test store 201, search 202.

**Only the preview has run it.** The Sidekick is Android's.

## The cause (by reading, sent before 198)

**All three ways the Sidekick comes to rest** (going to its side, thrown, tucked) kept its window's `lp.y`
between 48 points and the screen's height less its window and 48 points. Two things were wrong with the
lower limit:
1. **Mixed places.** `lp.y` counts from below the status bar, not from the screen's top (the about
   39-point offset measured in the 190s, `lensOffY`). But the limit was the screen's full height. So the
   window could come down about 39 points lower than meant: its bottom about 9 points from the screen's
   bottom, its glass over the gesture bar.
2. **No navigation-bar inset.** The limit never looked at the navigation bar. With 3-button navigation
   (about 48 points) it would have rested on the buttons.

## The fix

| File | What changed |
|---|---|
| `android/.../MainActivity.kt` | **The lowest:** `restBottomMost` puts the window's bottom 48 points above the navigation bar, on the screen. It takes the screen's whole height and the navigation bar's inset from the window's own insets (or the largest window Android allows), and the window's measured offset (`windowOffY`, kept for when it can't be measured; the status bar's height before the first measure). **The highest:** unchanged, 48 points below where the window's place begins. **Left too low by an earlier build:** it rises to the lowest once it's laid out (`keepAboveBars`, not for the timer, nor when tucked or docked). **Test state:** `restLimits` (the screen's height, the navigation bar's, the lowest the window's bottom may be, the window's size and its offset). |
| `lib/fit/shell.dart` | Part 5: "carried to the very bottom and let go, it rests 48 points above the navigation bar, never over it". |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 199, "Above the navigation bar", `askedTest = 'button'`; `0.160.0+227`. |
| `DESIGN.md` | §6: how high and low the Sidekick rests. |
| `tasks/BUILD199.md`, `CHANGELOG.md` | The brief; build 199. |
| `releases/prism-build-199.apk` | The build. |

**One place:**
- Since 198, all three ways it comes to rest, and the fan's test, use `restTopMost` and `restBottomMost`.
  So the fan's "at the very bottom" place is now the new, higher lowest.
- The workout timer's lens uses the same limits.

**On the S26, by arithmetic** (891 points tall, a gesture bar of about 16 to 24 points):
- the Sidekick's middle at its lowest is about 777 to 785 points down;
- it was about 840 before;
- so it rests about 55 to 63 points higher at most.

## The checks (part 5)

**New:** "carried to the very bottom and let go, it rests 48 points above the navigation bar, never over
it".
- **How:** the Sidekick is carried to 4 points from the screen's bottom, at its side, and let go.
- **Its window's bottom must be:**
  - within 2 points of the lowest it may be;
  - at least 46 points above the navigation bar's top.
- **It prints:** the screen, the navigation bar, the window's offset and where it rested.

**The fan checks (198)** now place "at the very bottom" at the new lowest.

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 81 right, 1 wrong, 1 skipped, of 83 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.
- **The new check is Android's,** so the preview doesn't reach it.

**Build 199:**
- `Prism build 199`, `0.160.0+227`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- **Its `classes.dex` has:** `restLimits`, `lowestBottom` and "lower than it may rest now".
- **Its `libapp.so` has:** "Prism build 199", "Above the navigation bar" and the new check.
- sha256 `224bd73bfc7f3e07782d738ad6a5b4fac5de5240670dece81603ff6fd0611e98`, 18,878,922 bytes.
- Link: added once it is pushed and checked.

## Where I could be wrong

1. **None of it has run on a phone.**
2. **The navigation bar's height comes from Android's insets.**
   - **Gesture navigation:** some phones report only the thin handle's height (about 16 points) for
     the navigation bar. The 48 points above it still keep the Sidekick well clear.
   - **The gesture bar hidden** (One UI can hide it): Android may report 0. Then it rests 48 points
     from the screen's bottom.
3. **The window's offset** is measured from where its window really is. Until it has been laid out once,
   the status bar's height stands in for it (what it has been on every phone so far).
4. **It rests higher than before at the bottom** (about 55 to 63 points on the S26). A Sidekick the owner
   had left right at the bottom rises that much when it comes back.
5. **A tucked Sidekick left too low stays where it is** until it's brought out. Then it rests above the
   bar.

## On the phone

**What to look at:**
- Carry the Sidekick to the very bottom at either side and let go. It settles with a clear gap above the
  gesture bar, never on it.
- In Prism, tap it there. Its fan opens up and clear (198).
