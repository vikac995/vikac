# Planned after 186 (planning only: don't start)

From the review chat, 16 November 2026, 16:04: the owner's new plan.

## 187: dismiss the Sidekick at the top

- **The cross moves to the top centre,** below the status bar (`crossX`/`crossY`).
- **A fling upwards dismisses it,** the mirror of the `atCross` test (`throwIt` in `MainActivity.kt`).
- **Inside Prism:** the same top cross replaces dropping onto Prism's button. Remove the fuse path for the
  Sidekick.
- **The cross shows as soon as the Sidekick is picked up,** not only when it's carried low: faint at
  first, clearer as it nears. People don't expect dismissal at the top, so it has to announce itself
  early.
- **The workout timer lens:** left exactly as it is. Its cross, Pause and Count up stay at the bottom; it
  gets reworked later.
- **To check:**
  - dragging towards the top never opens the notification shade;
  - the cross clears the status bar and the camera cutout, on both phones.

## After 187: three resting spots along the bottom (mock-up first)

- **Outside Prism only,** the Sidekick gets three new resting spots along the bottom, at 25%, 50% and
  75% of the width. The corners are its existing side spots.
- **From there,** its blobs fan upwards and its panel opens above it.
- **In Prism** it stays on the sides.
- **The spots** are kept as one short list, so they're easy to change.

**The size (asked by the review chat; an estimate from the code):** about 1½ to 2 builds, mostly
Android. Most of the Sidekick's code assumes it rests at a side. See the review chat's reply of 16
November.
