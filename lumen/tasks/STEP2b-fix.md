# Step 2b fix (build 179): the Sidekick's panel closes by itself after the opening hold

Briefs from the review chat (16 November 2026), saved as given (condensed to the parts that ask for
something). Urgent: before the large-text build.

**What was seen (two screen recordings on the owner's phone, build 178):** hold the Sidekick, the panel
grows fully open, it stays about 0.6–1.0 s after the finger lifts, then it closes by itself back into the
Sidekick. Over Prism's Home, and over the Claude app with the keyboard up (the keyboard stayed up
throughout, as it should).

**To narrow it** (verify each with the recorder; don't assume):
1. The CLOSE_SYSTEM_DIALOGS receiver (SidekickPanel.listen) closes on any such broadcast, whatever the
   reason. Samsung and the system send it with many reasons ("homekey", "recentapps", "assist",
   "globalactions", "lock", "dream", "voiceinteraction" and others), and some fire on window changes.
   Only "homekey" and "recentapps" (plus SCREEN_OFF) should close the panel. Log the `reason` extra in
   the close line.
2. The raise, removeViewImmediate + addView of the Dot after the opening hold's UP: check whether the
   removal or re-add triggers any hide, covered or "taken off the screen" path, or a front/outside event
   that leads to a close.
3. The postDelayed "Sidekick switched off here" (`!RestBubble.lensShownNow()` 350 ms later): if
   lensShownNow() is briefly false during the raise, this closes the panel. It's only meant for switch
   changes, but check it can't run on open.

If the recorder export doesn't come soon, fix all three defensively: the receiver filtered by reason, the
raise flagged so nothing reads it as hide or close, the switch-check only after a switch tap.

**Test check:** a real hold opens the panel, and it is still open 1.5 s after the lift, with no close
event, and the Sidekick window raised without the panel's visible state changing.

Same workflow; report as soon as the APK is up.
