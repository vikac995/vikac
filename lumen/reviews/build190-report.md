# Build 190 report: dismiss at the top

Brief: `tasks/BUILD190.md` (the review chat, 19:04, 19:14 and 19:21: the GO after the owner tried 189).

1. **A bigger grab strip** at Hovering past the edge, from the owner's try of 189 ("a bit hard to hit",
   "I accidentally did the back gesture a few times").
2. **The 188 swap tap on the S26** (a fix).
3. **Dismissing the Sidekick at the top** (the one behaviour change), as planned in `QUEUE-after-186.md`.

**No mock-up for the top cross,** as the review chat agreed: it's the existing ring, moved, and the owner
approved the behaviour in words.

**Only the preview has run it.** The cross, the Sidekick's menu and the hand-off are Android's.

## Files changed

| File | What changed |
|---|---|
| `android/.../MainActivity.kt` | **The grab strip:** 80 wide (`GRAB`), 24 above and below (`GRAB_PAD`); the Sidekick's own exclusion given up while the strip covers it; touches on a strip taken by Android logged (`gripCancels`). **The swap tap:** the Sidekick's fan keeps its blobs and their names above Prism's bar; within 40 pt of Prism's button a blob's name doesn't count as the blob; `menuTap` records what the menu did with its last tap. **The top cross:** `crossAt()`, `topClear()`, `crossOff`, the cross's window moved to it (`goWhereTheCrossIs`); shown faintly at once (`FAINT` 0.3), clearer as it nears; a fling up throws at it; `fusing()` and the "fused" message are gone. Test state: `crossX`, `crossY`, `topClear`, `crossFirst`, `crossMost`, `prismFocus`, `menuTap`. |
| `lib/fit/bubble.dart`, `lib/fit/shell.dart` | Prism no longer handles "fused" (the button's gulp). The button test: the swap check prints `menuTap`; the Sidekick's dismiss checks use its cross at the top; new checks. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 190, "Dismiss at the top", `askedTest = 'button'`; `0.151.0+218`. |
| `DESIGN.md` | §6: dismissing the Sidekick is at the top. |
| `tasks/BUILD190.md`, `CHANGELOG.md` | The brief; build 190. |
| `releases/prism-build-190.apk` | The build. |

## 1. A bigger grab strip, and where Back wins

**From the owner's try of 189** (S26, over the Claude app): at Hovering −60 only a thin sliver shows; "a
bit hard to hit", and Back happened by accident a few times.

**The strip, now:**
- **80 points wide from the edge** (was 56), about the tucked grip's 76. It's added whenever less than
  80 points of the Sidekick shows, so at any Hovering below about −4.
- **The Sidekick's height plus 48:** it reaches 24 points above and below it (was 8). At the standard
  size, 84 + 48 = 132 points tall.
- **Kept from Back** (`systemGestureExclusionRects`, all of it), as before.

**Android's limit, 200 points per edge:**
- It's per edge, the same on any phone. On the S26, about 891 points tall, that's a little under a
  quarter of the edge.
- **Android counts each window's request in full, from the top window down,** until the 200 are used.
  - The strip asks for 132.
  - The Sidekick's own window used to ask for its 84 as well. Together that's 216, over the limit,
    and the lower of the two would have been cut short by 16.
  - So while the strip covers the Sidekick, the Sidekick's own window now asks for nothing. The strip
    asks for 132, well inside 200.
  - At the largest Sidekick (92 points), 140.
- **What the limit can't do:** the app can't read what Android actually granted, only what it asked
  for. The check prints what was asked, against the 200.

**Where Back wins:**
- **When:** a touch that began on a strip (resting past the edge, or tucked) and is then taken away by
  Android (ACTION_CANCEL: most likely its Back gesture).
- **What's written to the recorder:** "a touch on its grab strip was taken by Android (probably Back),
  at y N points; the strip x,y w × h points", and which strip.
- **Counted** in the test state (`gripCancels`).
- So one "Send what just happened" after an accidental Back shows exactly where it won.

**The check** (at Hovering −60): "resting past the edge, a grab strip 80 points wide and 48 taller than it,
at the edge, kept from Back within Android's 200 per edge":
- at least 80 wide, at least the Sidekick + 48 tall, at the edge, beside it;
- its exclusion request covers all of it, and the total asked at that edge is ≤ 200;
- it prints the sizes, what was asked (and "OVER" if more than 200), and how many strip touches
  Android has taken so far.

## 2. The swap tap on the S26

**What failed:** "with the Sidekick's blobs out, one tap on Prism's button closes them and opens Prism's".
- 3 of 4 times on the S26: the Sidekick's menu closed, but Prism got no tap.

**The cause, by reading:**
- **Not the "thinks nothing is in front" flag.** That was the Sidekick's own last touch (the earlier tap
  that opened its menu), and the hand-off uses neither.
- **A blob took the tap:**
  - The menu checks the blobs first (`at()`).
  - A blob's tap area, with names on, includes its name: 80 points wide, reaching 62 below the blob's
    middle.
  - Blobs could sit as low as 100 points above the bottom, so a name could reach down over Prism's
    button (about 57 points above the bottom).
- **It fits the run:** the Sidekick rested low on the right (its middle at about 370, 798 points on a
  411 × 891 screen). Its fan reaches about 178 points to the left, which can put its lowest blob right
  above the button, at about 205.
- **The old details couldn't confirm it:** they didn't say what the menu did with the tap. Now they do.

