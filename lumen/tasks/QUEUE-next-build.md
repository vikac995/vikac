# Queued for the next build (183), after the phone results

From the review chat, 16 November 2026. Don't build before the owner's phone results for 182 and the
review chat's go (see LESSONS.md: no new build while the owner is testing).

1. **The button test waits for the Sidekick's pictures before tapping.**
   - In part 4, after the test's menu is set (`op: 'sidekick'`), wait until `sidekickPicturesFor` reads
     "5 of 5" (up to a few seconds), then tap.
   - Log how long it took.
   - If they never come, the tap check is WRONG with that reason, not a silent miss. (182 analysis:
     `reviews/step2b-fix3-report.md`.)
2. **The rainbow triangle's turn** (the owner approved the behaviour; from the review chat, 16 November
   2026):
   - **Behaviour:**
     - at rest: 0, pointing down;
     - blobs open: +60°;
     - app drawer: +120°, a little slower;
     - drawer opened from open blobs: the remaining +60°;
     - Prism's settings (hold): the same as the drawer, +120°;
     - always clockwise: one smooth spring, critically damped or overdamped, with no overshoot and no
       reversal; closing goes back the same way.
   - **Test:**
     - record the angle every frame during the open and the close of each;
     - fail on any overshoot past the target, or any change of direction;
     - include the drawer flicked open from open blobs with a real finger path (`Robot.drag`), not
       `_setDrawer`: today that's the one path that really reverses.
   - **The 183 report** includes the cause, from `reviews/investigate-sign-spin.md`.
   - **Two points from the investigation, sent after this approval was written; the review chat
     confirms them before the build:**
     - **The flick's first move** (`_buttonMove` → `_setOpen(false)`) sends the sign back towards 0
       before `_setDrawer(true)`. "The remaining +60°" needs the sign to wait for the flick's outcome,
       or not to go back at the first move.
     - **+120° ends looking exactly like rest,** because the Window triangle repeats every 120°: with
       the drawer open it points down, as at rest. Pass on to the owner if not already seen in the
       mock-up.
3. Whatever the 182 phone results ask for. The review chat adds it here.

**Later, for step 3's brief (the Sidekick's own app chooser),** not for 183: after a Change or Add, the new
blob shows only once Prism has sent its picture. Only a menu where every blob is new has nothing to open
meanwhile, which a person can't make in one step. Worth deciding in step 3 whether a blob without its
picture yet shows a placeholder.
