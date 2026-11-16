# Build 185: the Sidekick's panel, simplified

The go, from the review chat (16 November 2026, 15:07). The owner approved "New" from the mock-up:
https://claude.ai/artifact/SQYPHqVTK9WL2wjRXjnL1M (switch Today / New, drag the Hovering dial, try Slow
motion).

**185's one behaviour change: the Sidekick's panel, simplified**
1. **Remove the shade completely** (the 40% layer with the hole). Nothing is drawn around the Sidekick or
   the panel.
2. **Panel width and place.**
   - The panel's near edge always ends before the Sidekick's furthest Hovering spot (`GAP_MAX`, about
     36 pt, unchanged), with a small gap (about 8 pt). That's about 275 pt wide on a 411 pt screen.
     Compute it from the screen width, not a fixed number.
   - The panel sits at the Sidekick's height, clamped to the screen, as today.
   - While a dial changes Hovering, the panel stays put: the Sidekick can never reach it.
3. **While the panel is open, the Sidekick can be dragged by hand.**
   - Hand touches within the Sidekick's area to the Sidekick, as the grip does.
   - A vertical drag moves the panel along to the Sidekick's new height.
   - A tap on the Sidekick still closes the panel, as today (the owner confirmed keeping that for now).
4. **While a finger is on a dial:** the panel's body and contents go to 50% opacity, on the `clear`
   spring (effects, 1600, ζ 1). They come back on release. Nothing else changes.
5. **Opening and closing:** the panel grows out of and shrinks into the Sidekick, about 0.2 s, no
   overshoot.
   - The Sidekick must be visible every frame, including the moment the panel passes its edge.
   - Use whatever does that most simply: the stand-in, or fading or clipping the panel before it reaches
     the Sidekick's middle.
   - Keep the records inside `onDraw` (ran, count, rr, lens position, sr, covers, needed), so the phone
     proves it.
6. **The lens "always full quality" one-liner,** as agreed: batched polish, not a behaviour change for the
   owner.

**Tests**
- Retire or reword the two stand-in checks to match the rule.
- **New checks:**
  - no shade;
  - with the panel open, at Hovering 0, 18 and 36, the panel never overlaps the Sidekick's glass;
  - panel opacity is about 0.5 while a dial is held, 1.0 after;
  - during open and close, the pixel at the Sidekick's middle is the Sidekick's, every sampled frame;
  - dragging the Sidekick with the panel open moves it, and the panel follows vertically.
- Test area: badge 185, `askedTest 'button'`.

**186 (for planning, don't start):** the Hovering range.
- Closest = 75% of the Sidekick past the edge (the owner's update; it was 55%).
- Furthest stays about half its width (36 pt).
- Tucked in's minimum shows 10–15% more than today.
- The grab area adapts per setting, with a back-gesture exclusion strip that moves with the Sidekick
  (≤ 200 dp).
- It starts with a short measurement of grab-area sizes before choosing.
