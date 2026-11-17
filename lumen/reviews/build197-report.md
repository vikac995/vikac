# Build 197 report: a bigger magnifying glass

Brief: `tasks/BUILD197.md` (the review chat, the lead, 17 November, 12:21: the owner lifts the pause).
- 197 is new: the magnifying glass (the round lens that comes out of Prism's button and is carried over
  Home's cards) at about 2.5 times its diameter. Same lens, just bigger. Nothing else changes.
- Renumbered: 198 is the Sidekick's own app list (was 197); 199 the test's own store and 200 search,
  both still held.

**Only the preview has run it.**

## Files changed

| File | What changed |
|---|---|
| `lib/fit/shell.dart` | **The glass's size:** `_lensSize` 107.5 → 268.75 points. **Its ride above the finger:** `_lensRide`, 62 → 155, in the four places it is used (lifting off, carrying, picking it up again, the drop home). **The tests:** they aim the finger with `_fingerFor` (the ride under the card, kept on the screen) instead of a fixed 62. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 197, "A bigger magnifying glass", `askedTest = 'button'`; `0.158.0+225`. |
| `DESIGN.md` | §8: the carried lens's size and ride. |
| `tasks/BUILD197.md`, `CHANGELOG.md` | The brief; build 197. |
| `releases/prism-build-197.apk` | The build. |

## The glass

**Its size:** 268.75 points across, 2.5 times 107.5. The owner's "about 120" includes its shadow and bevel.

**It's the same glass**, with the same style:
- the full quality, whatever the setting;
- refraction 19, bevel 13, dispersion 0.16, magnify 1.2;
- the same morph into the action pill when it's put down on a card;
- it grows out of the button and drops back into it as before.

**Its ride above the finger: 155 points** (62 before), scaled with it. So the finger is about 21 points
under its lower edge (about 8 before), never over its middle.

**Kept fully on the screen.** As before, its centre stays half its size from the sides and the bottom,
and half its size plus 30 from the top.
- **On a 411-point-wide phone it's 65% of the screen's width.** Its centre can move only between about
  134 and 277 points across, so near a side it stops while the finger goes on.
- **Near the top it stops too.** With the finger in the top 320 points or so, it sits over the finger,
  as it did before in the top 140.

## Measured: the frame time while it's up (preview)

The long test's scene "carrying the glass over every card": drawing per frame, average/most, in ms.

| | run 1 | run 2 |
|---|---|---|
| **196, the 107.5-point glass** | 94.2 / 286.3 | 93.2 / 135.7 |
| **197, the 269-point glass** | 96.0 / 149.6 | 98.3 / 141.8 |

**About 2 to 5 ms more per frame on average, in the preview,** with "the most" within its noise (196's
first run had one slow frame).
- **What the preview is:** its picture is drawn in software, and every frame costs about 90 ms whatever
  is on it. So this shows the glass's extra cost is small next to the rest of a frame there.
- **What it isn't:** what the phone's GPU will do. See "Where I could be wrong".

**Also unchanged:** "picking the put-down glass up again" (88.8 and 100.9 before; 91.5 and 111.9 after), and
every glass check: brought out by a drag, put down on a card and staying there, moved to another card,
going home over nothing, and a slower flick still being the app list.

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 81 right, 1 wrong, 1 skipped, of 83 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only), twice
```

- **Analyser:** the same 4 old notes.

**Build 197:**
- `Prism build 197`, `0.158.0+225`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- **Its `libapp.so` has** "Prism build 197" and "A bigger magnifying glass".
- sha256 `e675bde0a040fb1dc8cfefb2a7cacf3cc670fef2cdf878b74a8e57860afc0788`, 18,878,922 bytes.
- Link: added once it is pushed and checked.

## Where I could be wrong

1. **None of it has run on a phone.**
2. **The GPU cost on the phone: up to about 6 times the glass's own.**
   - The full-quality glass is drawn with two backdrop passes over its own area: a blur, and the
     refraction shader that reads what's behind it. There's also a soft shadow round it.
   - All three grow with its area, which is 6.25 times what it was.
   - On the S26 (about 2.6 pixels a point) that's about 706 × 706 pixels instead of 282 × 282: 500,000
     pixels a frame instead of 80,000.
   - **The preview can't say what that costs on the phone's GPU.** Its software drawing hides it under
     the 90 ms every frame costs there.
   - **Where to look on the phone:** the long test's "carrying the glass over every card" row (its draw
     time and "late" frames), compared with 196's on the same phone. If it costs a refresh, the glass is
     the place to look.
3. **Memory while it's up: a few MB more, gone when it goes.**
   - Each backdrop pass needs a picture of the glass's area: about 2 MB at the new size, against 0.3 MB
     before.
   - With the passes and their copies, roughly 4 to 8 MB more of the GPU's memory, by arithmetic, not
     measured.
   - Nothing is kept once the glass is home.
4. **Near the edges it stops while the finger goes on,** and in the top 320 points or so it sits over the
   finger. The brief asked for it fully on the screen; this is the price at 269 points.
5. **High cards:** its centre can't go above about 164 points from the top. It decides which card it's
   over by its centre, so a card wholly above that can't be chosen with it. In the preview Home's cards
   all could be.

## On the phone

**What to look at:**
- Drag up from Prism's button and slide over Home's cards. The glass is much bigger, about two thirds of
  the screen's width, and it rides well above your thumb.
- Watch it near the sides and the top: it stays fully on the screen.
- Run the long test and compare "carrying the glass over every card" with 196's.
