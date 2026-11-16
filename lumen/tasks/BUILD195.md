# Build 195: hold to dismiss

From the review chat (16 November 2026, 21:45, and 21:59 on the numbering): the owner's own request.
Small. The app list moves to 196, search to 197. "Build and push when ready."

**"Dismiss" becomes hold-to-dismiss**, modelled on the owner's own prototype exhibit "I-05 Hold to
confirm" (their spec, tuned numbers):
- **Press and hold the Dismiss pill:** a fill sweeps across the pill from left to right over **1.2 s**.
  - Haptic ticks at 25%, 50% and 75% (light), and a heavy one at 100%.
  - The pill shakes slightly, growing with progress: offset sin(t/14 ms) × p² × 2.2 px, and a scale of
    1 − 0.035·p.
- **Let go or slide off before 100%:** the fill drains back on a spring (k 90, c 19) and nothing
  happens. The label reads "Hold to dismiss" at rest and "Keep holding…" while pressed.
- **At 100%:** a small pop (scale 0.88 → 1 on a spring, k 420, c 10), the label "Dismissed", then the
  panel closes and the Sidekick is sent away exactly as in 194 (back when the next app is opened from
  Prism).
- **A plain tap** on the pill does nothing except start the fill and drain it back. Maybe show the label
  "Hold to dismiss" for a moment.
- **Haptics:** no more than one per 28 ms.
- **Place:** unchanged, next to the title. Its touch stays ≥ 48 pt and clear of the ✕.

**Checks**
- a 0.6 s press-and-release leaves it shown, with the fill drained to 0 within 0.5 s;
- a 1.3 s hold dismisses it, and the panel closes;
- a press that slides off the pill at 0.8 s doesn't dismiss.

"Build and push when ready. Keep the 196 app-list work on its branch."

**The labels' place (the review chat, 22:02, after I said they don't fit beside the title):** "Go with
**(c)**. The owner explicitly chose the pill beside the title, and (a) would cost 44 pt that the S25 dials
don't have. The pill keeps the word "Dismiss" at 194's size, and the fill sweeps across it. "Hold to
dismiss" / "Keep holding…" / "Dismissed" appear in a small dark bubble just under the pill: while pressed,
and for about 1.2 s after a short tap. The bubble must stay inside the panel and never cover the ✕. Large
text falls back to its own line as before."
