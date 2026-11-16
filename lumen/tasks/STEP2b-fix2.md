# Step 2b fix 2 (build 181): the test's two misses, and no blink when the panel opens

Brief from the review chat (16 November 2026), saved as given. Exactly these, nothing else.

1. **Test baseline:** call `s = await where()` just before forwardsWas/wasTucked/closedWas/openedWas are
   read.
2. **Bring back:** call ensureVisible before the tap, and check the tap point is on screen. If it isn't,
   report "WRONG: off screen" with the coordinates instead of tapping blind. Also look for any other
   Robot tap in part 5 that could land off screen, and guard it the same way.
3. **The blink, option (a):** no raise at all. The Dot window stays under the panel. PanelView draws the
   stand-in using the Dot's own draw(canvas) only while it's covered (growing, shrinking, overlap). A touch
   in the hole counts as "a tap on the Sidekick". Add the layout-params hook so a move without a redraw
   still updates the stand-in.
   - Recorder lines: "stand-in drawn / stopped".
   - Remove raiseWhenUp, raisedFor/raisedAt and the 400 ms guard, if nothing else uses them.
   - Test: after the hold, the Dot window was never removed (count addView/removeView on it: 0 extra), and
     lensAbove is replaced by "the Sidekick visible at its spot". If you can, sample the panel's pixels at
     the Dot's centre during the grow animation to confirm the stand-in is drawn.

**Where it may differ:** if the Dot uses layers or RenderNode effects, say so in the report and describe
what the stand-in can't copy.

The redesign of the panel (bottom half, drawer-panel style, Frosted) waits for the mock-up and the
owner's approval. Don't touch its place, size or look in 181. The owner's board:
https://claude.ai/artifact/76vnqrqZFnPvzPx7o7dXMx (kept by the review chat).

On DESIGN §7: the owner restated the rule ("tuning the dial should make the settings panel turn
semi-transparent so your eyes notice the change"). Treat that as the newer rule; the wording is being
confirmed with the owner before it goes into DESIGN.md.
