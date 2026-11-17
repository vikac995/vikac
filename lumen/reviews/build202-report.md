# Build 202 report: search the Sidekick's app list

Brief: `tasks/BUILD202.md` (the app list's brief of 16 November, points 2 and 4 and their checks, split off
from it; numbered 202 on 17 November).
- **The one change:** a search field in the Sidekick's own app list (200), with the keyboard.

**Only the preview has run it.** The list and its keyboard are Android's.

## What it does

**The field:**
- Between "Your most used" and "All apps": a rounded field, a magnifier, "Search apps".
- While it has the focus: an accent edge and a caret.
- Once something is typed: an X at its right that clears it.

**A tap on it:**
- **The focus:** it takes the focus.
- **The keyboard:** its window, which kept out of the keyboard's way while the list was only looked at
  (200), now takes the keyboard. The flag is dropped while the field is in use.
- **The field moves up** to just under the list's header, where the keyboard can't cover it.
- **The keyboard is asked for at once,** and again 0.12 s later if Android hadn't shown it (the window
  takes a moment to have the focus with its new flags), and again whenever the window gets the focus
  back while searching.
- **The panel ends above the keyboard:** its bottom limit already counts the keyboard's inset (186), and
  it's laid out again as the keyboard comes up.

**Typing:**
- **Both parts are filtered live:** "Your most used" and "All apps", by any part of an app's name, with
  case and accents set aside ("whats" finds WhatsApp; "cafe" finds Café).
- **The field stays still** on the screen while the lists under and over it change.
- **When nothing matches:** it says "No apps match "…"".
- **The keyboard's Search key** puts the keyboard away. What was typed, and the list it filters, stay.
- **A pick from a filtered list** works as any pick (200).

**How the typing reaches it:**
- The panel is drawn by hand, so it's its own text editor: an input connection over what's typed, with
  composing and deleting as any keyboard does them.
- Suggestions are off: these are app names.
- A hardware keyboard's letters and its delete key work too.

**Back:**
- **With the keyboard up,** Back puts it away first. Android usually does this itself, before Back
  reaches the list; the list does the same if Back reaches it. The next Back closes the list.
- **When the list closes** (any way), the keyboard goes with it at once, as the focus goes back to the app
  behind (200).

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickPanel.kt` | **The field:** `Kind.SEARCH`, drawn by `drawSearch`. **The filter:** `matches`, `fold`. **Focus and keyboard:** `startSearch`, `showKeyboard`, `hideKeyboard`. **Typing:** `onQueryChanged` keeps the field still; the input connection (`onCheckIsTextEditor`, `onCreateInputConnection`); keys in `dispatchKeyEvent`. **Back:** the keyboard first. **Closing:** the keyboard goes with the list. **Taps:** the field and its X. **For the test:** its places (`search`, `search.clear`), its state (the field's focus, what's typed, the keyboard asked for and up, Back's count, the parts in order, the most used and the rows shown, "no match"), and `testType`. |
| `android/.../MainActivity.kt` | The test's `panel` step gains `type`. |
| `lib/fit/shell.dart` | Part 4: the search checks (below). |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 202, "Search the Sidekick's app list", `askedTest = 'button'`; `0.163.0+230`. |
| `DESIGN.md` | §6: search; the keyboard only once the field is tapped. |
| `tasks/BUILD202.md`, `CHANGELOG.md` | The brief; build 202. |
| `releases/prism-build-202.apk` | The build. |

## The checks (part 4, in Prism)

1. "its app list has a search field between 'Your most used' and 'All apps'" (the parts in order).
2. "a tap on its search field focuses it and asks for the keyboard, and its window may now take the
   keyboard". A note says whether the keyboard came up.
3. "typing in its search filters 'All apps' live: every app shown has what was typed in its name". It
   types the first three letters of the first app A to Z.
4. "typing in its search filters 'Your most used' too".
5. "when nothing matches, its list says so" ("zqxjv").
6. "its search cleared by its X: every app is back".
7. "an app picked from a filtered list: that blob becomes it".
8. "Back puts its search's keyboard away first, and then closes the list". If the keyboard wasn't up for
   the test, one Back closes the list, and it says so.

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 84 right, 1 wrong, 1 skipped, of 86 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 68 right, 3 wrong, of 71 (the usual 3, all "measured: no answer", Android-only)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.
- **The search checks are Android's,** so the preview doesn't reach them.

**Build 202:**
- `Prism build 202`, `0.163.0+230`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- **Its `classes.dex` has:** "Search apps", "No apps match", `imeHiddenByBack`, `shownRows` and "search
  field focused".
- **Its `libapp.so` has:** "Prism build 202", "Search the Sidekick's app list" and the new checks.
- sha256 `e8d581ea6671e6d0925442e691171c875a11815678d17a8e1f41da5970ff7efc`, 18,960,842 bytes.
- Link: added once it is pushed and checked.

## Where I could be wrong

1. **None of it has run on a phone,** and the keyboard is where this most could differ.
2. **The keyboard for a window over another app.**
   - The window needs the focus without "keep out of the keyboard's way" before Android will give it the
     keyboard. It's asked at once, again 0.12 s later, and again as the focus comes. If One UI still
     won't show it, the field has the focus with no keyboard. Check 2 notes whether it came up.
   - A hardware keyboard would still type.
3. **A hand-made text field:**
   - **No selection, copy or paste,** and the caret is always at the end. That's enough for typing a few
     letters of a name.
   - **Some keyboards' gesture typing or voice input** sends text in ways I've handled by the book
     (composing, then committing), but not seen.
4. **The keyboard over the panel:**
   - **The panel's bottom follows the keyboard's inset.** As it comes up, the panel is laid out again
     above it, centred on the Sidekick: so the panel may move a little.
   - **The field's place:** it's put just under the header first, so it stays in sight.
5. **The panel's size doesn't shrink while typing** (so nothing jumps under the finger). With few
   matches, there's empty space under them.

## On the phone

**What to look at:**
- **Over another app:** hold a Sidekick blob, tap Change, then tap "Search apps". The keyboard comes up,
  and the field sits under the header.
- **Typing:** type a few letters. Both lists narrow as you type. Tap a result: it lands.
- **The X:** it clears the field.
- **Back:** once puts the keyboard away, twice closes the list.
