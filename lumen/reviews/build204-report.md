# Build 204 report: badges on the outer side

Brief: `tasks/BUILD204.md` (the review chat, the lead, 18 November, 00:23: the owner's feedback on 202, on the
S26).
- **The one change:** a blob's notification badge sits on its outer side, away from the Sidekick (and on
  Prism's own blobs, away from the button).
- Until now it was always on the upper right, which on the right side faced the Sidekick.

**Only the preview has run it**, and the Sidekick's fan is Android's. Its placement is worked through by
hand below, with the same rules.

## The rule

**The Sidekick's blobs** (`FanLayout.badgeCenter`):
- **Where:** the blob's corner nearest the way away from the Sidekick's middle, 22 points out each way:
  the corner whose two signs are those of the blob's place relative to the Sidekick. That's the same
  "away from the Sidekick" as its name.
  - From a Sidekick on the right, its blobs are up and to the left of it, so the badge is on their upper
    left. Low in a corner, where the fan reaches below it, a blob below the Sidekick wears it lower left.
  - From one on the left: the upper right (or lower right).
- **Straight above or below the Sidekick:** on the side away from the screen's edge it's at.
- **Used in all three places:** the fan's layout (`badgeRect`, which the names keep clear of), the menu's
  drawing (`paintBadge`) and the fan's test.

**Never on its name:**
- Names are laid out after the badges and keep clear of them, as since 191.
- A name that would meet its badge on the line from the Sidekick goes straight beside its blob instead,
  still away from the Sidekick, or shorter.

**Prism's own blobs** (they do show badges: the notification count from the "notification counts" setting):
- A blob to the left of the button wears its badge on its upper left.
- One to the right, or straight above, on its upper right.
- Their names are under them, so a badge on top never meets one. (`_badgeLeft`, from the blob's direction
  from the button.)

## Worked through (the S26's 411 × 891 points, the usual five blobs, names on, a badge on every blob)

Done with the same fan, badge and name rules (names taken as 70 points wide):

| Side, height | Badges outward | Nearest other blob or the Sidekick | Nearest name to a badge | Names moved beside |
|---|---|---|---|---|
| right, high | 5/5 | 32.7 | 2.7 | 2 |
| right, middle | 5/5 | 26.7 | 4.7 | 4 |
| right, low | 5/5 | 33.6 | 3.4 | 2 |
| right, the very bottom (199) | 5/5 | 25.9 | 1.8 | 2 |
| left, the same four | 5/5 | the same | the same | the same |

**No badge comes near another blob or the Sidekick.** With a badge on every blob, two to four names go
beside their blob instead of along the line. Only blobs with notifications have badges, so usually fewer.

## The checks (part 4)

**The fan's test (191, 198) now puts a badge on every blob** at its ten places: a stand-in, one digit
wide, where an app has no notifications now. So where badges go is checked whatever is waiting.

**New:** "in its fan on both sides, every badge is on its blob's outer side, away from the Sidekick, never
on its name, another blob or the Sidekick".
- **Per place it needs:**
  - every badge outward;
  - none on another blob or the Sidekick (`badgeBlob` ≥ 0);
  - none on a name (`nameBadge` ≥ 0).
- **It needs badges counted on both sides.**
- **It prints** each place.

**The fan check itself** (blobs, names, badges, the screen and the bar) now includes these badges too.

## Files changed

| File | What changed |
|---|---|
| `android/.../FanLayout.kt` | `badgeCenter` (the rule); `badgeRect` takes the Sidekick's middle; `gaps` adds `badgeBlob`, `badgesOuter`, `badgesCounted` and "badge N facing the Sidekick" / "on blob N" / "on the Sidekick". |
| `android/.../MainActivity.kt` | The menu draws each badge at `badgeCenter`; its badge boxes and the fan's test use the same rule. The test puts a stand-in badge on every blob. |
| `lib/fit/shell.dart` | Prism's own blobs: the badge on the left or right by `_badgeLeft`. The new check. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 204, "Badges on the outer side", `askedTest = 'button'`; `0.165.0+232`. |
| `DESIGN.md` | §6: badges on the outer side. |
| `tasks/BUILD204.md`, `CHANGELOG.md` | The brief; build 204. |
| `releases/prism-build-204.apk` | The build. |

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 84 right, 1 wrong, 1 skipped, of 86 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 68 right, 3 wrong, of 71 (the usual 3, all "measured: no answer", Android-only)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.
- **The badge check is Android's,** so the preview doesn't reach it.

**Build 204:**
- `Prism build 204`, `0.165.0+232`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- **Its `classes.dex` has:** `badgesOuter`, `badgesCounted` and "facing the Sidekick".
- **Its `libapp.so` has:** "Prism build 204", "Badges on the outer side" and the new check.
- sha256 `43fe24732c7e1edc4192e382cd5e6073164b5653d402432fa222d74a24dd5597`, 18,960,842 bytes.
- Link: added once it is pushed and checked.

## Where I could be wrong

1. **None of it has run on a phone.** The table is worked by hand with names 70 points wide; real names
   differ, and the phone's check prints the real gaps.
2. **Names beside, not along the line:** a blob whose badge sits on the corner where its name would go
   has its name moved straight beside it. That's still away from the Sidekick, but not exactly the
   mock-up's line.
3. **Below the Sidekick, a lower corner:** in the few fans that reach below the Sidekick (low in a
   corner), those blobs wear the badge at their lower outer corner, as the rule says ("the corner nearest
   the outward direction"), not on top.
4. **Prism's own badges** are by reading. The preview's test has no notifications to show.

## On the phone

**What to look at:**
- **The Sidekick on the right**, with an app that has notifications: open its blobs. That blob's number
  sits on its upper left, away from the Sidekick, clear of its name.
- **On the left side:** upper right.
- **In Prism:** blobs to the left of the button wear it on the left.
