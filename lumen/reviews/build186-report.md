# Build 186 report: the Sidekick's panel, fixed up

Brief: `tasks/BUILD186.md`. The flicker, from the owner's videos (16:10); the scope the owner confirmed (16:16);
no shade behind Prism's panel (16:18); the GO with one test-only fix (16:45).

- **The one behaviour change:** the Sidekick's panel, fixed up (the flicker, the held dial, the bars, the
  order), with Prism's own panel losing its shade to match.
- **The investigation:** why the dial's see-through flickered (below).
- **Test kit only:** the button test brings the Sidekick out of tuck before its first tap.

**Only the preview has run it.** The Sidekick's panel is Android's, so it isn't in the preview, and none
of its checks can run there. The preview ran Prism's side and the new "nothing dims" check.

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickPanel.kt` | The moment after a dial is let go (`SETTLE_MS`, 600 ms). The dials kept out of Android's back gesture (`excludeDials`). The held dial drawn solid on its own backing, the rest at 0.4. The panel's bottom above Prism's bar (`RestBubble.barTop`). The new order of its contents. New test state. |
| `android/.../MainActivity.kt` | Prism's bar top comes over the button channel (`RestBubble.barTop`). A test op `untuck` (test kit only). |
| `lib/fit/bubble.dart` | `tellButton` also sends where Prism's bar begins. |
| `lib/fit/shell.dart` | Prism sends its bar top. The shade behind Prism's settings panel is gone. The button test: the new part 5 checks, the "nothing dims" check, and the untuck before the first tap. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 186, "The Sidekick's panel, fixed up", `askedTest = 'button'`; `0.147.0+214`. |
| `DESIGN.md` | §6 (the Sidekick's panel: its order, the bars, the held dial, the moment after) and §7 (no dimming around panels). |
| `tasks/BUILD186.md`, `CHANGELOG.md`, `LESSONS.md` | The brief and the GO; build 186; one new lesson (the preview's stale build, below). |
| `releases/prism-build-186.apk` | The build. |

## The investigation: why the see-through flickered

**The cause, found by reading the code:** in 185, every time a finger came off a dial, the dial ended at
once (`endRuler`).
- **What ending did:** the panel sprang back to solid (the `clear` spring, about 0.3 s), and the Sidekick
  went back to where it was (`showSpot`).
- **The next touch** started the dial again: see-through again, the Sidekick back where the dial puts it.
- **So a dial turned in several short strokes,** the natural way with a thumb, flashed solid between every
  two strokes. That's the video's "O O O T T T" at roughly 0.3 s a stroke. In the other recording, which
  mostly stayed see-through, the dial was turned in one long stroke.
- **The same ending came from any let-go:** a slow lift, a tap on a half (one step), the end of a flick's
  coast, and Android cancelling the touch.

**A second way to end a stroke early:** Android's back gesture.
- The panel sits on the far side from the Sidekick, so its outer dial lies within a few dozen points of
  the screen's edge.
- With gesture navigation, a sideways stroke there can be taken by the back gesture. Android then cancels
  the touch, which ended the dial too.
- I can't tell from the videos whether this happened. It can, so it's prevented.

## What changed, point by point

1. **The moment after a let-go** (`SETTLE_MS` = 600 ms).
   - **Let go:** the dial's value is kept at once, as before. The panel stays see-through and the Sidekick
     stays where the dial put it.
   - **A finger back on a dial within 0.6 s** carries straight on: nothing flashes.
   - **After 0.6 s with no finger:** the panel is solid again, and the Sidekick goes back to where it was.
   - **Closing the panel** in that moment ends it at once.
2. **The dials kept out of the back gesture.**
   - Both dials' areas (plus 4 points at the sides and 10 above and below) are given to Android as
     `systemGestureExclusionRects` while the panel is open. A stroke that starts there stays the dial's.
   - They're cleared when the panel closes. Android 10 and later only.
3. **The held dial solid, the rest more see-through.**
   - While a dial is held (and in the moment after), the panel's body and the rest of its contents are
     drawn at 0.4 (before: 0.5).
   - The dial being held is drawn again on top, fully solid, on a backing of the panel's own colour, so its
     value reads clearly whatever is behind it.
   - Same `clear` spring (effects, 1600, ζ 1).
4. **The panel above the bars.**
   - **In Prism:** Prism tells Android where its bar begins (the top of the button, the same figure Prism
     uses for its own panels). The panel's bottom ends 8 points above it.
   - **Over other apps:** 8 points above Android's navigation or gesture bar (the window's inset), as
     before.
   - In the owner's screenshot (S25), the panel ran down over Prism's bar. It shouldn't now.
5. **The new order:** Labels, Icons, Colours, Look, then where it rests (the Hovering and Tucked in dials),
   then the In Prism and Over other apps switches last.
   - On both phones the dials should be on the screen when the panel opens, without scrolling.
   - The switches, rarely used, need a scroll.
6. **No shade behind Prism's own settings panel.**
   - The 40% layer above the bar is gone. A tap beside the panel still closes it.
   - **Left with their dim backdrop, as they're dialogs, not this panel:**
     - the settings sheet (`showPrismSettings`, 0.4);
     - the test report (0.5);
     - the recorder's "Send what just happened" (0.4).

## The tests

**Part 5 (the Sidekick's panel, Android only), new or changed:**
- **"both dials on the screen as it opens, without scrolling":** both dials' boxes inside the panel's,
  at scroll 0.
- **"in Prism, its bottom at least 8 points above Prism's bar":** against Prism's own bar top and
  Android's bar, whichever is higher. The details give both, and what Android was told.
- **"over another app, its bottom at least 8 points above Android's bar, its dials on the screen":** in
  the round trip over another app.
- **"<dial> touched, the Sidekick goes there, the rest of the panel see-through, the dial solid":** the
  rest at 0.4 (within 0.08), the held dial solid (alpha 1), no shade.
- **"a dial dragged for 1.5 s, the rest of the panel stays see-through the whole time":** three 0.5 s
  legs, back and forth. On every frame drawn from the moment it went see-through, the most opaque must
  be ≤ 0.45, over at least 3 frames.
- **"a second stroke straight after, it stays see-through in between":** a fresh stroke 0.2 s after the
  first ends. Still ≤ 0.45 throughout, and the frame count carries on (not reset by a solid moment).
- **"a moment after the last stroke, the panel is solid again":** over 0.97, and no longer in the moment
  after.

**Part 2 (Prism's settings), new:**
- **"with Prism's panel open, nothing dims the screen behind it":** a strip across the top of the screen,
  above where the panel comes, read from Prism's own picture before and after the panel opens. It must
  keep at least 90% of its light.
- **Proven both ways in the preview:** 63.0% → 63.0% without the shade; 63.0% → 49.3% with the shade put
  back for the proof (wrong, as it should be).

**Part 4, test kit only (the GO's fix):**
- **The problem:** on the S25 in 185, the Sidekick was tucked away when the test tapped it ("ignoring
  yes", its last touch "…, tucked"). A tap on a tucked Sidekick only brings it out, so its blobs never
  opened, and 10 checks after it went wrong.
- **The fix:** just before "a tap opens its blobs", a new test op `untuck` brings the Sidekick out, as a
  tap would (its own `comeOut`, and the grip closed), and waits 0.7 s for it to settle. If it was tucked,
  a NOTE says so.
- **Nothing the owner uses changes:** the op is called only by the button test.

**Test area:** badge 186, "The Sidekick's panel, fixed up", `askedTest = 'button'`.

## Results (preview, on the final code)

```
button test:  CHECKS: 80 right, 1 wrong, 1 skipped, of 82 (the same as 185: the panel's checks run only on a phone)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only)
  ok     settings: with Prism's panel open, nothing dims the screen behind it  [63.0% light before, 63.0% with the panel open]
```

- **Analyser:** the same 4 old notes. Kotlin compiles.
- **A near miss, now a lesson:** my first long run said the "nothing dims" check was wrong (63.0% → 49.3%).
  The preview had run an old build: the copy with the shade put back, from proving the check could fail.
  Built again from the final code, it passes. `LESSONS.md` now says to build the preview right before
  every run a report quotes.

**Build 186:**
- `Prism build 186`, `0.147.0+214`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- Its `classes.dex` has `wasTucked`, `panelSolidDial`, `panelBarTop` and `setSystemGestureExclusionRects`.
  Its `libapp.so` has "Prism build 186", "The Sidekick's panel, fixed up", the "nothing dims" check and the
  untuck note.
- sha256 `074318772efb9570575af12cfb85fcd23212e3c06df4488cc498e3b08d8380a3`, 18,797,002 bytes (by chance
  the same size as 185: its biggest parts are stored unpacked, in whole blocks; the contents differ).
- Link (checked: answers 200, same sha256): https://github.com/vikac995/vikac/raw/23eb1bbabede0a743500a0eb8e63d8c8a6319300/lumen/releases/prism-build-186.apk

## Where I could be wrong

1. **None of the panel's changes has run where it matters.** The panel is Android's; the first phone run
   proves or disproves each point.
2. **0.6 s may be too short or too long.**
   - Too short: a slow thumb between strokes still sees a flash.
   - Too long: after the last stroke, the panel stays see-through, and the Sidekick away, a little longer
     than expected.
   - It's one constant (`SETTLE_MS`), easy to tune.
3. **The back gesture may not have been the cause at all;** the short strokes explain the video on their
   own. Excluding the dials costs nothing, as they're only 72 points tall together (Android allows 200
   per edge). But on a phone with three-button navigation, it does nothing.
4. **Prism's bar top is Prism's own estimate** (the button's middle less 0.62 of its size, the figure its
   panels already use). If the bar is drawn taller than that at a large text size, the panel could still
   touch it. The check measures against the same figure, so it would not catch that; a screenshot would.
5. **If the screen is very short,** the panel is never less than 200 points tall, and could then reach
   the bar.
6. **The untuck fix is only for the first tap.** The round trip over another app taps the Sidekick again
   later. If it's ever tucked there, the same cascade could happen there. It wasn't in the S25's misses,
   so I left it as asked.

## On the phone

**What to look at:**
- Turning a dial in several short strokes: no flashing between them.
- The dial held stays solid; the rest of the panel clearly faded.
- The panel's bottom above Prism's bar (in Prism) and above Android's bar (over another app).
- The two dials on the screen when the panel opens; the two switches at the end.
- No dimming when Prism's own settings open.

**In the button test's report:** the new checks above, and a NOTE if the Sidekick was tucked before the
first tap.
