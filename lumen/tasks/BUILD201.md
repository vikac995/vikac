# Build 201: the test's own store (F02 + F34)

From the review chat (16 November 2026, 22:30 and 22:43), planning only: "Plan it as the build after the
list. I'll give the go." Wait for the go.

**Why (an outside read-only review of build 194, spot-checked by the review chat and by me):**
- **F02:** the button test writes its blobs to the owner's real files through `BlobSlots.put`, and
  restores them only at the end. Confirmed by reading:
  - `put`/`putAll` write `prism_blobs_v1`, `GestureSlots.put` writes `prism_gestures_v1`, and `setNames`
    writes `prism_blob_names`, all synchronously.
  - `_longTest` keeps the owner's keys only in memory and puts them back in its `finally`.
  - The Sidekick's menu (`SidekickMenu.testPut`) and its settings are saved to Android's prefs during
    the test.
  - A killed process (swiped away, a crash, a reboot, a flat battery) never reaches the `finally`.
- **F34:** the test also switches the owner's glass quality, reduce-transparency, lights and glass mode
  (diag.dart `_apply`/`_restore` ~537–543, ~626–634; shell.dart ~3070–3074, ~7568–7634, ~8106–8114),
  restored only at the end. Harmless today only because they aren't persisted. "Give them the same
  test-scoped overlay, never saved, so it stays safe once settings persistence lands."

**The plan (agreed, "marker file included"):**
1. **Dart:**
   - BlobSlots, GestureSlots and the names get a test mode. While it's on, changes are kept in memory
     and written only to test files, never the real ones.
   - `beginTest()` at the start of `_longTest`, `endTest()` in its `finally`: test mode off, reloaded
     from the real files. This replaces the manual restore.
   - The settings in F34 get the same test-scoped overlay, never saved.
2. **Android:** SidekickMenu and SidekickSettings get the same mode: nothing is written to prefs while
   it's on, and memory is reloaded at the end. New test steps on the `lens` channel turn it on and off.
3. **Marker:** a marker file written as the test begins and removed as it ends. Found at the next start,
   it means a test ended unfinished; Prism notes it in the flight recorder ("your menu was not touched").
4. **Checks:**
   - After the test's own `putAll(five)`, the real menu and swipe files still hold the owner's.
   - At the end, all three files are byte-for-byte as they began.
   - On the phone, the Sidekick's prefs are unchanged during the test.
   - The F34 settings, whatever is saved for them, are unchanged.

**Its number (the lead, 17 November, 12:23, 12:50):** "after 197 (the glass), go straight on with 198
(the Sidekick's app list), then 199 (the test-safety fix), then 200 (search), one at a time, each posted
on the board as usual"; then the low-Sidekick bug came first (198, 199), and "the app list, the test
store and search follow, renumbered after it": 201 is the test store, 202 search.

**Found while building it:** the test also changes the person's look (its colour vibe), Auto's glass
level (a test's heavy scenes can step it down), the pinned thing, the timer's count up or down, Prism's
icons and the app list's density, each saved to a file of its own; and the Sidekick's app-open counts
(200). All of them are kept apart the same way.
