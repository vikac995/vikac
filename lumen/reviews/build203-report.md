# Build 203 report: the glass a quarter smaller

Brief: `tasks/BUILD203.md` (the review chat, the lead, 18 November, 00:23: the owner's feedback on 202, on the
S26).
- **The one change:** the magnifying glass a quarter smaller than in 197, its ride above the finger scaled
  with it. Nothing else.
- **Also from the owner:** 198's fan works.

**Only the preview has run it.**

## Files changed

| File | What changed |
|---|---|
| `lib/fit/shell.dart` | `_lensSize` 268.75 → 201.5625 points (1.875 times the 107.5 it was until 196). `_lensRide` 155 → 116.25 (1.875 times the 62 it was), in the same four places as 197. The clamps follow, as before. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 203, 18 November, "The glass a quarter smaller", `askedTest = 'button'`; `0.164.0+231`. |
| `DESIGN.md` | §8: its size and ride. |
| `tasks/BUILD203.md`, `CHANGELOG.md` | The brief; build 203. |
| `releases/prism-build-203.apk` | The build. |

## The glass

| | Until 196 | 197 to 202 | 203 |
|---|---|---|---|
| Size | 107.5 | 268.75 | 201.5625 points |
| Ride above the finger | 62 | 155 | 116.25 points |
| The finger under its edge | about 8 | about 21 | about 15 points |

It's the same glass: the same look, the same full quality, the same pill when it's put down.

**On a 411-point-wide phone:**
- It's 49% of the screen's width (65% in 197).
- Its middle can move between about 101 and 310 points across.
- Near the top it sits over the finger only in the top 250 points or so (320 in 197).

**GPU and memory** (by arithmetic, as in 197):
- Its area is about 56% of 197's, and 3.5 times that of the glass until 196.
- On the S26 that's about 530 × 530 pixels.
- Its backdrop pictures are about 1.1 MB each, against 2 MB in 197, so roughly 2.5 to 4.5 MB of the GPU's
  memory while it's out.
- Nothing is kept once it's home (197's note).

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 84 right, 1 wrong, 1 skipped, of 86 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 68 right, 3 wrong, of 71 (the usual 3, all "measured: no answer", Android-only)
```

**Every glass check is right:**
- brought out by a drag;
- put down on a card, and staying there;
- moved to another card;
- going home over nothing;
- a slower flick still the app list.

**"Carrying the glass over every card":** 109.8 ms of drawing per frame on average, in one run. That's
higher than 197's 96 and 98, though the glass is smaller. In the preview's software drawing every frame
costs about 90 to 110 ms whatever is on it, and runs differ by more than the glass's share. It says nothing
about the phone. Only the phone's long test can.

- **Analyser:** the same 4 old notes.

**Build 203:**
- `Prism build 203`, `0.164.0+231`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- **Its `libapp.so` has** "Prism build 203" and "The glass a quarter smaller".
- sha256 `c5efa3b5e732f2b0adc47163a608a67e9d436612606dda05a7ace6c143229706`, 18,960,842 bytes.
- Link: added once it is pushed and checked.

## Where I could be wrong

1. **None of it has run on a phone.**
2. **The preview's frame time can't show the change:** see above.

## On the phone

**What to look at:** drag up from Prism's button over Home's cards. The glass is about half the screen's
width, a quarter smaller than in 202, and still rides clear of the thumb.
