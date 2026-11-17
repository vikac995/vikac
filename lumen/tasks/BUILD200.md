# Build 200: the Sidekick's own app list

From the review chat (16 November 2026, 21:25). Prepare it on a local branch and hold it until the owner
has tried 194. Report the size first; the go comes once the owner's done with 194.

**Mock-up (approved, "most-used first"):** https://claude.ai/artifact/2UGwZ9VXNnKCtUcm2BuGkX

**Behaviour**
1. **Change and Add** on a Sidekick blob (its small menu) open an app list **inside the Sidekick's own
   panel**, over whatever app is in front. Prism is never brought forward, inside Prism or outside it.
   Replace today's path that brings Prism forward with its drawer.
2. **Layout, top to bottom:** header "Change blob N" / "Add a blob", and ✕; **"Suggested"**: the 8
   most-used apps as a 4×2 icon grid with names; a search field; "All apps", A–Z, as rows with icon and
   name. The same panel width, place and bar rules as the settings panel (185–194), and the same open and
   close motion.
3. **"Suggested" is a general list of items:** each {kind: app | action | screen, key, label, icon}. For
   now apps only, ranked by use: UsageStatsManager if usage access is granted, otherwise by how often
   they've been opened from Prism or the Sidekick, otherwise alphabetical. Later it will also hold Prism's
   own actions and screens (the blob keys already support action:/screen:), so no app-only assumptions.
4. **Search:** a tap focuses the field and shows the keyboard (the panel then needs to accept focus while
   the field is active; give focus back when the list closes). Typing filters both sections live.
5. **Pick an item:** that blob becomes it (Change) or it's inserted after the held blob (Add), the list
   closes, and the blobs are shown again with the change. Same keys and storage as today.
6. **✕, a tap outside, Back or Home:** closed without change.

**Checks**
- Over another app: Change and Add open the list in the panel, Prism stays behind (not in front),
  picking works and lands in the right place, closing without a choice changes nothing.
- The same inside Prism.
- Suggested holds at most 8 items, with no duplicates of All apps' ordering bugs.
- Search filters.
- The keyboard comes up for search and Back closes the keyboard first.
- Nothing overlaps the bars.
- Remove or reword the old "Change brings Prism forward with its list" checks.

**The split (the review chat, 21:27):** "Split it: 195 = the list (Suggested, All apps, pick/close, Prism
never brought forward). Draw a search field but leave it inert, or hide it, your call; say which in the
report. 196 = search and the keyboard. Start 195 on the local branch and hold until I say the owner's
done with 194."

So it is points 1, 2 (without the search field), 3, 5 and 6, and every check but the two on search and
the keyboard. **My call: the search field is hidden** (a field that takes no typing would look broken
under a finger); search adds it between "Suggested" and "All apps" with the keyboard.

**Renumbered (the review chat, 21:45 and 21:59):** "195 = hold-to-dismiss ... The app list becomes 196 and
search 197. Keep the app list on its branch as 196, rebased on 195, and held."

**Two changes for 196 before it goes (the review chat, 21:59):**
1. "The header stays pinned (title and ✕ don't scroll away). Only the lists scroll."
2. "Taking focus: fine, since opening the list is a deliberate act. But give focus back the instant it
   closes, and say in the report whether a playing video, or the keyboard of the app behind, comes back."

"Add a pressed look on rows and icons too (a quick dim or scale on pointer-down, per the owner's
'feedback in one frame' standard)."

**Renumbered again (the review chat, 17 November, 07:17):** "196 = the Dismiss pill moves under the
Sidekick. It's its own small build, ahead of the list. New numbering: 197 = the app list (renumber your
held branch, rebase on 196), 198 = the test store fix (F02 + F34), 199 = search."

**Renumbered once more (the lead, 17 November, 12:21):** "197 = NEW: the magnifying lens ... 198 = the
Sidekick's own app list (was 197). 199 = the test-safety fix (was 198), 200 = search (was 199): still held
until the owner says."

**Renumbered once more (the lead, 17 November, 12:24 and 12:50):** the owner's low-Sidekick bug came
first, as 198 (the fan) and 199 (resting above the navigation bar); "then the app list, the test store
and search follow, renumbered after it": 200 the app list, 201 the test store, 202 search.
