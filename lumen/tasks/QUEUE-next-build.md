# Queued for the next build (183), after the phone results

From the review chat, 16 November 2026. Don't build before the owner's phone results for 182 and the
review chat's go (see LESSONS.md: no new build while the owner is testing).

**For every item: "Snappy: almost instant, but beautiful."** (The owner's rule, DESIGN.md §3.) Every
animation lands in about 0.2 s, with at most a tiny settle and never a long wobble. Springs are stiff and
near-critically damped.

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
     - **Snappy:** it lands in about 0.2 s. It must also pass the test's 1° overshoot limit, so it is
       critically damped (ζ 1), not the mock-up's 0.78 (that goes about 2% past: 1.2° on a 60° turn).
       To within 2% of the stop:
       - `Motions.effects` (1600, ζ 1): about 150 ms, an existing named spring;
       - 1100 at ζ 1: about 175 ms, which would be a new named one;
       - today's `Motions.spatial` (700, 0.9): about 180 ms, and not critically damped.
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
3. **The Sidekick's panel goes "under the glass"** (approved by the owner; from the review chat,
   16 November 2026). Mock-up: https://claude.ai/artifact/XZo7zUA66qjXF5Cr6ik8xJ ("Under the glass").
   - **The bug (182):**
     - Closing the Sidekick's panel lets the shrinking panel land on the Sidekick. For about 0.1 s the
       Sidekick is hidden by an opaque dark rounded box (owner's video, 11:23).
     - Opening is fine (no blink).
   - **What the code shows** (read, not seen on a phone; for the 183 report):
     - **The stand-in is not skipped, and not drawn under the panel.** `PanelView.onDraw` draws it
       last, on every frame where `covers(rr)` is true, closing included. While the panel shrinks
       onto the Sidekick, its rectangle always contains the Sidekick's middle, so `covers` is true.
     - **But the Sidekick's glass is see-through.** Its body gradient is 0x78–0xD6 alpha, about
       47–84%, made to let the app show through. Over the panel, the panel's opaque dark surface shows
       through the glass instead of the app, and darkens it. Around the glass, the panel's rounded
       rectangle sticks out:
       - it ends as the Sidekick's own square, with corners of its radius;
       - at 20% open it is a fifth of the way to the full panel.
       Together, that reads as a dark box over the Sidekick.
     - **Why only closing:** the close uses `spatialFast` (1400, 0.9). From 30% down to 0.4% takes
       about 90 ms: 60 ms to reach 30%, 149 ms to reach 0.4%. That's the spring's slow tail, with the
       panel at about the Sidekick's size. Opening (`snappy`) is under 30% for only about 30 ms.
     - **To confirm from the 182 recorder:** around the close there should be "stand-in drawn" and no
       "stand-in stopped" before "its own settings gone". A "stopped" during the close would mean
       `drawLensInto` returned false (the Sidekick's window not attached, or not the Sidekick), and
       then the cause is different.
   - **Spec, "under the glass":**
     - For the whole open and close movement, the panel is drawn first and the Sidekick's stand-in
       last, on top.
     - The panel shrinks towards the Sidekick's centre (it already does).
     - As it passes under the glass, it shows faintly through it. The Dot's glass fill is see-through
       enough. If needed, the stand-in's glass is drawn at reduced opacity over the panel, inside the
       lens circle only.
     - A **barely noticeable** glow in the glass as it takes the panel in: a short, soft brightening
       of the lens, about 0.1 s, low intensity (the owner: "very subtle, barely noticeable").
       Opening reverses it.
     - The Sidekick must never disappear or be covered, not even for one frame.
     - (From the finding above: "faintly" means the dark panel must not fill the glass at full
       strength, as it does now. Inside the lens circle the panel is drawn faded, or the glass over
       it is made more opaque. The mock-up decides which reads as "faintly".)
   - **Test:**
     - During the open and the close, sample the panel's frames at several stages.
     - At the Dot's centre, the panel's pixel must match the stand-in, not the panel's colour, at
       every sampled stage, including the last 20%.
     - Any stage where the Dot is covered is WRONG.
     - (Today's `testSample` samples one stage, 12% open, as the opening. It needs the closing's
       stages too, including the last 20%. It should also check a ring just inside the glass's edge,
       where the dark box showed, not only the middle.)
   - **Decided** (review chat, 10:59, matching the mock-up):
     1. **Inside the lens circle, the panel is drawn at about 30% strength** (faint), never at full.
        Simplest way: clip the panel's drawing to "outside the lens", then draw it again clipped to
        "inside the lens" at 0.3 alpha, then the stand-in on top.
     2. **The panel shrinks to a point at the lens centre** (size → 0), not to a lens-sized box. It
        then disappears completely inside the glass, with no box sticking out at the end. (Today it
        lerps from the lens's box, `lensX() ± sr`, to its own box; that start becomes the centre
        point.)
     3. **The close spring:** keep `spatialFast` if the tail looks fine once 1 and 2 are done;
        otherwise a slightly faster tail. My call; the report notes which, and why.
        - **Snappy:** `spatialFast` (1400, 0.9) is within 2% of shut in about 130 ms, but its last
          30% → 0.4% takes about 90 ms. With the panel shrinking to a point inside the glass, that
          tail is hidden under the glass. If it still reads as slow, it gets a stiffer, critically
          damped spring.
     4. **Tests:** sample at the centre and on a ring just inside the glass edge, at several closing
        stages including the last 20%, and the same for opening.
   - **Later, not 183:** Prism's own panels will go into and come out of Prism's button the same way,
     as part of the panel-family redesign.
4. **Blob labels never cover an icon or a badge** (approved by the owner; from the review chat,
   16 November 2026).
   - **The bug:** with the Sidekick's blobs open over WhatsApp, the "Facebook" label is drawn over
     WhatsApp's "4" notification badge.
   - **What the code shows** (read, not seen on a phone): the Sidekick's menu (`Menu.onDraw` in
     `MainActivity.kt`) draws blob by blob in one loop: the picture (`paintBlob`), then its badge
     (`paintBadge`), then its name (`canvas.drawText(items[i].name, …)`), at full length with no
     width limit. So a later blob's name is drawn over an earlier blob's badge. Prism's own blobs are
     drawn in `shell.dart`; where their labels are drawn is to be found when building.
   - **Spec, for Sidekick and Prism blobs alike:**
     1. **Draw order:** all labels first, then all icons, then all badges. A label may be covered; an
        icon or badge never.
     2. **Label max width:** about 1.5× the blob's diameter. Longer names are shortened with "…" (the
        ellipsis at the end), using one shared function on both sides (Kotlin and Dart), at whatever
        text size the phone uses.
        - (Kotlin and Dart can't share one function. So it's the same rule, under the same name, on
          each side. A test op asks Android to shorten the test's names, and the test checks that both
          sides give the same result.)
   - **Test:**
     - With a long app name and an app with a badge as neighbours, open at the top, middle and bottom.
     - Check that no label's box overlaps any icon or badge drawn after it, that is, badges and icons
       are on top.
     - Check that every label fits within its maximum width.
     - Repeat with large text if part 5 can set it. Otherwise, check that the shortening function
       shortens a long name at 1.5× text scale.
   - **For the large-text item** (`QUEUE-large-text.md`): use the same shortening function there.
5. Whatever the 182 phone results ask for. The review chat adds it here.

**Later, for step 3's brief (the Sidekick's own app chooser),** not for 183: after a Change or Add, the new
blob shows only once Prism has sent its picture. Only a menu where every blob is new has nothing to open
meanwhile, which a person can't make in one step. Worth deciding in step 3 whether a blob without its
picture yet shows a placeholder.
