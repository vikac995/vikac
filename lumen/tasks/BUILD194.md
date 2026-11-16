# Build 194: Dismiss beside the title, safe zones, and the blobs back sooner

From the review chat (16 November 2026, 20:56 and 21:02). 193 was already pushed when these came, so they
are 194, and the app list becomes 195.

1. **The "Dismiss" pill right after the "Sidekick" title**, on the left of the header row: [Sidekick]
   [Dismiss] … [✕]. Not next to the ✕; the ✕ stays on the right. At least 12 pt between the title and
   the pill. The pill's touch target at least 48 pt, and not reaching the ✕'s.
2. **Safe zones** (owner feedback on 192, video 22:00, S26, gesture navigation, Hovering about −48, the
   Sidekick on the left and right, dragged with its blobs out: "the touch safe zones need to be better").
   In the video Android's Back arrow appears at the right edge several times as the owner grabs the
   Sidekick there, with the blobs out and while dragging.
   - The review chat's guess: with the blobs out the strip is gone, and the full-screen menu window
     doesn't exclude the Sidekick's spot, so a grab at the edge goes to Back.
   - Fix: whenever the Sidekick rests at or past an edge, its spot (glass + the strip's margins) is in
     `systemGestureExclusionRects` at all times: also while the blobs are out (the menu window asks for
     the same rect) and during a drag (the rect follows the finger, at most every 50 ms). Within 200 dp
     per edge. Also check the Sidekick window's own exclusion at Hovering 0 to 15.
   - Check: with the blobs out, and with the Sidekick at −48 on each side, the exclusion covers its glass
     and at least 24 pt above and below.
3. **Sooner** ("the animation should trigger a bit sooner"): the blobs reopen only once the Sidekick has
   settled, a visible pause. New: at let-go, as soon as the resting spot is decided (`throwIt`'s
   target), start reopening the fan at that target, growing from the Sidekick while it glides, done
   about when it arrives. A short glide (< 120 ms): open at once. The same exceptions (sent away, tucked:
   no reopen).

**GO** (review chat, 21:09): Dismiss right after the title, the safe zones, and the sooner reopen in 194;
the app list is 195. Build when ready and send the link.
