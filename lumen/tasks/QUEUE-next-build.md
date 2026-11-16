# Queued for the next build (183), after the phone results

From the review chat, 16 November 2026. Don't build before the owner's phone results for 182 and the
review chat's go (see LESSONS.md: no new build while the owner is testing).

1. **The button test waits for the Sidekick's pictures before tapping.**
   - In part 4, after the test's menu is set (`op: 'sidekick'`), wait until `sidekickPicturesFor` reads
     "5 of 5" (up to a few seconds), then tap.
   - Log how long it took.
   - If they never come, the tap check is WRONG with that reason, not a silent miss. (182 analysis:
     `reviews/step2b-fix3-report.md`.)
2. **The triangle's turn: the final spec,** approved by the owner (from the review chat, 16 November
   2026, 09:29). It replaces the earlier 0 / +60 / +120 plan. Background: `reviews/investigate-sign-spin.md`
   and `tasks/INVESTIGATE-sign-spin.md`.
   - **One source:**
     - `tapOutcome()` returns what a tap on Prism's button would do now.
     - `_buttonUp` acts on it, the settings panel's close-tap uses it, and `_signSync` reads it.
     - `nextTapClosesAll` = the outcome leaves nothing open.
     - Holds stay outside it.
   - **The rule (Window only):**
     - Pointing down if `nextTapClosesAll`, otherwise up. Rest is up: base +60°, since Window is drawn
       pointing down at angle 0.
     - On every change of outcome:
       - the orientation differs → +60°;
       - same orientation, but the outcome changed → +120° (the owner's choice). This is one named
         constant or setting, `sameMeaningTurn` = 120 | 0, so it can be changed later in one place.
     - The angle only increases and is never re-based. One critically or over-damped spring.
   - **Cases:**
     - the drawer chosen for a blob: up;
     - the drawer chosen for the Sidekick: down;
     - parked glass: down;
     - a workout sheet: ignored;
     - during a flick: wait for the outcome. (The flick's first move, `_buttonMove` → `_setOpen(false)`,
       must not move the sign.)
   - **Petals stops turning,** and does the shoot-out like the other looks (Pearls, Lotus, Beam, Halo).
   - **Tests:**
     1. At every state the test visits, the orientation matches what the next real tap actually does:
        tap, then check what's open.
     2. The angle every frame: no reversal (more than 0.5° against the way to the target) and no
        overshoot (more than 1° past it). The path is written into the check.
     3. No single turn over 120° (Window).
     4. A real `Robot.drag` flick from open blobs.
     5. Phone only, a note: the largest step per frame. SKIPPED in the preview, whose frames are too slow.
   - **The 183 report** includes the cause write-up from `reviews/investigate-sign-spin.md`.
3. Whatever the 182 phone results ask for. The review chat adds it here.

**Later, for step 3's brief (the Sidekick's own app chooser),** not for 183: after a Change or Add, the new
blob shows only once Prism has sent its picture. Only a menu where every blob is new has nothing to open
meanwhile, which a person can't make in one step. Worth deciding in step 3 whether a blob without its
picture yet shows a placeholder.
