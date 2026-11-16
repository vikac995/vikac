# Build 193: dismiss only from its menu

From the review chat (16 November 2026, 20:52), a big owner decision: it replaces the app list, which
moves to 194. Prepare it, build and push straight away. The owner just threw the Sidekick at the top
cross by accident.

1. **Remove dragging or flinging the Sidekick to dismiss it, entirely.** No top cross for the Sidekick,
   no fling-to-dismiss, no pull toward a target. A carry anywhere just moves it: sides, tuck, and (later)
   bottom spots as usual. The workout timer's lens keeps its own bottom cross / Pause / Count up; it gets
   reworked later.
2. **Dismiss only from its panel:** hold the Sidekick and its settings panel opens, as today. The panel
   gets a clear **"Dismiss"** button.
   - Where: in the header row, left of the ✕ (a pill reading "Dismiss", the same style as the panel's
     other buttons). It must not be confusable with ✕ (close the panel).
   - Tap it: the panel closes and the Sidekick goes away the same way as today's dismiss: it stays away
     until the next app is opened from Prism, with the same `sideGone` rules. The existing swallow/close
     animation, shrinking into its spot (no cross).
3. **Remove the dismiss-related checks** (the top cross's place, faint at once, carried to the top, flung
   up, the cancelled carry to the top, the shade). Keep "carried to the top, the notification shade never
   comes down" as a drag check: carried there, it is NOT dismissed and the shade stays up. Add: a carry
   onto the old top-middle spot and a fast fling up both just move it; it's still shown. Add: hold →
   panel → "Dismiss" → it's gone; then it comes back when the next app is opened from Prism (or the
   test's own bring-back).
4. Remove the dead code (the top cross for the Sidekick) rather than leaving it switched off. The timer
   still needs its own.

Send the link when it's done.
