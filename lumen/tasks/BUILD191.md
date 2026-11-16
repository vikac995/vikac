# Build 191: the fan and its names

From the review chat (16 November 2026, 19:23), for planning: start it after 190 is pushed; the go comes
when the owner has tried 190.

- **Mock-up:** https://claude.ai/artifact/7b5NvRHX4jVK8UVKfEQjoh. The owner chose "Away from the
  Sidekick", plus the turned fan.
- **The owner's screenshot** (20:15, S26, Prism, the Sidekick high on the right, Pearls look, labels on):
  the blobs pile up near the top-right corner (Facebook on top of Scan), and the names sit under their
  blobs, covering the next blob and the chart.

**The rule:**
1. **The fan turns away from corners,** so the blobs keep their normal spacing, never overlap, and stay
   clear of the screen edges and Prism's bar. Shrink the arc's radius only if turning alone can't fit
   them.
2. **Each name sits on the far side of its blob,** along the line from the Sidekick's middle through the
   blob: left of it on the right edge, right of it on the left edge, above it for a bottom spot later.
   - A name never covers any blob, badge or the Sidekick.
   - Max width about 1.5 blobs, ending in "…".
   - Names are pushed back inside the screen.
   - Icons and badges are always drawn above names.
3. **Checks:** on both phones, at the Sidekick high, middle and low on each side, test for any overlaps
   (blob–blob, name–blob, name–badge, name–Sidekick), and for anything off-screen or on Prism's bar.
   Print the smallest gap found.

**Added to 191** (review chat, 19:38 to 19:51; hold the push until the owner has finished with 190):
1. **The Hovering range is −48 to 15** (the owner, from trying 190): the farthest 15 ("so the menu isn't
   too small; 15 is plenty"), so the panel gets about 21 pt wider (its width rule follows GAP_MAX); the
   deepest −48 (at −60 they "accidentally kept flicking it" when trying to grab it). The default 8 stays.
   Saved values outside are clamped when read. −48 scales with size as before; state the exact
   percentage past the edge. Keep the 80-pt grab strip; check it still comes at −48. Checks: closest −48
   (print the %), farthest 15, the "Hovering 0/18/36" panel check becomes 0/8/15.
2. **Full transparency while a dial is held:** the rest of the panel at opacity 0 (REST_SEE 1.0); only the
   solid "Where it rests" block stays. Same timing (quick spring, 100 ms settle). Checks: the rest ≈ 0
   (pixel ~0), the drag and stroke checks ≤ 0.06. Nothing else of the panel (its edge or hairline) may
   linger.
3. **189 on the S25 (SM-S931B): 680/694.** The 14 WRONG:
   - the swap, 2 of 4 (the 188 bug, fixed in 190);
   - both dial checks, 4 of 4: the section and numbers solid, but **"the rest 0"** where about 51 was
     expected. Confirm by reading why; make sure the check samples a point that is opaque when solid
     (otherwise a full-transparency check passes vacuously);
   - the grab strip at −60, 4 of 4: **"beside it false"** (56 wide, at the edge, 24 points of the
     Sidekick showing). Confirm whether 190's placement fixes it, or fix it (a stale y after a move, or
     the 39-pt window-vs-screen offset in every report).
4. **Navigation mode:** the S25 uses 3-button navigation, the S26 presumably gestures. Every report prints
   the navigation mode in its header (3-button / 2-button / gestures), next to the screen line. Checks that
   depend on gestures (the exclusion strip) say "not applicable: 3-button navigation" rather than pass or
   fail vacuously. Keep using the real insets, nothing hard-coded.

Reply "all in" (or what's missing) before the go.

**GO for 191** (review chat, 19:54 and 20:05): the owner's S25 is free to try it while the S26 runs the 190
button test. Merge, build, push, and send the link.
