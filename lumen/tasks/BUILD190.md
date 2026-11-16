# Build 190: the swap tap fixed, and dismiss the Sidekick at the top

From the review chat (16 November 2026, 19:04). Hold 190 until the owner has tried 189 by hand.

1. **First item: the 188 swap tap on the S26.** 188 on the S26 (SM-S942B): 679/682. The only WRONG, 3 of
   4 times: "one menu at a time: with the Sidekick's blobs out, one tap on Prism's button closes them and
   opens Prism's" [the Sidekick's blobs in, Prism's in; the triangle points up; Prism was given 0 tap(s);
   its last touch: down at 970,2094; lens at 860,1984 size 220, mode 2; a tap; Prism in front true,
   thinks nothing is in front; so it opens the menu]. The Sidekick's menu closed, but the tap wasn't
   handed to Prism. The opposite direction, the hold and Prism's side all pass. The dials fit with
   73.9 pt to spare on the S26. Find the cause by reading; fix it as the first item of 190, not as a
   separate build.
2. **Dismiss the Sidekick at the top:** as planned in `QUEUE-after-186.md` ("190: dismiss the Sidekick at
   the top").

**Added to 190, ahead of the top dismiss** (review chat, 19:14 and 19:21): the owner tried 189 by hand (S26,
over the Claude app, screenshots 20:13–20:14). Hovering 36: fine. Hovering −60: only a thin sliver shows
at the right edge; "It's a bit hard to hit it like that", and "I accidentally did the back gesture a few
times". They want more tolerance.
1. **A bigger grab strip** when the Sidekick is past the edge: 80 pt wide from the edge (was 56), matching
   the tucked grip's ~76; as tall as the Sidekick + 48 pt (24 above, 24 below; was +16); the same
   `systemGestureExclusionRects`, within Android's 200 dp per-edge limit. Say what the limit allows at
   the S26's height.
2. **Diagnostics:** log to the recorder every time a touch that started inside the strip gets
   ACTION_CANCEL ("taken by Android, probably Back"), with its y and the strip's rect.
3. **Check:** at −60, the strip is ≥ 80 pt wide and ≥ the Sidekick + 48 tall, and it's in the exclusion
   rects. If Android's exclusion is being capped or ignored at that height, print it.

Then the swap fix and the top dismiss as planned. **GO: build 190 when ready**, push, send the link. No
mock-up needed for the top cross (the existing ring moved; the owner approved the behaviour in words).