**The fix:**
1. **In Prism, the Sidekick's blobs and their names keep above Prism's bar.** The lowest a blob may sit
   is now 66 points above the bar's top (44 without names). So Prism's button is always beside the
   blobs, and the tap is handed to Prism.
2. **A safety net:** within 40 points of Prism's button, with Prism in front, a blob's name doesn't count
   as the blob. A blob's own circle still does, but (1) keeps blobs off the bar.
3. **The record:** `menuTap` says what the menu did with its last tap:
   - "on blob N of 5";
   - "beside the blobs, on Prism's button: handed to Prism";
   - "beside the blobs, N points from Prism's button";
   - "on the Sidekick".
   The swap check prints it.

## 3. Dismissing the Sidekick at the top

**Where:** the Sidekick's cross is now at the top, in the middle, in Prism and over other apps alike.
- **Below the status bar and the camera:** the cross's middle is 52 points below where they end (read
  from Android's window insets).
  - The ring swollen round the Sidekick is 38 points, drawn 1.22 times larger: 46. So 6 points to spare
    at its largest.
- **The cross's window is moved there** when the Sidekick is picked up.
- **Screen vs window coordinates:** a floating window's own coordinates can be offset from the screen's
  (the status bar). The offset is measured from the cross's own window (`crossOff`), so the cross lands
  where it's meant to on the screen.

**Shows at once, faintly:**
- As soon as the Sidekick is picked up, the ring shows at 0.3.
- It grows clearer the nearer the Sidekick is carried: fully within its pull (60 points), still at 0.3
  nearly half the screen away.
- It lights up as before when letting go would dismiss it.
- **Before:** it was hidden until the Sidekick was carried into the bottom quarter.

**A fling up toward it dismisses it:**
- The mirror of the old fling down: upward faster than 700 px/s, coasting into the top 30% of the
  screen, within 120 points of the middle.
- Carried there and let go dismisses it, as before at the bottom.

**In Prism:**
- Dropping the Sidekick on Prism's button no longer sends it away (`fusing()` is gone), and Prism's
  button no longer gulps.
- Prism's button position is still kept, for the swap tap (188).

**The workout timer's lens:** left exactly as it was. Its cross, Pause and Count up stay at the bottom;
it still flings down.

**The notification shade:**
- A drag of the Sidekick is the Sidekick's window's own touch from start to end, so carrying it to the
  top never opens the shade.
- The test checks that Prism still has the focus after carrying it up and after the fling. The shade
  coming down would take it.

## The tests (part 5, phone)

- **The grab strip at −60** (changed from 189's 56-point check): see section 1.

- **"its cross is at the top in the middle, clear of the status bar and the camera":**
  - the cross's middle within 2 points of the screen's middle;
  - its swollen top at or below where the status bar and camera end;
  - in the top fifth.
- **The cancelled carry and the dismiss now go to the top cross:**
  - "carried to the top and the touch cancelled, it is not dismissed and goes back where it began";
  - "carried to the top middle and let go, it is dismissed".
  Both use where Android says the cross is.
- **"picked up, its cross shows faintly at once, and fully when it is carried there":** first shown
  0.25–0.45, at most ≥ 0.95.
- **"carried to the top, the notification shade never comes down":** Prism keeps the focus.
- **"flung up toward the top middle, it is dismissed":** with Prism keeping the focus.
- **The swap check** prints what the Sidekick's menu did with the tap.

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 81 right, 1 wrong, 1 skipped, of 83 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only)
              (an earlier run on the prep gave 63: the old preview-only miss "app list: the flick wakes
              neither the magnifying glass nor a card", seen in 8 earlier runs; nothing here touches the app list)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.

**Build 190:**
- `Prism build 190`, `0.151.0+218`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- Its `classes.dex` has `gripCancels`, `edgeAskedDp`, `menuTap`, `crossFirst`, `topClear` and the
  "probably Back" line. Its `libapp.so` has "Prism build 190", "Dismiss at the top" and the new checks.
- sha256 `e20b7266eb1a3013b46090893f22faef6ddd96fecccc34ccbc0ea38991683f54`, 18,878,922 bytes.
- Link: in the next commit.

## Where I could be wrong

1. **The real Back zone may be wider than the strip** on some phones or settings (Back sensitivity is a
   setting). The recorder lines will show where it still wins.
2. **The swap cause is by reading,** and the old details couldn't show it. The new `menuTap` will say
   on the phone what the menu did with the tap.
3. **Keeping the Sidekick's blobs above Prism's bar** changes where its fan sits when it rests low in
   Prism. The fan turns upward more. If it ever can't fit, the blobs that don't fit still go below.
   The name safety net then still gives Prism its button.
4. **Some phones report the status bar differently** (`currentWindowMetrics` from a non-visual
   context). If it reads 0, the status bar's own height is used instead.
5. **A fling up is now a way out.** Someone flinging the Sidekick up just to move it higher, toward the
   middle, could dismiss it. A fling that doesn't head for the top middle (within 120 points) only
   moves it, as before.
6. **The strip now takes touches over more of the app** beside a Sidekick resting past the edge: up to
   56 points next to it at −60, 24 points above and below. That's the trade the owner asked for.

## On the phone

**What to look at:**
- At Hovering −60: easy to tap and to drag from the edge, without Back.
- Pick up the Sidekick: a faint ring at the top in the middle at once, clearer as it nears; let go on
  it, or fling up toward it: the Sidekick goes.
- In Prism, the same.
- Dragging it to the top never pulls down the notification shade.
- With the Sidekick resting low in Prism, its blobs stay above Prism's bar, and a tap on Prism's
  triangle swaps to Prism's blobs.
