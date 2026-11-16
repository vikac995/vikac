# Build 192: drag the Sidekick with its blobs out

From the review chat (16 November 2026, 20:18). The owner tried 191 by hand: "we're good". This is 192,
ahead of the app list (which moves to 193).

**Request: drag the Sidekick while its blobs are open.** Today (screenshot 21:17, S26, Pearls, the
Sidekick high on the right, its blobs fanned out over the Claude app) it can't be dragged in that state.

**Wanted:**
1. With the blobs out, a drag that starts on the Sidekick's glass (+6 pt, the same as the panel's
   `touchLens`): once past the touch slop, the blobs fold back in quickly (the normal close, about
   0.15 s), and the Sidekick follows the finger 1:1, exactly as a normal drag.
2. On let-go it settles as a normal drag would (sides, tuck, the top-cross dismiss all as usual). Once
   it has come to rest, the blobs open again at the new spot (the 191 fan and names). Dropped on the top
   cross: dismissed, no reopen. Ended tucked: no reopen (a tucked Sidekick has no fan; say if I think
   otherwise).
3. A plain tap on the Sidekick with the blobs out still closes them, as today.
4. The triangle follows the one-menu rule throughout.

**Checks:** with the blobs out, a 120-pt drag of the Sidekick toward the screen's middle: the blobs close
within 0.25 s of the drag starting, the Sidekick moves 1:1, and after rest the blobs are out again round
the new spot with 0 overlaps (the 191 gap check). A drop on the top cross: dismissed, the blobs not
reopened. A tap: the blobs close, and no reopen.

Also include the prep-192 test fix (the drag toward the middle); say how big it is. If small, build and
push straight away, and send the link.

## Carried items

**From the 190 S26 run** (review chat, 20:12; SM-S942B, gestures, the owner's Hovering −49): 705/710. All
the new 190 checks pass (the swap 4/4 with menuTap "on Prism's button: handed to Prism"; the top cross at
206,96, its top 49.8 against the status bar and camera's 43.8; faint at once 0.30; dismissed by carry and
by fling; the shade never came down). WRONG:
1. The strip check, 4/4, "beside it false" (80 × 131.8, all of it excluded, 132 of 200, no strip touches
   taken by Android): the check's bug, fixed in 191.
2. "dragged by hand with the panel open…", 1 of 4: the Sidekick moved −60 of the −120 drag (the panel 0,
   fills true), at Hovering −34, past the edge with the 80-pt strip up. Look by reading; if real (a drag
   that starts on the strip loses half its travel), fix it in the next build.
   - **By reading (prepared on prep-192, test only):** the test's drag is injected into the panel and
     handed to the Sidekick, so the strip isn't involved; the drag follows the finger one to one (pressAt
     and follow use raw positions, the strip forwards raw positions too). Let go, the Sidekick comes to
     rest no nearer than 48 points to the top (`throwIt`), so dragged 120 up from about 108 points from
     the top it comes to rest only about 60 up. The test always dragged up: now it drags toward the middle
     of the screen, expects what the 48-point limit allows, and prints where it started.

FYI: memory on the S26 about 1.0 GB in all (graphics about 550 MB, process about 350 MB): Milestone 2
material, no action now.
