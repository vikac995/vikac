# Build 200 report: the Sidekick's own app list

Brief: `tasks/BUILD200.md` (the review chat, 21:25, split at 21:27; renumbered at 21:45 and 21:59, when
hold-to-dismiss became 195; on 17 November at 07:17, when Dismiss under the Sidekick became 196; at
12:21, when the bigger magnifying glass became 197; and at 12:24, when the owner's low-Sidekick bug
became 198 and 199).
- 200 is the list: "Your most used", "All apps", picking and closing, with Prism never brought forward.
- Search and the keyboard are 202 (201 is the test's own store).
- Before it goes, the review chat asked for a header that stays put, the focus given back the instant it
  closes, and a pressed look on rows and icons.

- **The search field is hidden** (my call, as the split allowed): a field that takes no typing would look
  broken under a finger. 202 adds it between the two parts, with the keyboard.

**Only the preview has run it.** The list, its panel and its window are Android's. It is built on 199.

## Files changed

| File | What changed |
|---|---|
| `android/.../AppChoices.kt` (new) | **What the list offers:** each item is general (kind, key, name, and for an app its package), so Prism's actions and screens can join later. **All apps:** every app on the home screen, each once, Prism left out, A to Z. **Most used:** up to 8, ranked as below. **Icons:** drawn when wanted, away from the main thread, kept only while the list is open (at most 12 MB). **Counts:** how often each app was opened from Prism or the Sidekick. |
| `android/.../SidekickPanel.kt` | **The panel's second mode, its app list** (`Chooser`, `openChooser`, `picked`). **Its header** ("Change blob N" or "Add a blob", and the ✕) stays put while the lists scroll under it. **Its contents:** the grid, the rows, the pressed look, and "Finding your apps…" while they're read. Only the parts in sight are drawn. **Its window** takes the focus while the list is up (for Back), never the keyboard, and gives the focus back as it begins to close. **The test's view of it:** state (`chooser`, `chooserPicks`, `chooserReopenMs`, `panelNoKeyboard`), places (`suggested.N`, `all.N`, `pick.<key>`) and Back (`testBack`). |
| `android/.../SidekickMenu.kt` | `hasPicture`: whether Prism has sent a key's picture. |
| `android/.../MainActivity.kt` | **Change and Add** now open the list in the Sidekick's panel. **Gone:** bringing Prism forward, asking it to choose (`askPrism`), and its answer (`sidekickChosen`, `toBack`). **New:** `openMenuAgain`. **Counted:** an app opened from a Sidekick blob or from Prism. **The test's `panel` step** gains `back` and `spot`. |
| `lib/fit/shell.dart` | **Gone:** Prism's side of the old path (Android's ask, place 200, the step back, "closes the list and goes back"). **Checks:** part 4's Change and Add rewritten (below). |
| `lib/fit/bubble.dart` | `sidekickChosen` removed. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 200, "The Sidekick's own app list", `askedTest = 'button'`; `0.161.0+228`. |
| `DESIGN.md` | §6: the Sidekick's app list; the focus while it is up. |
| `tasks/BUILD200.md`, `CHANGELOG.md` | The brief, the split and the renumbering; build 200. |
| `releases/prism-build-200.apk` | The build. |

## The list

**Opening it:**
- Hold a Sidekick blob and tap Change or Add.
- Its blobs fold away, and 0.2 s later the list opens out of the Sidekick, as its settings do. It has
  their width, side, motion and bar rules: under the status bar, and 8 points above Android's bar or, in
  Prism, Prism's.
- **Prism is never brought forward,** in Prism or over another app, and Prism's own list never comes up.

**Its layout, top to bottom** (as in the approved mock-up):

| Part | What it shows |
|---|---|
| Header | "Change blob N" or "Add a blob", and the ✕ (and no "Hold to dismiss" under the Sidekick). It stays put. |
| "Your most used" | Up to 8 apps, four across: 42-point icons, 11-point names under them, cut with "…" when long |
| "All apps" | Every app, A to Z, one to a 44-point row: a 28-point icon and its 14-point name |

