# Build 196: the Dismiss pill under the Sidekick

From the review chat (17 November 2026, 07:17): "GO: 196 = the Dismiss pill moves under the Sidekick.
It's its own small build, ahead of the list." New numbering: 197 the app list (the held branch,
renumbered, rebased on 196), 198 the test store fix (F02 + F34), 199 search. "Build and push, and send
the link."

**196 spec:**
1. **The header:** goes back to just "Sidekick" … ✕. No Dismiss there, and no bubble.
2. **The pill:** while the panel is open, it's drawn by the panel's window just **below the Sidekick's
   glass**: centred on the Sidekick's x, 10 pt gap under the glass. It reads **"Hold to dismiss"** and
   has room for the full words, so there's no bubble.
   - If there isn't room below (bar, nav or screen bottom), it goes **above** the glass.
   - **Clamped on screen** with a 12 pt margin, so at Hovering −48 it slides inward to stay fully
     visible.
   - **Follows** the Sidekick when it's dragged with the panel open.
   - Shows and hides with the panel's open/close motion.
3. **Behaviour:** exactly 195's hold-to-dismiss: 1.2 s fill, light ticks at 25/50/75%, heavy at 100%,
   the shake, a drain on early release or slide-off. The pill's own label changes to "Keep holding…"
   while held and "Dismissed" at 100%, then the panel closes and the Sidekick is sent away as now.
4. **Touch:** at least 48 pt tall, never overlapping the Sidekick's glass touch area. Include it in the
   exclusion rect when it's near an edge.
5. **Checks:** reuse 195's six, at the new place. Add:
   - "the pill under (or over) the Sidekick, fully on screen" at Hovering 8 and −48, high and low;
   - "the header has no Dismiss".
