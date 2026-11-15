# Step 1 of 4: give the Sidekick its own menu

Read first: `lumen/HANDOVER.md` (how to work with the owner, the rules, the plan), `lumen/DESIGN.md`
(the design rules: follow them exactly), the top of `lumen/CHANGELOG.md`. This task is step 1 of "THE
PLAN" in the handover. Your work will be reviewed line by line before the owner relies on it.

## The goal

Today the Sidekick's blob list lives inside Prism: `BlobSlots` in `lib/fit/apps.dart` holds Prism's
list and a `_side` list that mirrors it until changed, and `show(side: true)` switches which list
Prism's own blob code edits. Every Sidekick edit is done by Prism. After this step:

- **The Sidekick's list is owned and saved by Android** (the Sidekick's code in
  `android/app/src/main/kotlin/dev/lumen/lumen/MainActivity.kt`, in its own small class or file, for
  example `SidekickMenu.kt`), in SharedPreferences. It holds up to 5 keys (`app:<package>`,
  `action:<n>`, `screen:<n>`, `phone:shade`, `phone:side`...), with the empty ones always last.
- **`BlobSlots` holds only Prism's list.** No side list, no switching.
- **Remove on a Sidekick blob is done entirely on Android**: the others close up in the middle at
  once, Prism is not brought forward, Prism's menu is untouched.
- **Change / Add on a Sidekick blob** still use Prism's app list for now (step 3 replaces it), but
  only as a chooser: Prism shows the list, the chosen key is sent back to Android, Android puts it in
  the Sidekick's list (Change: that place; Add: right after the held blob; Add Blob: at the end).
  Prism's own blob menu is never touched, never opens afterwards, and Prism's triangle does not turn.
  If Prism was brought forward only for this, it steps back to the app that was open (as now).
- Reordering inside the Sidekick's menu (dragging its blobs) is done entirely on Android.

## Pictures

Android still gets each blob's name, colour and picture from Prism (Prism draws the Prism-style
icons). Keep that, but as one-way data: when the Sidekick's list changes, Android tells Prism the keys
(e.g. `sidekickKeys`), and Prism answers by sending the pictures for exactly those keys (the existing
`_blobMap` in `shell.dart` does the drawing). Prism must not keep or edit the Sidekick's list.

## Moving the saved list over (once)

On the first start of this build, the Sidekick's list must stay what the owner had: if the old saved
side list (`prism_blobs_side`, written by `BlobSlots`) exists, use it; otherwise the Sidekick starts
with a copy of Prism's list (that is what it showed). Do this once, then Android owns it.

## Remove from Prism's code (and say so in the changelog)

In `lib/fit/apps.dart`: `_side`, `_showSide`, `side`, `sideOwn`, `sideAt`, `show(side:)`, `sideAsMain`,
`putSideAll`, `_sideFile` (after the one-time move). In `lib/fit/shell.dart`: `_sideKey`, `_pickSide`,
`_showMenu(side:)` and the "changing the side menu" paths, the `blobOrder` / `sideRemove` handlers'
list editing, and anything else that edits the Sidekick's list. Keep the settings report's "side menu:"
line (read the Sidekick's keys from Android, or from the last keys Android sent).

## Do not

- Change how anything looks or moves. This step moves data only.
- Touch the workout timer (`TimerBubble`) or the other floating modes: that is step 4.
- Build the Sidekick's settings panel or app list: steps 2 and 3.
- Loosen or delete a test to make it pass. Update tests only where the behaviour changed, and say how.
- Push anywhere but your own session branch (see below).

## Done means

1. `grep` finds no Sidekick list in `BlobSlots`, and no code in `shell.dart` that edits one.
2. In the preview: `tools/preview/test.sh long` gives 65 of 69 and `tools/preview/test.sh buttons`
   gives 62 of 63 (the misses are the known ones, listed in `tools/preview/README.md`). Run each twice
   if a timing check misses.
3. The button test's Sidekick half is updated for the new ownership and checks, on the phone:
   Remove changes only the Sidekick's list and does not bring Prism forward; Add and Change put the
   key only in the Sidekick's list; Prism's list is the same before and after; after the move the
   Sidekick shows the same blobs as before. (It cannot run in the preview: say so.)
4. Both sides compile; one release APK, build 170, with the NAME-OK check and a commit-pinned link
   that answers 200; a `CHANGELOG.md` entry.

## Your report (for the review)

Write `lumen/reviews/step1-report.md` and push it with the build:

- every file changed, and in one line each what changed;
- everything removed from Prism's code;
- the new Android class: what it stores, where, and every message between Prism and Android about
  the Sidekick's list now (name, direction, what it carries);
- how each "Done means" item was checked, with the test results pasted;
- what you could not check, and what the owner should try on the phone, step by step;
- anything you were unsure about, and what you chose.

## Branch

Start from the latest work: `git fetch origin claude/flutter-ui-showcase-ngzfru` and base your session's
branch on `origin/claude/flutter-ui-showcase-ngzfru`. Commit and push to the branch your session was
given. Tell the owner the branch name and the commit when you are done, so the review can read it.
