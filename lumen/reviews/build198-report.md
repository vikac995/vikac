# Build 198 report: the fan, never squeezed

Brief: `tasks/BUILD198.md` (the review chat, the lead, 17 November, 12:24 and 12:50; a bug from the owner's
screenshot).
- **The bug:** the Sidekick resting very low at the right edge, in Prism. A tap opens its fan up and to
  the left with the blobs cramped and overlapping: the 5th half under the scan blob, the timer half under
  the dumbbell.
- **Two separate causes, read first and sent before building:**
  - 198 is the overlap.
  - 199 will be the bottom clamp (it can rest over the gesture bar).
  - The app list becomes 200, the test store 201, search 202.

**Only the preview has run it.** The fan is Android's.

## The cause (by reading)

**`FanLayout.lay` keeps its blobs' spacing at any size of arc,** so its seats can't collide. But:
1. **It tried arcs only up to 1.4 times their usual size** (and turned up to 120° either way).
2. **When none fitted, it returned the least bad,** and the menu's `seats()` then pushed every seat that
   was off the screen (or on Prism's bar) back onto it, each on its own (`coerceIn`, "as a last
   resort"). The seats below the limit were pushed up onto their neighbours: the screenshot.

**Why nothing fitted there:**
- The Sidekick's middle can be about 840 points down on the S26 (see 199 for why so low).
- In Prism the blobs must stay 45 points above the top of Prism's bar.
- So the fan had only the room up and to the left of the Sidekick. The five-blob fan needs about 112° of
  arc at its usual size, and 79° at 1.4 times. The room there was about 61° to 70°.

**Worked through** with the same search, at the S26's size, the Sidekick on the right, names on:

| The Sidekick's middle | Before (up to 1.4) | Now (up to 2.2) |
|---|---|---|
| 840, in Prism | nothing fits: 48 points off, so blobs pushed in one by one | fits at 1.6, turned 56° |
| 840, in Prism, the bar 26 points higher | nothing fits: 74 points off | fits at 1.8 |
| 840, over another app | fits at 1.4 | fits at 1.4 (the same) |
| 777 (where 199 will keep it), in Prism | fits at 1.4 | fits at 1.4 (the same) |

In every case the neighbours are the usual 23.8 points apart, edge to edge.

**Why the test missed it:** its fan check (191) put the Sidekick "low" at 80% of the way down, and never
lower than 48 points off the screen's bottom. It can really rest about 39 points lower than that (see 199).
The check also measured the arc before the menu's clamp, so it couldn't see the pile-up.

## The fix

| File | What changed |
|---|---|
| `android/.../FanLayout.kt` | **The arc may be up to 2.2 times its usual size** (1.4 until now), still smallest first, so it's only as large as it must be. **The last resort** (nothing fits at all): `intoBounds` moves the whole fan onto the screen as one, so its blobs keep their spacing and can never overlap. `usualGap` is the usual gap between neighbours. |
| `android/.../MainActivity.kt` | **The menu's `seats()`:** no more pushing each seat in on its own; it uses `intoBounds`. **The Sidekick:** one place for the highest and lowest it may rest (`restTopMost`, `restBottomMost`), used by all three ways it comes to rest (going to its side, thrown, tucked), and by the fan's test. Their values are unchanged in 198; 199 changes them. `windowOffY`: its window's measured offset. **The fan's test:** ten places (the very top, high, the middle, low, the very bottom, on each side), from the Sidekick's real limits, laid out as the menu shows it. The open menu's state adds `usualGap` and `cy`. |
| `lib/fit/shell.dart` | The fan check at ten places; it and the open menu's check require the blobs at least as far apart as usual. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 198, "The fan, never squeezed", `askedTest = 'button'`; `0.159.0+226`. |
| `DESIGN.md` | §6: the fan, up to 2.2 times, never squeezed. |
| `tasks/BUILD198.md`, `CHANGELOG.md` | The brief; build 198. |
| `releases/prism-build-198.apk` | The build. |

## The checks (part 4)

1. **"its fan at ten places, from the very top to the very bottom it may rest on each side: blobs as far
   apart as usual, no blob, name, badge or the Sidekick on another, nothing off the screen or on Prism's
   bar"** (was six places).
   - For each place it prints where the Sidekick's middle is, how far apart the blobs are, how far the
     fan turned and grew, and "moved in as one" if nothing fitted.
2. **"its open menu: blobs as far apart as usual, …"** (the real menu, where the Sidekick is): it adds the
   usual gap and where the Sidekick is.

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 81 right, 1 wrong, 1 skipped, of 83 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.
- **The fan checks are Android's,** so the preview doesn't reach them.

**Build 198:**
- `Prism build 198`, `0.159.0+226`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- **Its `classes.dex` has:** `usualGap`, "at the very top" and "at the very bottom".
- **Its `libapp.so` has:** "Prism build 198", "The fan, never squeezed" and the new checks.
- sha256 `3696ad8fd8db2d95fb74eed8b2c3cbf6c84375679c9af2c654c556eeb77b6a48`, 18,878,922 bytes.
- Link: added once it is pushed and checked.

## Where I could be wrong

1. **None of it has run on a phone.** The table above is worked by hand from the code, with Prism's bar
   where I think it is (about 786 points down on the S26). The phone's check prints the real figures.
2. **Larger arcs reach further:** at 1.6 to 2.2 times, the farthest blobs are up to about 390 points
   from the Sidekick, up the screen. They stay clear of the edges, and of each other.
3. **The last resort** (nothing fits even at 2.2) moves the whole fan, so its middle is no longer the
   Sidekick's. No case I worked needed it. If one does, the fan won't look centred on the Sidekick.
4. **Until 199, the Sidekick can still rest over the gesture bar.** 198 only makes its fan right there.

## On the phone

**What to look at:** let the Sidekick rest as low as it goes at the right edge, in Prism, and tap it. The
fan opens up and to the left, a little wider, with every blob clear of the next.