**The header stays put** (the review chat's change):
- Only the two lists scroll, under it.
- Once they have scrolled, a hairline shows under the header.
- The ✕ is always in reach.

**Pressed** (the review chat's change):
- A row or an icon dims (a soft ground of the panel's ink behind it) and shrinks 6%, in the next frame
  after the finger comes down.
- A finger that starts to scroll lets it go.

**Also:**
- **While the apps are read** (about a moment) it says "Finding your apps…".
- **It scrolls and flings** as the settings panel does.
- **An icon not drawn yet** shows as a soft rounded square until it is.

**"Most used":**
1. By time in front over the last 14 days, from Android's usage stats, when Prism may read them (it can,
   for screen time).
2. Otherwise by how often each was opened from Prism or the Sidekick, counted from this build.
3. Otherwise the first 8 A to Z.

If fewer than 8 were used, the rest are filled from A to Z, each app once.

**A tap on one:**
- **Change:** that blob becomes it.
- **Add:** it goes in right after the held blob.
- The list closes back into the Sidekick, and its blobs come out again with the change.
- **When they come out:** once the list has gone (0.32 s) and once Prism has sent the new blob's picture
  (an open fan keeps the blobs it opened with), waiting at most 1.5 s.

**Closed without a change by:** its ✕, a tap beside it, Back, or Home.

## The focus, the keyboard and a video behind

**The focus:**
- The list's window takes the focus while it is up, so that Back reaches it.
- **It gives the focus back the moment it begins to close** (the review chat's change), not when it has
  finished going back into the Sidekick (about 0.2 s later).

**The keyboard: it should not go down at all.**
- The window is marked "alternate focusable for the input method" (`FLAG_ALT_FOCUSABLE_IM`). Android's
  rule: a focusable window with this flag doesn't interact with the keyboard.
- So the app behind stays the keyboard's window, and its keyboard, if up, is left as it is: up while the
  list is open, still up when it closes.
- **The catch:** the keyboard may cover the lower part of the list. The list's lower edge is set by the
  navigation bar, not the keyboard.
- **202 changes this:** search will need the keyboard for the list itself.
- **By reading only:** not yet seen on a phone.

**A playing video behind: it should keep playing.**
- The app behind isn't paused or stopped (the list is a window over it, not a new screen). It only loses
  the focus for as long as the list is up.
- Most video players (YouTube, Netflix, and apps built on Android's own player) pause on being paused or
  stopped, not on losing the focus, so they play on.
- **Some apps do pause on losing the focus,** mostly games. They get it back the moment the list begins to
  close. Whether they then resume on their own is up to each app.
- **By reading only.**

## The tests (part 4)

**Removed:** the old Change and Add checks (Prism's list for the Sidekick, the button wearing the blob,
"over another app, Change brings Prism forward…").

**Reworded:**
- "Remove asks nothing of Prism" is now "Remove opens no list".
- The slide from Remove onto Change also checks that no list opened.

**New, in Prism:**
1. "Add opens its own app list in its panel, 'Add a blob', for after the held blob".
2. "its app list takes the focus (for Back) but never the keyboard".
3. "its app list in Prism: Prism's own list does not come up, and Prism's blobs stay as they were".
4. "'Your most used' holds 1 to 8 apps, each once and each one of 'All apps'; 'All apps' has each app
   once, a row each". A note says what "most used" was ranked by.
5. "its app list in Prism is clear of the bars".
6. "its app list's header stays put: scrolled to the last app, its title and X are where they were".
7. "its app list gives the focus back the moment it begins to close". Read 40 ms after the ✕ is tapped:
   it's closing, and its window no longer takes the focus.
8. "its app list's X closes it, and nothing is changed".
9. "Change opens its own app list in its panel, 'Change blob 1'".
10. "an icon in its app list looks pressed while the finger is on it". Read 0.125 s into a 0.25 s press.
11. "one of the most used picked for Change: that blob becomes it, the list closes and its blobs come out
    again" (it prints how long they took).
12. "picked in its list: Prism's own menu and blobs are as they were, and Prism's list never came up".
13. "Prism sends the picked app's picture, and the Sidekick shows it".
14. "a row in its app list looks pressed while the finger is on it".
15. "an app picked from 'All apps' for Add: it goes in right after the held blob, only there" (a row, not
    the grid).
16. "its app list closed by a tap beside it / by Back / by Home: nothing is changed" (three checks).

**New, over another app** (skipped if none of the usual apps is found):
1. "Change opens its own list over it, and Prism stays behind".
2. "its app list is clear of Android's bar".
3. "picked for Change: that blob has it, and that app is still in front".
4. "Add opens its own list over it, and Prism stays behind".
5. "picked for Add: it goes in right after the held blob, and that app is still in front".
6. "its list closed by Back: nothing is changed, and that app is still in front".

**Not checked by the test:** a video or a keyboard in the app behind (the test has no such app to drive).

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 81 right, 1 wrong, 1 skipped, of 83 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.
- **The new checks are all Android's,** so the preview doesn't reach them.

**Build 200:**
- `Prism build 200`, `0.161.0+228`, built from the final code, on 199. Name `Prism`, package
  `dev.lumen.prism`.
- **Its `classes.dex` has:** "Your most used" and `panelNoKeyboard`, with 196's "Hold to dismiss", 198's
  `usualGap` and 199's `restLimits`.
- **Its `libapp.so` has:** "Prism build 200" and the new checks.
- **Neither has** `sidekickChoose`.
- sha256 `96aa902b7c1af08b06ad24f6f6d660e2e4fcb10f4457c15a4b2fa201aeec2017`, 18,960,842 bytes.
- Link (checked: answers 200, same sha256): https://github.com/vikac995/vikac/raw/1a64dc5be0e404264abd7197e12f932af55b3dcb/lumen/releases/prism-build-200.apk

## Where I could be wrong

1. **None of it has run on a phone.**
2. **The keyboard and a video behind are by reading** (above). If One UI treats the keyboard flag
   differently, the keyboard behind goes down while the list is up, as it did before this change, and
   most likely stays down after.
3. **The keyboard, when up, may cover the bottom of the list.**
4. **"Most used" from usage stats counts all use,** including apps opened outside Prism. Without usage
   access, the counts start at this build, so at first the list falls back to A to Z.
5. **The first open reads every app,** with icons drawn as they come into sight. On a phone with many
   apps, "Finding your apps…" may show for a moment, and the icons fill in.
6. **The test's Back** calls the list's own Back handling. It isn't Android's real back gesture. On
   Android 13 and later the real one comes through the same handler (`OnBackInvokedCallback`); before
   13, through the Back key.
7. **The pressed look shows at once,** so a finger that comes down to scroll flashes it on a row for a
   moment before the scroll lets it go. This is the price of "feedback in one frame".

## On the phone

**What to look at:**
- **Change, over another app:** hold a Sidekick blob and tap Change. The list opens beside the Sidekick,
  that app stays behind it, and Prism doesn't appear.
- **Scrolling:** scroll down "All apps". The header with the ✕ stays put.
- **Picking:** press an app and it dims at once. Let go: the list closes into the Sidekick, and its blobs
  fan out with the new one in that place.
- **Add** from a blob: the new one lands right after it.
- **Closing** each way (✕, a tap beside it, Back, Home): nothing changes.
- **With a video playing behind:** it should keep playing.
- **With the keyboard up in the app behind:** it should stay up.
