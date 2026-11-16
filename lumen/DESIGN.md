# Prism design rules

Every agent and every build follows these. They were settled with the owner over many builds; each
one is here because something felt wrong without it. If a change needs to break one, ask the owner
first. If something is not covered, choose what an existing element already does, and add the
answer here.

## 1. What Prism is for

- **"An app designed to keep you on track and get out of your way."** It should save time and never
  ask for attention it does not need.
- **Intuition over innovation.** People do what they are used to (tap to use, hold to change, drag to
  move, back to undo) and it works. If they guess wrong, it should at least take them to the right
  place, where they can find the rest.
- **One element, one behaviour, everywhere.** A blob, a menu, a slider or a panel behaves, moves and
  buzzes the same wherever it appears, in Prism and on the Sidekick. One piece of code decides it.
  Before adding a behaviour, check whether an element already has it, and use that.
- **Stable before new.** Something people can use all day, every day, matters more than any feature.

## 2. Battery and smoothness

- **Nothing runs when nothing happens.** No timers that poll, no animations off screen, no redraws
  at rest. Things move only while they are seen moving, and stop.
- Draw once, reuse the picture: icons, the background, a grid while it is being resized.
- Changes that cost something are done while nothing is moving, never during an animation.

## 3. Motion

**"Snappy: almost instant, but beautiful."** (The owner's rule, 16 November 2026. It applies to everything
from build 183 on.)
- **Every animation lands in about 0.2 s,** with at most a tiny settle. Never a long wobble.
- **Springs are stiff and near-critically damped.** For reference, the owner's tuned Prism Shapes mock-up:
  stiffness 1100, damping 52, mass 1 (ζ ≈ 0.78), visually done in about 0.2 s
  (https://claude.ai/artifact/ULmc5XwopWThc87pLGC7tS).
- **Where something must never go past its stop** (the triangle's turn), the spring is critically damped
  (ζ 1). ζ 0.78 goes about 2% past: on a 60° turn, a degree.

All motion uses the named springs in `lib/core/springs.dart`. No new timings: pick the spring.

| What | Spring | Feel |
|---|---|---|
| Something opening from Prism's button (app list, Prism's settings) | `Motions.snappy` | Quick, with only a hint of give. It is done all day: never slow. |
| The same closing | `Motions.spatialFast` | Quick, no bounce. Closing is as fast as opening, never slower. |
| The sign turning (triangle) | `Motions.spatial` until 183; from 183 a stiff, critically damped one (see `tasks/QUEUE-next-build.md`) | Lands in about 0.2 s. Never past its stop, never back. |
| Values settling (sliders, density) | `Motions.effects` family | No bounce at all. |

- **What opens from a button grows out of that button and goes back into it.** The app list and
  Prism's settings do exactly this, with the same code path (`_SpringPanel` for panels). Never invent
  a second way of opening the same kind of thing.
- **Nothing is ever drawn twice during a change.** When things rearrange (the app list changing
  density), each item travels to its new place, or fades where it was and comes up where it is.
  Never cross-fade two whole layouts: the double image is hard on the eyes.
- **Softer, fewer, still fast.** Less flashing, more fading, softer movement, but snappy and
  responsive. If something feels busy, remove movement before adding more.
- **No pops.** Whatever turns into something else starts and ends at the same size, place and
  shape as the thing it came from and goes back to.
- **Centred as the eye sees it.** A triangle is centred by where its corners are, whichever way it
  points (`BlobSign.triangleNudge`), not by its geometric centre.

## 4. Touch: tap, hold, drag, flick

- **Tap uses. Hold still changes. Move first is a drag. Fast upward is a flick.**
- **Hold time:** Android's own long-press time × 0.85, the same for every hold everywhere (Prism's
  `_holdMs`, Android's `Floater.holdTime()`).
- **A finger that moves before the hold time is a drag, never a hold**, however long it then stays.
  A finger that only trembles a few points is still a hold.
- **One decision, one result, one buzz.** A touch is never two things at once (for example the
  glass lifting and the app list opening). If it is undecided, wait; do not do both.
- **Nothing triggers by accident.** A hold never fires while something is still flying out, while
  a list is up, or while something is being dragged.

## 5. Haptics

The same action always gives the same buzz (`lib/core/haptics.dart`).

- **tick**: a step, a selection, a page, a tap on a small control.
- **settle / click**: a hold recognised, something opened or set in place.
- **thud**: something removed or dismissed, or an action that cannot happen.
- One buzz per action. Never two for one touch.

## 6. Prism and the Sidekick

- **Prism** is the centre button (the glass with the coloured triangle) and its blob menu.
  **The Sidekick** is the floating button that comes with you over other apps, with its own menu.
  They are **two separate things that look and behave alike**: same gestures, same menus, same
  springs, but separate data, separate settings and separate screens.
- **Each one is edited where it is.** Editing the Sidekick happens over the app it is in and never
  opens or turns Prism. Editing Prism happens in Prism. Nothing about one should feel like editing
  the other.
- **Hold the closed button**: its settings (Prism's in Prism, the Sidekick's over the current app).
  While Prism's settings are open, its triangle has turned half a turn, as for the app list, and
  turns back when they close. No cog.
- **Hold a blob**: a small menu beside it: **Change | Remove | Add**. Remove is red, Add is green and
  shown only while there is room. Keep holding and move instead: the menu goes and the blob comes
  along.
- **Hold the empty space with the blobs out**: **Edit Prism | Add Blob** (or **Edit Sidekick | Add
  Blob**). Add Blob is green. Nothing else goes in this menu.
- **Blobs always stand together in the middle.** Remove: the others close up at once. Add from a
  blob: the new one goes right after it. Add Blob: at the right end. Empty places are never shown.
  With nothing at all, one "+" blob.
- **The button never goes bare.** With an empty menu it keeps its look, in the light's own colours.
- **Change** opens the list titled "Change ..." with a red Remove in it; while it is up, the button
  becomes the blob being changed, and goes back after.
- **The Sidekick never takes the keyboard or the focus** of the app underneath.
- **Dismissing the Sidekick is quiet**: nothing shows while it is moved; a thin ring fades in only
  when it is carried into the bottom quarter, and lights up when it would be dismissed there.
- Its two places at a screen edge are two dials side by side in its own panel, **Hovering** (how far
  from the edge it rests) and **Tucked in** (how much of it shows), in whole points, like the Train
  page's kg and reps. Touching one puts the Sidekick in that state at once; sliding moves it the way
  the finger goes, on either edge; let go, it goes back to the state it was in.
- **Its own settings panel** (Android's, over the app it is in) sits beside it, on the side away from
  it, nearly full height, and grows out of it and back into it as Prism's settings do from the
  button. The Sidekick is always drawn above its panel. The panel never takes the focus: Back goes to
  the app underneath; it closes with the ✕, a tap on the shade, a tap on the Sidekick, or Home.

## 7. Panels and controls

- **No explanations in panels.** Labels only. (Tooltips come later, before testers: see the backlog
  in `PRISM.md`.)
- **Two-way choices are glass segmented pickers** (`Segmented`): Labels Show | Hide, Icons Prism |
  Regular, Layout Pages | List, Colours Mellow | Vivid. **Switches** only turn a feature on or off
  (In Prism, Over other apps).
- **Continuous values are smooth sliders** (`LumenSlider`). Stops only where the steps mean
  something (app list density: 3, 4, 5 or 6 across).
- **Seeing what you change** (the owner's words): "The rule is the best, most logical experience. When
  someone is visibly resizing or repositioning something, they must see what they are changing, in real
  time. If a panel hides it, the panel makes way while the control is held. If it's already in sight
  (like the Sidekick beside its panel), nothing extra happens: no added animation." So the app list's
  Density (its grid is behind its panel) makes the panel step aside while it is held; the Sidekick's
  dials leave its panel exactly as it is, and only the shade lifts.
- **Panels opened from the button sit above it**; the button stays in sight, and a tap on it, beside
  the panel, the X or back closes the panel, all at the same speed.
- Back undoes the most recent thing opened, one step per press (the table in `PRISM.md`). Every new
  element says where it sits in that table before it is built.

## 8. Look

- **Glass only on things that float over content**: the bar and its tab glass, Prism's button, the
  Sidekick, sheets. Cards, lists and buttons are solid.
- **Glass rims are thin light, never thick tinted bands**, and there are no hard inner circles.
- **The carried magnifying lens** (the one dragged over widgets) **always renders at full quality**:
  the full glass (blur, refraction, dispersion and rim), whatever the Glass setting or Auto's current
  level. The only exception is Android's "reduce transparency", which makes it solid. (The owner's rule,
  16 November 2026.)
- **The looks** (Pearls, Petals, Lotus, Beam, Halo, Window; Window is the default): each fills the
  glass and is balanced in it. Looks that turn keep their colours still while their shape turns
  (Window, Petals). Every look is easy to remove completely: one entry and one function in
  `lib/fit/blob_sign.dart`, and the same in `BlobLooks.kt`.
- Mellow or Vivid is a switch, not a separate look. Vivid sits on a black ground with depth.
- The tab glass never goes past the ends of the bar.
- Inspiration only, never copies: no Pink Floyd prism cover, no Polaroid logo, no other app's look.

## 9. Words

- Names: **Prism**, **Sidekick**, **blobs**, **Glass** (the magnifying glass on Prism's button).
- Actions: **Change**, **Remove** (red), **Add** / **Add Blob** (green), **Edit Prism**,
  **Edit Sidekick**. Use these words, the same everywhere.
- Plain, short, no jargon.

## 10. How work is done

- Every build: a full release APK with a commit-pinned link, a `CHANGELOG.md` entry saying what
  changed, what was checked and what was not.
- The automatic tests (the long test and the button test) are updated with every change of
  behaviour. A test is never loosened to make it pass. Every miss is explained.
- Anything that only runs on Android is said to be unchecked until the owner has tried it.
- If unsure what the owner meant, ask before building. If they say stop, stop.
