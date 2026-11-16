# Queued for the next build (183), after the phone results

From the review chat, 16 November 2026. Don't build before the owner's phone results for 182 and the
review chat's go (see LESSONS.md: no new build while the owner is testing).

1. **The button test waits for the Sidekick's pictures before tapping.**
   - In part 4, after the test's menu is set (`op: 'sidekick'`), wait until `sidekickPicturesFor` reads
     "5 of 5" (up to a few seconds), then tap.
   - Log how long it took.
   - If they never come, the tap check is WRONG with that reason, not a silent miss. (182 analysis:
     `reviews/step2b-fix3-report.md`.)
2. Whatever the 182 phone results ask for. The review chat adds it here.

**Later, for step 3's brief (the Sidekick's own app chooser),** not for 183: after a Change or Add, the new
blob shows only once Prism has sent its picture. Only a menu where every blob is new has nothing to open
meanwhile, which a person can't make in one step. Worth deciding in step 3 whether a blob without its
picture yet shows a placeholder.
