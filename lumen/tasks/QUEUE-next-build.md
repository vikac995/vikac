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
   - **The flick fix:** a flick from open blobs must not target 0 first.
     - `_setOpen(false)` at the flick's first move (`_buttonMove`) must not move the sign while a
       drawer flick may be under way.
     - The sign waits for the gesture's outcome: the drawer, the remaining +60°; anything else, back
       as usual. (One way: defer the sign's update until the gesture is decided.)
   - **Test** (from `reviews/investigate-sign-spin.md`, "How the test could catch it"):
     1. **The angle every frame:** during the open and the close of each (blobs, drawer, drawer from
        blobs, settings), record (frame time, angle, target) on every tick. WRONG on any step more
        than 0.5° against the way to the target, or any value more than 1° past it. Write the path
        into the check.
     2. **A real flick from open blobs:** the drawer flicked open with a real finger path
        (`Robot.drag`), not `_setDrawer`, checked as in 1.
     3. **No turn over 120°:** for a look that repeats every 120°, WRONG if a single turn's span is
        over 120° (it would show its end look on the way). Start and target are enough, so this runs
        in the preview too.
     4. **A note only, phone only** (SKIPPED in the preview, whose frames are too slow): the largest
        turn in one frame.
   - **The 183 report** includes the cause, from `reviews/investigate-sign-spin.md`.
   - **Settled with the review chat (09:19):**
     - the sign waits for the flick's outcome;
     - +120° ends pointing down, as at rest: the owner's mock-up showed it and the owner approved it.
3. Whatever the 182 phone results ask for. The review chat adds it here.

**Later, for step 3's brief (the Sidekick's own app chooser),** not for 183: after a Change or Add, the new
blob shows only once Prism has sent its picture. Only a menu where every blob is new has nothing to open
meanwhile, which a person can't make in one step. Worth deciding in step 3 whether a blob without its
picture yet shows a placeholder.
