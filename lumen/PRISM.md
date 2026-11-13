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

## The kit: every element Prism is allowed to use

Keeping the list short keeps the app light, consistent and predictable. If a screen needs something
that is not here, the first question is whether one of these can do the job.

| # | Element | What it is for | Glass? |
|---|---|---|---|
| 1 | Card | Any block of content | No, solid |
| 2 | Main button (filled pill) | The one thing to do on a screen | No |
| 3 | Quiet button (outlined pill or text) | Everything else you can tap | No |
| 4 | Thumb dial | A number you nudge (kg, reps, seconds) | No |
| 5 | Ruler | A number you set from scratch (body weight) | No |
| 6 | Switch and segmented choice | On or off; one of a few | No |
| 7 | Tick circle | Done, skipped, not yet | No |
| 8 | Sheet | A quick action over the page | No, solid |
| 9 | Bar with riding lens | Moving between the four pages | Yes |
| 10 | The button, its blobs, and the carried lens | Acting from anywhere; explaining | Lens only |
| 11 | Floating pill (rest timer) | Something running in the background | Yes |
| 12 | Round button | One per page at most, top right | No, solid |

Glass is on three things (bar with its lens, the carried lens, the rest timer), all small and all floating. Nothing else may be glass.

## The back button

Back undoes the most recent thing that opened, one step per press:

| If this is showing | Back does this |
|---|---|
| A sheet (Log food, Weigh-in, Timer, Scan) | Closes the sheet |
| The settings sheet | Closes it |
| The lens, carried or put down | Sends it home to the bar |
| The blobs | Closes them |
| Train, Food or Progress, nothing open | Goes to Home |
| Home, nothing open | Leaves the app |

Every new element must say where it sits in this table before it is built.

## Testing

Prism records every frame under the scene that was showing. The round button on Home opens a sheet with
**Copy test report**; tapping the frame-rate readout does the same. Paste the result to whoever is tuning it.
The code is `lib/fit/diag.dart`.

**Run the test** does it all in one go: the app first drives itself through a fixed script under each glass
setting (`lib/fit/robot.dart` sends real touch events; the script is `_robot()` in `shell.dart`), then idles,
then asks a person to use it under each setting. Report rows are prefixed `auto` and `you`.

## Building it

```
ORG_GRADLE_PROJECT_fit=1 flutter build apk --release --target-platform android-arm64 -t lib/fit/main.dart
```

Without `ORG_GRADLE_PROJECT_fit` and `-t`, the same project builds Lumen. The code is in `lib/fit/`.

## Not in this first build

- The lens works on Home only; Train, Food and Progress do not offer themselves to it yet.
- Editing the blobs, the bar, or the home screen.
- The food sheet and the Food page keep separate lists; both change the calories on Home.
