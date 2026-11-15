# Step 2b (build 178 or later): the Sidekick's own settings panel

Brief from the review chat (15 November 2026), saved as it was given, then what the approved mock-up adds.
**Build only after build 177's phone run passes: the review chat confirms.**

**Approved mock-up:** https://claude.ai/artifact/URMobjt1XEiqh2kTSFJmLv (version 5), approved by the owner.
Plan: `STEP2-plan.md` (its "owner's answers" hold, with the changes below).

## The brief, as given

- **The panel:** beside the Sidekick, on the side away from it. 330 pt wide, nearly full height, content
  scrolls. It grows from the Sidekick's circle on snappy and closes into it on spatialFast. Contents fade in
  between 5% and 30%. The shade leaves a hole at the Sidekick.
- **Order:** the title and ✕ → In Prism / Over other apps switches → Labels, Icons, Colours pickers → Look
  (3 per row) → "Where it rests": two DragDial-style ruler pills side by side, labelled **Hovering** and
  **Tucked in**.
- **Rulers:** touching one sends the Sidekick straight to that state. Sliding moves the Sidekick the same
  way as the finger on either edge, so the value runs opposite on the left edge. One tick buzz per point. A
  flick coasts, then lands on a whole point.
- **While sliding:** the panel stays fully visible, and **only the shade lifts**. The Sidekick window is
  always above the panel.
- **No flash on letting go.** The owner noticed the mock-up's panel blinks slightly on release. The real
  one must go straight back to the shaded state, with no flicker or opacity jump.
- **Closing:** ✕, the shade, the Sidekick, Home/Recents, screen off. Never focusable (decision A); Back
  goes to the app.
- **Way back:** the "Bring back the Sidekick" line in Prism's settings, shown only while both switches are
  off.
- **Prism's panel:** loses its Sidekick part and the Prism|Sidekick picker.

**DESIGN.md, the new rule:** "a panel steps aside while a control is held only when it hides what that
control changes; otherwise only the shade lifts." So the app list's Density (its grid is behind its panel)
keeps stepping aside, unchanged, and the Sidekick's panel stays. The owner saw both in a comparison mock-up.
Update §6/§7 to match.

Same workflow, with "Where I could be wrong". Report back to the review chat when done.

**The ruler to copy:** the Train page's kg/reps pills, `DragDial` (`lib/rooms/patterns/inputs_room.dart`,
used at `lib/fit/train_page.dart` 513/533): two side by side, the value on top, ticks below. Not the
weigh-in's `Ruler`.

## What the mock-up adds (read from it; size, place, order and motion only)

The mock-up says itself: "the controls, glass, haptics and springs will be Prism's own. This shows size,
place, order and motion." So every control is drawn as Prism's own (its pickers, switches, type, panel
surface and corners), and only the following is taken from the mock-up:
- **Place:** on a 412 × 915 pt screen, 330 wide, from 56 pt below the top to 98 pt above the bottom,
  8 pt in from the screen's edge on the side away from the Sidekick.
- **Grow and close:** the panel's rectangle runs from the Sidekick's own circle (its place and size) to
  the panel's place. Its corners also run from the Sidekick's round to the panel's.
- **The shade:** black at up to about 40%, with a clear round hole about 6 pt bigger than the Sidekick.
  Taps on the shade close the panel.
- **Section labels:** Labels, Icons, Colours, Look, "Where it rests, in points"; the two rulers' own labels
  above them, Hovering and Tucked in.
- **Ranges:** Hovering 0–36, Tucked in 8–40, whole points.
- **Touching a ruler:** the Sidekick goes to that state at once: hovering at that distance, or tucked in.
- **Letting go of either ruler** (the review chat's correction: the mock-up's half-second untuck was a
  shortcut): the Sidekick returns to the state it was in before the panel opened. If it was out, it goes
  back out at the new Hovering distance; if it was tucked, it goes back tucked at the new amount. The same
  when the panel closes.
- **Both switches off:** the panel closes, after about a third of a second, and the Sidekick goes. Prism's
  settings page then shows "Bring back the Sidekick" ("shown only while it's off everywhere", with a
  "Bring back" button), which switches both back on.

**Confirmed by the review chat:** the first switch is **"In Prism"** (it was "In this app"). DESIGN.md §7
changes with it.
