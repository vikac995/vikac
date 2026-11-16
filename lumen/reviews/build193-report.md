# Build 193 report: dismiss only from its menu

Brief: `tasks/BUILD193.md` (the review chat, 20:52): a big owner decision, after they threw the Sidekick
at the top cross by accident. It replaces the app list, which moves to 194.

- **The one behaviour change:** the Sidekick is sent away only from its settings panel. Dragging or
  flinging it never sends it away.

**Only the preview has run it.** The Sidekick, its panel and its window are Android's.

## Files changed

| File | What changed |
|---|---|
| `android/.../MainActivity.kt` | **Gone, for the Sidekick:** its cross (`rise` does nothing for it), its pull (`follow`), the fling at the cross (`throwIt`), the faint ring and its measures. Also gone: the top place and its helpers (`topClear`, `CROSS_BELOW`, `crossOff`, moving the cross's window), and `FAINT`, `crossFirst`, `crossMost`. **Kept for the timer's lens** (and a pinned thing's): its cross at the bottom, with Pause and Count up. **New:** `dismissFromPanel` (the old dismiss, shrinking away where it rests, no cross: `close(viaCross = false)`) and `dismissSidekick`. Test state: `sidekickDismissals`, `sideGone`. The menu's `dragLens` takes `toTop` instead of `toCross`. |
| `android/.../SidekickPanel.kt` | The "Dismiss" pill in the header, left of the ✕: drawn, tapped, and its place for the test (`close.dismiss`). At a large text size, if it doesn't fit beside the title, it goes on a line under it. |
| `lib/fit/shell.dart` | The dismiss checks replaced (below). |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 193, "Dismiss only from its menu", `askedTest = 'button'`; `0.154.0+221`. |
| `DESIGN.md` | §6: the Sidekick is sent away only from its panel; the panel's header. |
| `tasks/BUILD193.md`, `CHANGELOG.md` | The brief; build 193. |
| `releases/prism-build-193.apk` | The build. |

## 1. No dismissing by dragging or flinging

**The Sidekick has no cross any more:** nothing shows when it is picked up, nothing pulls it, and a
fling toward the top middle only moves it. A carry anywhere just moves it: to its side, or tucked
into it, as always.

**The code is removed, not switched off:**
- **Gone:** the top cross's place and its helpers, the faint-at-once ring, its "near" fading, the
  Sidekick's thin-ring drawing, the fling-up rule, and the Sidekick's pull toward a cross.
- **Kept, unchanged:** what the workout timer's lens (and a lens of a pinned thing) still uses. Its
  cross at the bottom, Pause and Count up, its pull, its fling down, and the swallow when dropped on it.

## 2. "Dismiss" in its panel

**Where:** hold the Sidekick and its panel opens, as today. Its header has a pill reading "Dismiss", to
the left of the ✕.
- **Style:** a pill like the panel's own controls (Prism's lettering, 15 points, on a soft ground of
  the panel's ink). It's never round, so it can't be mistaken for the ✕, which only closes the panel.
- **At a large text size:** if "Dismiss" doesn't fit beside the title, it goes on a line of its own
  under it, at the right.

**A tap on it:**
- **First the panel closes** (back into the Sidekick, as with the ✕).
- **About 0.3 s later, the Sidekick is sent away exactly as before:**
  - it shrinks away where it rests (the same 0.15 s shrink, with no cross to fall into);
  - `sideGone` is set, so it stays away until the next app is opened from Prism;
  - it comes back where it was (or tucked, if it was).

## 3. The tests

**Removed** (part 5, from 190): the cross's place, faint at once, the cancelled carry to the top, carried
to the top and dismissed, flung up and dismissed.

**Kept, changed:** "carried to the top, the notification shade never comes down". Now carried there it's
not dismissed, and Prism keeps the focus.

**New:**
1. **"carried to the top middle and let go, it only moves: it is still there".**
2. **"flung up fast toward the top middle, it only moves: it is still there":** carried halfway down
   first, then a fast flick 160 points up toward the top middle. Prism keeps the focus.
3. **"held, its panel's 'Dismiss' sends it away, and the panel closes":** the panel open, then a tap on
   "Dismiss". It must be gone, the panel closed, `sideGone` set, and one dismissal from the panel
   counted.
4. **"sent away from its panel, it comes back when brought back":** with the test's own bring-back.
5. **192's "carried onto the cross with its blobs out" is now "carried to the top middle with its blobs
   out, it only moves, and its blobs come out again".**

**Test area:** badge 193, "Dismiss only from its menu", `askedTest = 'button'`.

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 81 right, 1 wrong, 1 skipped, of 83 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.

**Build 193:**
- `Prism build 193`, `0.154.0+221`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- Its `classes.dex` has `sidekickDismissals` and "sent away from its settings (Dismiss)". Its `libapp.so`
  has "Prism build 193", "Dismiss only from its menu", `close.dismiss` and the new checks.
- sha256 `f86fb8572d80f0f274ab1c4a1b7436d537e86009c4ed1f53d660b126ff523d6d`, 18,878,922 bytes.
- Link: in the next commit.

## Where I could be wrong

1. **None of it has run on a phone.**
2. **The test's bring-back** is its own ("side on"), not opening an app from Prism. That path (`sideGone`
   cleared when an app is opened from Prism) is unchanged from before, but this build doesn't test it.
3. **The pause between the panel closing and the Sidekick going** (0.28 s) is my choice, so the two
   don't happen on top of each other.
4. **"Dismiss" has no pressed look yet:** it doesn't darken under the finger. It's a plain tap target,
   36 points tall, with 4 points of slack round it.

## On the phone

**What to look at:**
- Drag or fling the Sidekick anywhere, the top included: it only moves, nothing appears at the top.
- Hold it: its panel's header has "Dismiss" left of the ✕; tap it: the panel closes, the Sidekick
  shrinks away; open an app from Prism and it's back where it was.
