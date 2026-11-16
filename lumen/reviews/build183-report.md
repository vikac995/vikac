# Build 183 report: testing tools

Brief: `tasks/BUILD183.md`, which is `tasks/QUEUE-next-build.md` items 1, 5, 6 and 7, as the owner approved.
Testing tools only: nothing the owner uses in Prism or the Sidekick changes.

**Only the preview has run it:** the Prism side, and the past-report checks. Every Android-side check
(the pictures wait, the Sidekick's place, the panel's samples) runs only on a phone.

## Files changed

| File | What changed |
|---|---|
| `lib/fit/past_reports.dart` (new) | `PastReports`: one file per finished report in `files/prism_reports`. Written to a spare file and then renamed, so a crash leaves all or nothing. The newest 20 are kept. Each file name holds the time and the test's name. `PastReport` reads back its text, build and result. |
| `lib/fit/shell.dart` | The badge, the shared test button (`_testButton`, the asked-for one green with its tag) and the past reports list. A finished test is kept as a past report first of all, and a note added to it goes into the same file. Button test changes: the pictures wait; `lensMid`; the five-moment samples; "never hides"; the past-report checks. The preview-only `PRISM_PANEL_SHOW` switch. |
| `lib/fit/main.dart` | The preview-only `PRISM_TEXT_SCALE` switch (a larger system text size, for the large-text pictures). |
| `lib/fit/recorder.dart` | "Send what just happened" is kept as a past report too. |
| `lib/fit/diag.dart` | `buildNumber`, `buildDate`, `buildTitle` and `askedTest = 'button'`, set with every build. Build 183. |
| `android/.../MainActivity.kt` | The test state gives `lensMid` and `lensRadius`: the Sidekick's middle and glass from where it really is on the screen. `lensWindow()`. The `sample` op takes several `stages`. |
| `android/.../SidekickPanel.kt` | `standIn` records what it was asked and whether it drew (`lastAsked`, `lastDrew`). Each sample says so, with the Sidekick's window place and the sampled point. |
| `pubspec.yaml` | `0.144.0+211`. |
| `tasks/BUILD183.md`, `CHANGELOG.md`, `tasks/QUEUE-large-text.md` | The brief; build 183; two large-text findings. |
| `reviews/shots183/` | The test area and the past reports at text sizes 1.0, 1.3 and 2. |
| `releases/prism-build-183.apk` | The build. |

## Item 1: the pictures wait

