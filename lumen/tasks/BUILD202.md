# Build 202: search in the Sidekick's app list

From the review chat (16 November 2026, 21:25, the app list's brief, points 2 and 4, and its checks; split
off at 21:27; numbered 202 by the lead on 17 November, "Go on with 202 search", 14:01).

From the app list's brief:
- "**Layout, top to bottom:** header "Change blob N" / "Add a blob", and ✕; **"Suggested"**: the 8
  most-used apps as a 4×2 icon grid with names; a search field; "All apps", A–Z, as rows with icon and
  name."
- "**Search:** a tap focuses the field and shows the keyboard (the panel then needs to accept focus while
  the field is active; give focus back when the list closes). Typing filters both sections live."
- Checks: "Search filters." "The keyboard comes up for search and Back closes the keyboard first."

And from 200 (my note to the review chat, which it approved): the list keeps out of the keyboard's way
(FLAG_ALT_FOCUSABLE_IM) until search needs it; search clears that flag while its field is in use.
