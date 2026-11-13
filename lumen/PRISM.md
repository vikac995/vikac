# Prism

A fitness app prototype in the Lumen design. It is a second app built from this same project, so it shares
Lumen's glass, springs, haptics and controls. It installs next to Lumen (its id is `dev.lumen.prism`).
All data is made up and nothing is saved.

## What is in it

| Place | What it is | Lumen example it comes from |
|---|---|---|
| Bottom bar | A glass bar with four tabs and a lens that rides between them; slide along the bar and the lens follows | R01 Glass |
| Centre button | One flat colour; a tap splits it into five blobs on springs | R21, R51 |
| Home | Today's workout, calories left, weight, today's list | R26 Dashboard |
| Train | A workout in progress with thumb dials; the rest timer is a glass pill above the bar | R39, R23 |
| Food | The day's calories, macros, meals, water | R46 |
| Progress | A chart you can run a finger along, and bests | R45 |
| Quick actions | Log food, Weigh-in, Timer and Scan open as a glass sheet over the page | R19 Sheets |
| Settings | The round glass button on Home: dark or light, frame-rate readout, haptics, glass quality | |

## Where glass is used, and where it is not

Glass is only on things that float over content: the bar and its lens, the round button at the top of Home,
the rest timer, and the quick-action sheet. Cards, lists and buttons are solid, so text never sits on a moving
background. That is five glass surfaces at most on screen, usually two.

## Testing

Prism records every frame under the scene that was showing. The round button on Home opens a sheet with
**Copy test report**; tapping the frame-rate readout does the same. Paste the result to whoever is tuning it.
The code is `lib/fit/diag.dart`.

## Building it

```
ORG_GRADLE_PROJECT_fit=1 flutter build apk --release --target-platform android-arm64 -t lib/fit/main.dart
```

Without `ORG_GRADLE_PROJECT_fit` and `-t`, the same project builds Lumen. The code is in `lib/fit/`.

## Not in this first build

- The lens from R51 (drag the button to explain and act on things). The button only opens the blobs.
- Editing the blobs, the bar, or the home screen.
- The food sheet and the Food page keep separate lists; both change the calories on Home.