- **When:** after the test gives the Sidekick its own menu (part 4, and the round trip's menu).
- **How:** the test reads `sidekickPicturesFor` every 150 ms until it reads "n of n", for up to 6 s.
- **Notes:** a NOTE says how long it took: "the Sidekick's pictures for its menu had all come N ms after …".
- **If they never come:** "a tap opens its blobs" is WRONG with that reason ("Prism's pictures had not all
  come 6 s after …"), instead of a silent miss.

## Item 5: the three 182 checks, and the side check

**1 and 2, "at its spot":**
- **Now:** the hole is compared with `lensMid`, the Sidekick's middle where it really is on the screen.
  That's the same source as the hole and the stand-in.
- **Both checks print:**
  - the hole;
  - `lensMid`;
  - the old figure from where its window was asked to be;
  - roaming;
  - the window's size.
- **A NOTE says by how much the two figures differ, when they do,** because other checks still use the
  old one.

**3, the stand-in:**
- **Sampled at five moments:** 6%, 12%, 25%, 50% and open (100%). The geometry is the same on the way
  back in.
- **For each moment, a NOTE in plain words:**
  - whether the panel covers the Sidekick;
  - whether the stand-in was asked for, and whether it was drawn;
  - whether the pixel at its middle is the Sidekick's or the panel's, with the three colours;
  - where the Sidekick's window was from the panel's corner, and the point sampled.
- **The check:** every moment that covers it and can tell (where the Sidekick's middle isn't the panel's
  own colour) shows the Sidekick. SKIPPED, with why, if none can tell.

**The side check, as decided (b):**
- **Two checks now:**
  - "about 330 points wide, on the side away from the Sidekick": its middle beyond the Sidekick's;
  - "open, the panel never hides the Sidekick": at 100%, either the panel is clear of it, or the pixel
    at its middle is the Sidekick's.
- **Both print:** the Sidekick's side, its middle and glass, its Hovering distance, how far the panel
  reaches over its glass (or how clear of it it is), and the panel's box.

## Item 6: Past reports

- **Kept, first of all, the moment a test ends:**
  - every finished test (button, long, leak, hour-long, stability, battery, glass): they all end in
    one place;
  - "Send what just happened".
- **Not kept as past reports:**
  - a test cut short leaves its partial report as "the last report", as before;
  - the short guided "Run the test" has its own "Copy test report" and isn't kept. It wasn't in the
    brief's list; it can be added if wanted.
- **Under "Copy the last report":** "Past reports", newest first. Each row shows "Button test · build
  183", then "Today 13:05 · 69 right, 1 wrong" and a Copy button. A tap anywhere on the row copies the
  report, through the same copy as "Copy the last report".
- **Checked in the button test** (in a folder of its own, so the owner's list isn't touched):
  - one report is kept, then read back by a new reader from storage, as after a restart;
  - it matches byte for byte (with ½, quotes, an emoji and a Windows line end in it), with the right
    name, time, build and result;
  - then 22 more are kept: only the newest 20 stay, newest first.

## Item 7: the test area

- **The gold badge at the top:**
  - "183", "You're testing build 183", and "16 November · Testing tools: past reports and the test to
    run";
  - it replaces the grey "Testing · build" line, and keeps its test key `buildName`.
- **Colours:** the mock-up's (gold `#E3AD55` on a dark gradient). The badge keeps its own light text,
  so it reads the same in a light theme.
- **Font:** the number uses Prism's own display font, not the mock-up's web font.
- **The asked-for test:**
  - `Diag.askedTest = 'button'` makes the button test's button green (`#3FCF8E`), with a "TEST THIS ONE"
    tag on its top edge;
  - '' makes none green.
  - All eight test buttons now come from one builder.
- **A small difference from before:** the buttons are at least 52 tall rather than exactly 52, so a long
  label wraps onto a second line instead of being cut.

**At large text sizes (preview, pictures in `reviews/shots183/`):**
- At 1.3×, everything fits and wraps.
- At 2×, the badge, the buttons and the past reports wrap properly.
- **Not mine, unchanged, noted in `QUEUE-large-text.md`:**
  - the two buttons "Copy test report" and "Start over" clip their words at 2×;
  - the home screen's workout card breaks words letter by letter.

## Results (preview, on the final code)

```
button test:  CHECKS: 69 right, 1 wrong, of 70
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(...))]
  ok     past reports: one kept is read back after a restart, byte for byte  [98 bytes back of 98; "Button test", build 183, "605 right, 12 wrong", 2026-11-16 12:33:00.000]
  ok     past reports: only the newest 20 are kept, newest first  [20 kept, newest "… leak test 22", oldest "… leak test 3"]
long test:    CHECKS: 62 right, 4 wrong, of 66 (the usual 4)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.

**Build 183:**
- `Prism build 183`, `0.144.0+211`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- Its `classes.dex` has `lensMid` and `sampleDrew`. Its `libapp.so` has "Prism build 183", "TEST THIS ONE"
  and `prism_reports`.
- sha256 `0e9de9209c68215e539e6f3742ae04d7e2112f0e9266325897f891bf2c5237f6`, 18,731,258 bytes.
- Link: LINK_RESULT

## Where I could be wrong

1. **The stand-in samples may still not say why** it's missing, if it is. They now report whether
   `standIn` was asked and drew, and where the Sidekick's window was. If both say "yes" and the pixel is
   still the panel's, the problem is in how the Sidekick draws into another window's canvas. That would
   need its own look.
2. **"At its spot" now trusts `lensMid`.** If the Sidekick's window is roaming (stretched over its path)
   when the state is read, `lensMid` is that window's middle, not the Sidekick's. The check prints
   "roaming" when it is.
3. **Past reports read the build and result from each report's own text,** by the build line and the
   "CHECKS:" line. A report without them (the recorder's) shows its name and time only. A report kept
   in the moments before the phone's clock changes may sort one place out.
4. **The 2× pictures are the preview's text scaling,** a straight 2×. Android's own largest size scales
   large text less than small text, so a phone may look a little different.

## On the phone

**What's new to look at:**
- The badge at the top of the test area.
- The green button test.
- After the test, "Past reports" with that run in it.

**In the button test's report:**
- The NOTES give the pictures' wait.
- They say, for each of the five moments, whether the Sidekick was drawn on top of its panel.
- The check details give both figures for the Sidekick's middle.
