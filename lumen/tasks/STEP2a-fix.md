# Step 2a fix (build 177): two regressions in the button test's Sidekick half

Brief from the review chat, saved as it was given (15 November 2026).

**Good:**
- The settings move worked. Read from prism_floating, prism_side_spots and prism_blob_names in files;
  your systemTemp path was right.
- All 11 "sidekick settings" checks pass 4/4, and the palette reached Android (17 colours).
- Native now grows only about 9 MB a round (119 → 145), down from about 60. The test's own frames
  still grow (0 → 7632), so check that the bound holds.

**Keyboard probe, decided: A.**
- B kept the keyboard up while the focusable window existed (Prism lost the window focus, the field
  kept it, the IME stayed connected).
- But the keyboard went down about 300 ms after B's window went away ("down at 2300–2400 ms"), in all
  4 rounds. So B closes the other app's keyboard on close.
- The owner chose "measure, then decide", with the keyboard winning if it doesn't survive. So it's
  **A: the panel never takes focus; Back goes to the app.** It closes with ✕, the shade, the Sidekick,
  or Home/Recents. Record that in STEP2-plan.md and PRISM.md's Back table.

**New in 176: 68 wrong, all in the Sidekick half, all 4 rounds.** This is a regression; 173 and 175
passed these.
```
WRONG sidekick: holding a blob brings its small menu (4/4) [small menu 0]          ← 175: [small menu 1]
WRONG sidekick: pressed on Remove and let go on Change ... (4/4) [small menu 0, its menu action:4 action:3 action:2 action:1 screen:0]
WRONG sidekick: Remove takes that blob out ... (4/4) [its menu action:3 action:2 action:1 screen:0 empty: (was action:4 action:3 ...)]  ← blob 0 removed instead of 1
WRONG sidekick: Prism has been told its keys again (4/4) [Prism was told action:3 action:2 action:1 screen:0 empty:]  (follows from the above)
WRONG sidekick: closed without choosing ... (4/4) [its menu action:3 ...]
WRONG sidekick: Change brings Prism's list ... (4/4) [list true, place 200, asked for 0 action:3, button as the blob 1.0]
WRONG sidekick: settings closed, it is back in sight, out at its place (4/4) [shown false, hidden true, tucked false]
WRONG clean: after the Sidekick's settings (4/4) [panel true/true, ...]   ← the settings panel was left open
then "there is no lens" for: tapped (4 of 40), moved then held, let go low, cancelled carry, carried to the bottom; and "clean: after the Sidekick" [panel true/true]
ok: held, its settings come up; under its own settings it is hidden; the slider checks; tucked 8/40; all 11 settings checks; the keyboard probes; "under Prism's own settings it is hidden"
```
Two separate faults, I think, but find them, don't assume:
1. **A hold on Sidekick blob 1 opens blob 0's menu.** Is it the test's coordinates, or a real index
   shift on Android? Something new in 176 may have changed the fan or the item order: the Icons split,
   the side pictures, the settings checks running earlier in part 5, or "its own look back" restoring
   the look as "" (the report shows "Android , was (the first)").
2. **After the new settings checks, Prism's settings panel stays open** (panel true/true). The Sidekick
   stays hidden under it, and everything after has "no lens". Find which new step leaves the panel
   open. Make the test close it and verify. And make sure a real panel can't keep the Sidekick hidden
   after close.

**Task: build 177 = these fixes only. No panel UI yet.**
- The owner hasn't approved 2b's mock-up yet: it now has two dials at the bottom instead of sliders.
- Also check the frame list bound.
- Note for step 4, still live: in the owner's own use, dragging the Sidekick onto Prism's button still
  "fuses".

Same workflow, with "Where I could be wrong". Report back to me when done.
