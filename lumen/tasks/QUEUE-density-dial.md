# Queued: the app list's Density as a dial

From the owner, sent by the review chat, saved as given (16 November 2026). Design approved pending the
owner's final look. Build nothing until build 178's phone run is back. Goes with (after, or with)
`QUEUE-density-overlap.md`: the grid's single-copy motion is fix 1's.

**Mock-up:** https://claude.ai/artifact/CR5oUdbxuz9RvhwGsoFrV9 (version 2).

- Replace the app list settings' Density StopSlider with a DragDial-style ruler pill (value "4 per row"
  etc., one step per density).
- **Placement:** the settings panel is laid out so that its bottom edge is the app list's bottom edge, and
  the dial is the panel's last element. So when everything else clears, the dial is already sitting on the
  list's bottom edge, like a footer, with no jump.
- **While held:** from the first touch until the finger lifts, the shade, the panel background and every
  other control are cleared, and only the dial pill stays, on a near-opaque surface. No flicker between
  steps; this follows the owner's rule in DESIGN §7.
- The grid re-lays out live per step, with fix 1's single-copy motion.

(The idea first noted in HANDOVER's roadmap, item 3: "the app list's Density control as a dial".)

**Status (16 November 2026):** pending. The owner has not yet seen the density mock-up (version 2); its motion and the dial wait for the review chat to confirm the owner's OK. Order: after build 179 (large text), the overlap fix, then the dial; all after build 178's phone run.
