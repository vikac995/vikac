# Lumen changelog

## Prism, build 19 (13 November 2026)

**File:** `releases/prism-build-19.apk`

Tighter, more liquid motion, from your notes on build 18.

- **The drop has no tail.** It appears small under your thumb (not above it), swells in the first stretch of the way, and travels home as one shape, pulled slightly long and thin by its own speed.
- **The landing is shorter and hits harder.** It arrives still moving, squashes more (about twice as much as before), and settles in roughly a third of the time.
- **The menu blobs shoot out faster**, and the gap between the leftmost and the rightmost is about half what it was (18 ms per blob instead of 38).

**What to look for**
- Does the drop appear exactly under your thumb?
- Landing: is the squash now enough, and is it over quickly enough? If it reads as a glitch rather than a hit, say so.
- Blobs: is the left-to-right order still just visible, or gone?

**Checked:** it compiles, passes analysis, and stills in my preview of the drop in flight.
**Not checked:** the motion. My preview cannot show it, and these are all timing changes. The numbers are my best judgement and may need another round.

## Prism, build 18 (13 November 2026)

**File:** `releases/prism-build-18.apk`

- **The blob menu opens real apps:** Claude, WhatsApp, Instagram, Facebook. Tap a blob and the app launches. If one is not installed, its blob shows the first letter and tapping it gives a dull thud.
- **Each blob takes its colour from the app's own icon, kept inside Prism's palette.** The app reads the icon, finds the colour it is mostly made of (white, black and grey do not count), keeps that hue, then holds how vivid and how bright it is to the same band as Prism's own blobs, so white on top reads equally on every one. An icon with no real colour becomes slate.
- **The picture on the blob** is the app's own one-colour outline in white, where the app supplies one (the same outline Android uses for themed icons). Otherwise the real icon is shown small in the middle.
- **Round button on Home, "Blobs open real apps"** switches back to Prism's fitness actions. The test switches to the fitness actions by itself while it runs, so the robot cannot open other apps, and switches back after.

**What to look for**
- Do all four blobs look like they belong together and to the rest of the app? Which, if any, looks off?
- Is each one still recognisable as its app at a glance?
- White outline or small real icon: tell me which apps got which, and which you prefer.

**Checked:** in my preview, with stand-in colours and letters: four blobs, colours in one family, tapping does not crash.
**Not checked:** everything that needs a phone: reading the real icons, the white outlines, the colour taken from the real icon, and launching. If a blob shows a letter although the app is installed, tell me which.

## Prism, build 17 (13 November 2026)

**File:** `releases/prism-build-17.apk`

Morphing animations, from your notes on build 16.

- **The drop no longer grows at the bottom.** That was a deliberate "pool" I added; it read as the button appearing twice. Removed. The drop now simply travels the whole way.
- **It starts nearer your finger and smaller.** The glass rides above the finger and is large; the drop used to inherit both. It now begins lower and at about three quarters of the size.
- **It lands like a droplet.** On arrival the button jiggles: wider, taller, wider, dying away. A faster arrival jiggles more.
- **The blob menu shoots out.** Blobs leave one after another, left to right. Each starts tiny, grows as it travels, stays tied to the button by a thread of its own colour that thins and snaps on arrival, and bounces back a little at its resting place.

**What to look for**
- Drop: is the starting point right now, or still too high? Is the jiggle the right amount, or too much or too little?
- Blobs: does the bounce at the top read as liquid, or as a glitch? Is one-after-another too slow when you are in a hurry?

**Checked:** stills in my preview: the menu opens with tiny blobs growing, and the drop starts lower and lands on the button.
**Not checked:** any of the motion. The jiggle and the threads I have not seen at all, only compiled.

## Prism, build 16 (13 November 2026)

**File:** `releases/prism-build-16.apk`

- **The lens comes home as a drop of colour, not as glass.** The moment you let go or dismiss it, the glass is gone. A flat blob in the colour it had (the card's colour if it was a pill, otherwise the button's orange) travels back to the bar, stretching along its path with a short tail. It shifts to the button's orange on the way, pours into a pool that grows where the button lives, the plus draws itself in, and the button lands with a small bounce.
- No glass, blur or shadow is drawn during the return, so those frames are as cheap as the app gets.

**What to look for**
- Does the drop read as one liquid shape, or can you see separate circles in the tail?
- Is the landing a clean hand-over to the button, or is there a visible pop in size or position?
- Speed: too slow, too fast, or right?
- Grab the button again while the drop is still flying: it should become the lens at once.

**Checked:** in my preview the shape, colour change and landing play as described.
**Not checked:** on a phone. My preview draws about seven frames a second, so I have seen stills of this animation, never the motion.

## Prism, build 15 (13 November 2026)

**File:** `releases/prism-build-15.apk`

- **New glass style: Auto, now the default.** The app starts on Original. While you use it, it watches its own frames in blocks of 480 (about four seconds of movement). If more than 15 % of a block is over budget, it switches the bar to Event (solid bar; lens and rest timer stay glass) and remembers that for next launch. It goes back up to Original only if there is clear headroom, and at most once, so it cannot flicker between the two.
- The settings row is now **Auto / Orig. / One / Frost / Event**. Choosing any of the four fixed styles turns Auto off. **Orig.** is the full revert.
- The top of the test report says which style is in use and how many times Auto stepped down.

**What to expect on your S26:** nothing visible. Your phone ran Original at 6.9 % over budget, well under the 15 % line, so Auto should stay on Original. If the bar ever turns solid by itself, the report's action list will say "auto: stepped down" with the percentage; send it to me.

**Not checked:** I cannot make a phone slow on demand, so the step-down has never actually fired. The 15 % line is my judgement from your numbers, not something tested on an S24. Auto does nothing during the test itself.

## Prism, build 14 (13 November 2026)

**File:** `releases/prism-build-14.apk`

- **Fixed: the lens waking cards on its way home** (from your recording). After you let go or dismiss it, the lens flies back to the bar as a plain button. It no longer highlights or explains the cards it passes over.

**What to look for:** park the lens on the workout card, tap elsewhere to dismiss it, and watch the Weight card as the lens passes: it should stay still.

**Not checked:** on a phone, and not in my preview either; this is a two-line change from reading your recording.

## Prism, build 13 (13 November 2026)

**File:** `releases/prism-build-13.apk`

Four glass styles to compare, switchable at any time. **Original is the default and is exactly how build 12 looked.**

Round button on Home, **Glass style**:

- **Original.** The bar and its riding lens are always glass.
- **One (one at a time).** Only one moving piece of glass at once. While you carry the lens the bar turns solid; while the bar's small lens slides between tabs it is a plain highlight and turns back to glass when it stops.
- **Frosted.** The bar still blurs what is behind it but no longer bends it: one drawing pass instead of two. The small lens and the carried lens are unchanged.
- **Event.** The bar is solid always. Only the carried lens and the rest timer are glass.

The test now runs: Full glass (Original), One at a time, Frosted, Event, No glass. Medium, Low and the lights were dropped from the test because your reports showed they differ by 0.2 ms or less; they are still in settings.

**To revert fully:** choose Original. Nothing else changed in this build, and every earlier build is still downloadable.

**What to look for**
- One: does the bar changing as you lift the lens read as a glitch or as intentional? Does the small lens popping back to glass after a tab switch catch your eye?
- Frosted: put Food or Progress behind the bar and scroll. Can you tell it from Original at all?
- Event: does the app still feel like itself?

**Checked:** in my preview each style renders as described, at rest and with the lens out.
**Not checked:** on a phone, and I have no S24. Whether any style is actually faster is exactly what the test will say. Tab switches and sheets, the biggest cost in your reports, are not fixed in this build.

## Prism, build 12 (13 November 2026)

**File:** `releases/prism-build-12.apk`

The test made more trustworthy, after comparing the robot's half with yours in the build 11 report.

- **The robot's finger now moves once per screen refresh** and ends scrolls with a flick, so lists coast as they do under a real finger. Before, it moved on its own timer, which left refreshes with nothing to draw and made scrolling look worse than it is.
- **"Late" is stricter.** A missed refresh counts only if a slow frame came just before it. Missed refreshes with no slow frame are no longer counted as stutter.
- **Each frame is charged to the right action.** Frame times reach the app in batches up to a second late; they are now matched to actions by their own timestamps instead of by arrival time.
- **A warm-up pass that is not recorded**, so one-off first-time costs no longer land on Full glass just because it runs first.
- **The robot covers more:** all four screens (arrive, flick down, flick back), ticking a set on Train, tabs a second time quickly, blobs twice, Weigh-in twice and Log food, the lens over every Home card twice.
- **New in the report:** a grid with one row per action and one column per setting, for the robot and for you, including how long the screen kept drawing after each action (battery).

**How to run it:** same as before. Round button on Home, **Run the test**. It now takes about 5 minutes: roughly 3.5 hands off, then 70 seconds of you.

**Checked:** in my preview the robot did every step under every setting and the grid filled in.
**Not checked:** on a phone. In particular the "kept drawing" times and the new late rule only mean something at real frame rates; my preview draws a frame in about 140 ms.

## Prism, build 11 (13 November 2026)

**File:** `releases/prism-build-11.apk`

The test now runs itself first, then hands over to you. One tap, one report.

- **Part 1, automatic (about a minute).** The app drives itself with the same touch events a finger sends: every tab, the blobs open and closed, the Weigh-in sheet opened and dismissed, Home scrolled down and back, and the lens carried over every card on Home. It repeats that exact script under each of the five glass settings, so every build is measured on identical actions.
- **Eight seconds hands off**, to check nothing draws while idle.
- **Part 2, you (14 seconds per setting).** As before, with the checklist in the banner. This is the real-finger data.
- **One report.** Rows starting `auto` are the robot, rows starting `you` are yours. The report appears by itself at the end.
- **Fixed: the dot left on the calorie ring** in Food when the value drops to zero (from your recording). The ring now fades out as it empties instead of leaving its rounded end behind.

**How to run it:** round button on Home, **Run the test**. Put the phone down while the banner says "Hands off". When it says "your turn", use the app until the report appears, tap **Copy report**, paste it to me.

**What to look for:** during part 1, the app should visibly move by itself. If it sits still or gets stuck with something open, tell me at which setting.

**Checked:** in my preview the robot switched tabs, opened the blobs and the sheet, scrolled and carried the lens under all five settings, and the report had both `auto` and `you` rows.
**Not checked:** on a real phone. Tap positions are computed from the layout, not hard-coded, but your screen is the first real one to run it. I also could not reproduce your zero-ring recording frame by frame; the fix is from reading the drawing code.

## Prism, build 10 (13 November 2026)

**File:** `releases/prism-build-10.apk`

The guided test and its report, improved from what the first two reports could not tell me.

- **A three-second countdown** before recording starts, so the first setting is not short-changed while the settings sheet closes.
- **A checklist in the banner.** Each setting should be tested on the same five things: switch tabs, open the blobs, carry the lens, open a sheet, scroll. The banner's second line lists what is still to do for the current setting and says "All covered" when done. Last time each setting saw different actions, so the settings were not strictly comparable.
- **A hands-off step at the end** (8 seconds). Nothing is touched and the report says how many frames were drawn. A screen left alone should draw nothing; anything more is a battery leak.
- **Battery level, heat and power saving**, read at the start and at the end. A hot phone or power saving slows drawing, which would otherwise look like a regression.
- **Compared with your last run.** The phone remembers the previous guided run; the next report shows late frames, over-budget frames and average draw time per setting next to the earlier values and names the build they came from.
- **First time against every time after.** Each line in "where it stutters" now shows the worst frame the first time the action happened and the worst on repeats. A slow first and fast repeats means a one-off warm-up, not something to redesign.
- **Why it was slow.** Each line says BUILD (working out what to show, which is my code) or DRAW (painting: glass, shadows, size).
- **Coverage section**: for each setting, which of the five things were missed.

The test now takes about 81 seconds: 3 to get ready, 5 settings of 14, and 8 hands off.

### What to test

Run the guided test and follow the banner's "Still to do" line under each setting. This run stores the baseline; the one after it will show the comparison.

### Not checked

- Run in the Linux preview at 2 seconds a step: the countdown, checklist, hands-off step, coverage and first/later columns all appeared. Battery and heat need the phone, and showed blank there. The comparison needs two runs on the same device and was not seen.

## Prism, build 9 (13 November 2026)

**File:** `releases/prism-build-9.apk`

From the owner's guided-test report (Galaxy S26, 120 Hz). Frames that reached the screen late: Full glass 1.9 %, Medium 1.1 %, Low 0.9 %, No glass 0.5 %. The lens over Home's cards and tab changes led the list.

- **The lens no longer rebuilds the whole app when it crosses onto a card.** Each crossing redid every page, the bar and the blobs; that is the "BUILD 8 to 10 ms" in the slow frames. Now only the lens layer changes.
- **Pages are their own layer.** Sliding a page in on a tab change moves a finished picture; before, the page was repainted on every frame of the slide.
- **The round button on Home is solid.** As glass it scrolled with the page, so its backdrop changed every frame and Home ran three pieces of glass where other pages ran two. Home was the slowest screen (18.9 % of frames over budget on Full).
- **The report ranks by late frames**, the ones a person can see, and says so at the top. "Over budget" stays as a second column.

### What to test

Run the guided test again the same way. Compare with build 8: the "lens on ..." lines and the "tab ..." lines should have fewer late frames, and Home on Full glass should be closer to the other pages.

### Not checked

- Nothing here was measured; these are three causes read from the report. The next report is the check.

## Lumen build 23 (13 November 2026)

**File:** `releases/lumen-build-23.apk`

### R56 Widget stacks: a second stack, and editing

- **Two stacks.** The first turns up and down as before. A new one below it turns left and right, with the next widgets peeking out on the right and the dots underneath.
- **Hold a stack to edit it.** It unfolds in place into a list, one row per widget in order:
  - drag a row's handle to reorder (the first row is the widget on top);
  - the minus removes a widget;
  - "Add" chips put in any widget that is not in the stack yet;
  - a switch for "Turn by itself through the day";
  - Done folds it back into a stack.
- A stack with nothing in it shows "Empty stack. Tap to add widgets."
- The four time-of-day buttons from build 21 are gone; the switch now lives in the editor.

### What to test

1. Swipe each stack. Is sideways or up-and-down the more natural way to turn a stack on a page that itself scrolls up and down?
2. Hold a stack, reorder, remove one, add one, Done. The stack should show the new order.
3. Remove everything from a stack.

### Not checked

- Linux preview only: one sideways swipe, and opening the editor. Reordering, removing, adding and the empty stack were not tried.

## Lumen build 22 and Prism build 8 (13 November 2026)

**Files:** `releases/lumen-build-22.apk`, `releases/prism-build-8.apk`

### Lumen 22: R55 Morphing drawer shows your real apps

- On the phone the drawer now lists the apps actually installed, in alphabetical order, with their real icons and names. Each icon is cut to the morphing outline, so the outline still changes shape while one icon fades into the next. Tap an icon to open that app.
- A "Real / Made up" button switches back to the 72 drawn ones.
- Lumen asks Android which apps can be opened from a home screen. It needs no permission prompt for that; nothing leaves the phone.

### Prism 8: a guided test, and a report that points at the cause

- **Guided test.** Round button on Home, then "Run the guided test (70 s)". Keep using the app. Every 14 seconds it switches setting by itself: Full glass, Medium glass, Low glass, No glass, Full glass with background lights. A small blue banner says which one is running and counts down. At the end it puts your settings back and shows the report with a Copy button.
- **The report is ordered by what to fix.**
  1. *By setting*: frames, the share over budget, the share late, average build and draw time, worst frame.
  2. *Where it stutters, worst first*: each line is "setting | screen > action" (for example "Full glass | home > sheet Weigh-in") with how many times it happened, frames over budget, the worst frame, and average build and draw time.
  3. *By screen* under each setting, with frames per second and the 95th percentile.
  4. *Slow frames*: each one with the time, how long it took, whether BUILD (working out what to show) or DRAW (painting it) was the slower half, the setting, the screen and the action it followed.
- **The recorder costs almost nothing.** Per frame it adds a few numbers to two running totals; it makes no text and allocates nothing unless a frame was actually slow. The banner updates once a second.

### What to test

1. Lumen R55 with your real apps: do icons load, does tapping open the app, and is the morph still pleasant with real icons?
2. Prism: run the guided test while doing a bit of everything (tabs, blobs, each sheet, lens over the cards, scrolling), then send the report.

### Not checked

- Real apps cannot be tried in the Linux preview at all: listing, icons and opening are untested.
- The guided test was run in the preview at 2 seconds a step; the report came out right and the settings were restored.

## Lumen, build 21 (13 November 2026)

Two experiments in a new home section, "Launcher ideas" (56 examples in total). Prism is unchanged (build 7).

**Files:** `releases/lumen-build-21.apk`

- **R55 Morphing drawer.** An app drawer that does not scroll. The grid of 24 stays where it is; swipe up or down and each icon turns into the one a page further on. Its outline changes shape, its colour blends, the picture and the name swap. The change runs as a wave, top row first, and follows the finger; let go and it settles on the nearest page. One tick per row that turns over. 72 made-up apps in alphabetical order, with a marker on the right and "A to H · 1 to 24 of 72" underneath.
- **R56 Widget stack.** Several widgets sharing one place. Swipe up or down on the stack to turn to the next; the edges of the others show underneath, and dots show how many there are. "Turn by itself" lets the stack turn to what fits the time of day (the four buttons stand in for the clock).

### What to test

1. R55: drag slowly and watch one row. Then flick. Is it delightful, or does it make an app harder to find than scrolling would? That is the real question for this idea.
2. R55: the frame-rate readout during a drag. All 24 icons redraw every frame.
3. R56: swipe through the four widgets; try the times of day.

### Not checked

- Linux preview only: one drag on each. Flicks, haptics and frame rate are untested.

## Prism, build 7 (13 November 2026)

**File:** `releases/prism-build-7.apk`

- **Weigh-in uses the big ruler** from Lumen R23, with the large number above it, in place of the small dial.
- **Sheets are solid, not glass.** The owner reported that opening the weigh-in sheet is costly. It blurred and bent a third of the screen. Glass is now only on the bar, its lens, the carried lens, the rest timer and the round button.
- **The back button is handled.** It closes whatever opened last (sheet, then lens, then blobs), then goes to Home, and only leaves the app from Home with nothing open. The rules are a table in `PRISM.md`.
- **The report says which action causes stutters.** Two new parts:
  - *Actions, worst first*: every action (each tab, blobs, each sheet, lens lifted, lens on a card, scroll, set tick, food add, habit, back) with how many times it happened, how many frames followed it, how many of those ran over budget, the worst single frame and the average.
  - *Slow frames*: each frame that took more than one and a half refreshes, with the time, how long it took split into build and draw, what was on screen, and the action it followed.
- **`PRISM.md` now lists the kit**: the twelve elements Prism may use and which four are glass.

### What to test

1. Start over, then do each thing a few times: switch tabs, open and close the blobs, open each sheet, carry the lens over the cards, scroll, press back in each state. Copy the report.
2. Back button: with a sheet open, with the blobs open, with the lens put down, on Train, on Home.

### Not checked

- Linux preview only: the weigh-in sheet with the ruler, and the new report sections (they filled in correctly). The back button cannot be pressed in the preview, so its behaviour is untested.

## Prism, build 6 (13 November 2026)

**File:** `releases/prism-build-6.apk`

- **The lens is in Prism.** Drag the button and it lifts off the bar as the magnifying glass from Lumen R51. Home's four cards swell as it approaches and a card names and explains each one.
- **Over something you can act on, the glass becomes a pill with real actions.** Today's workout: Continue (goes to Train). Calories: Log food (opens the food sheet). Weight: Log weight (opens the weigh-in sheet). Let go and the pill stays; tap it to do the thing. Today's list only explains, so the glass stays round there and goes home when you let go.
- A tap on the button still opens the five blobs.
- The test report now has a `+lens` scene and logs which card the lens was on and which action was used.

Any page can offer itself to the lens by wrapping a piece in `LensTarget` (`lib/fit/lens.dart`): a title, one sentence, a colour, and optionally actions. Only Home does so far.

### What to test

1. Drag the button over each Home card. Does each explain itself and, where it should, turn into a pill?
2. Let go on Weight and tap "Log weight"; save a weight.
3. Copy a test report after using the lens for a while: the `home+lens` row shows what the glass costs while it is carried.

### Not checked

- Only the Linux preview: the lens over Weight, the pill, and tapping it to open the weigh-in sheet. The other three cards, and letting go over empty space, were not tried.
- Frame rate with the lens carried. It is the largest piece of refracting glass in the app.

## Prism, build 5 (13 November 2026)

**File:** `releases/prism-build-5.apk`

From the owner's test report on a Galaxy S26 (120 Hz, 8.3 ms per frame): drawing averaged 3.1 to 4.5 ms, 2 to 5 % of frames were late, each screen had a rare spike of 33 to 58 ms, and the app drew about 10,800 frames in 2 h 43 min.

- **Battery: the workout clock no longer redraws a page nobody is looking at.** It redrew the whole Train page once a second on every tab. It still keeps time, but only redraws while Train is showing.
- **Tab changes are lighter.** The page used to fade in, which makes the phone draw the whole page into a separate layer first; this is the likely source of the 33 to 58 ms spikes. It now only slides 14 px.
- **The report says more.** Per scene: how long it was showing, frames per second, and late frames as a percentage. A new "battery" line gives frames per second overall and how much of the time the screen was completely still.

### What to test

1. Start over, use the app for a minute, copy the report. The worst "draw max" on tab changes should be well under 33 ms.
2. Leave Prism open on Home for a few minutes without touching it, then copy: Home should show almost no new frames.

## Prism, build 4 (13 November 2026)

**File:** `releases/prism-build-4.apk`

- **Plain background by default.** The owner's recordings of build 3 showed 119 to 120 frames a second most of the time, with dips to about 101 to 116. The coloured lights are now off unless you turn on "Background lights" in the settings sheet; the background is one flat colour, the cheapest thing a phone can draw.
- **Glass steps down by itself.** On "Auto", if frames are being missed, the glass drops from Full to Medium to Low instead of dropping frames. This existed in Lumen but was never switched on in Prism.
- **A test report you can copy.** Prism now records every frame and files it under what was on screen: `home`, `train`, `train+rest`, `food`, `progress`, with `+blobs` or `+sheet` when those are open. Two ways to copy it:
  - the round button on Home, then **Copy test report**; or
  - with the frame-rate readout on, **tap the readout**.
  The report has the phone model, Android version, chip, screen and refresh rate, the glass setting and what it is actually running at, and for each scene: frames drawn, frames that arrived late, and the time spent building and drawing them (average, 95th percentile, worst). It ends with the last sixty things you did, with times. **Start over** clears it.

### How to use it

1. Open the settings sheet and tap Start over.
2. Use the app as you normally would for a minute: switch tabs, scroll, open the blobs, tick a set.
3. Copy the report and paste it to me.

### Not checked

- The report was read back in the Linux preview and has the right shape. The phone model line needs the Android side, so it showed "unknown device" there; on the phone it should name the device.
- Whether the plain background removes the remaining dips.

## Prism, build 3 (13 November 2026)

**File:** `releases/prism-build-3.apk`

The made-up numbers now agree with each other:

- **Workout order.** Home crossed out bench press yet said "Continue with bench press", and Train called bench press exercise 2. Now: 1) Overhead press is done, 2) Bench press is next, "1 of 5 done".
- **Estimated best.** Progress said 80 kg for one rep while the heaviest set was 80 × 8, which is about 100 kg. Bench is now 100, squat 130 (from 110 × 6), deadlift 150 (from 130 × 5).
- **Period switch.** Month, 3 months and Year changed today's best. Now today's best stays put and only the history behind it changes.
- **Bests per lift.** Squat and deadlift showed bench's bests; each lift has its own now.
- **Food in one place.** The Food page and the quick "Log food" sheet kept separate lists. Both now add to the same meals, so Home, Food and the sheet always agree. "Burned 320", which no total used, is gone.

## Prism, build 2 (13 November 2026)

**File:** `releases/prism-build-2.apk`

From the owner's screen recordings of build 1:

- **Frame rate.** Build 1 ran at about 65 frames a second on a 120 Hz screen whenever anything moved (and about 80 with glass off), so the glass was not the main cost. The likely cause was the wallpaper: each soft light was about a hundred see-through circles, repainted every frame. It is now drawn once, at a quarter of the screen size, and shown stretched. Not measured on the phone yet.
- **Stripes in the wallpaper** are gone (same change), and it is a little darker.
- **The clock and the page title collided** when scrolling. A soft fade now sits under the status bar.
- **"KCAL LEFT" read wrong past the goal.** It now says "KCAL OVER" in red.

## Prism, build 1 (13 November 2026)

A new, separate app: **Prism**, a fitness app prototype in the Lumen design. It installs next to Lumen. Lumen itself is unchanged (still build 20). See `PRISM.md`.

**Files:** `releases/prism-build-1.apk`, `releases/prism-source-build-1.zip` (the whole project: Lumen and Prism share their code)

- **A glass bar with a riding lens.** Four tabs (Home, Train, Food, Progress) in one piece of glass. A lens sits on the current tab and slides to the next with a stretch; a tab brightens as the lens reaches it. Slide a finger along the bar and the lens follows; let go and it settles on the nearest tab.
- **The button in the middle** is one flat colour. A tap splits it into five blobs on springs: Workout (goes to Train), Log food, Scan, Weigh-in, Timer.
- **Quick actions open as a glass sheet** over whatever page you are on. Log food lists three recent foods, one tap each. Weigh-in is a thumb dial and Save. Both change the numbers on Home.
- **Home:** today's workout with its first exercises listed, calories left, weight, and today's list with done or skip.
- **Train:** the workout-in-progress screen with thumb dials. Ticking a set brings up the rest timer as a glass pill floating above the bar.
- **Food** and **Progress:** the day's food, and a chart you can run a finger along.
- **Glass is used sparingly:** only on things that float (bar, lens, the round button on Home, rest timer, sheet). Content is solid.
- The frame-rate readout is off by default; turn it on from the round button at the top of Home.

### What to test on the phone

1. The bar: tap between tabs and watch the lens travel. Then slide a finger along the bar.
2. Does the glass read as glass over the wallpaper and over the cards as you scroll Home under the bar?
3. Tap the button, pick Weigh-in, turn the dial, save. Home should show the new weight and tick "Morning weigh-in".
4. On Train, tick a set. The rest timer should rise above the bar as glass.
5. Turn on the frame-rate readout (round button on Home) and scroll each page.
6. Light mode, from the same sheet.

### Not checked

- Only the Linux preview (mouse, software rendering). I saw all four pages, the lens on each tab, the blobs, the food sheet, and the rest timer. Not tried: sliding along the bar, the weigh-in and timer sheets, the settings sheet, light mode, done and skip on the list.
- How the glass looks on the phone, frame rate, haptics.
- Not in this build: the lens from R51, and any editing.

## Build 20 (13 November 2026)

Three new examples (54 in total) and one fix. Nothing was removed.

**Files:** `releases/lumen-build-20.apk`, `releases/lumen-source-build-20.zip`

### Fixed

- **R47 Demo video: the loop never played.** The clock that drives it was created but never started, so the figure stood still and the cue never changed. My mistake, present since build 15; it now runs.

### New: R52 Lens with blobs (in "The centre button")

A variation on R51, kept separate so both can be compared. Drag the button onto a widget and rest there for 0.3 s: that widget's actions bud out of the glass as blobs on springs, the same kind the button makes. The glass then holds still and the point above your thumb picks: slide onto a blob (it swells, with a tick) and let go to run it. Pull well away and the blobs fold back and the glass follows you again. Over things with no actions it only explains, as in R51.

### New: a "Play" section with two small games, drawn from scratch

Both use a creature I drew in code (a round body, eyes that look around, a mouth, a tuft). No images, no borrowed characters.

- **R53 Treat toss.** A catching game where nothing is captured. A shy creature hops about; you flick a treat upward so it arrives where the creature is. It counts one heart; land it while the creature is mid-jump, mouth open, and it counts two ("Perfect!"). Five hearts and it trusts you: it comes close, smiles, confetti. "Find another" brings the next of four.
- **R54 Card pack.** Swipe across the top of a foil pack to tear it (it ticks as the foil gives). The cards rise out and the pack falls away. Tap a card to turn it over, tap again to keep it; kept cards line up at the bottom. The rim of the stack glows in the colour of the rarity that is coming, the best card is always last, better cards get a moving band of light, and Epic or Legendary gets confetti. Five cards a pack, always at least one Rare.

### What to test on the phone

1. R53: is the flick strength natural? I tuned it by arithmetic, not by hand: a medium upward flick should land at the creature's height. Tell me if treats fall short or sail over.
2. R53: can you time a throw for the jump? Is "two hearts for mid-jump" readable without the instructions?
3. R54: does tearing feel like tearing? Does the glow before a good card build anticipation or spoil the surprise?
4. R52 against R51: which way of getting to a widget's actions do you prefer?
5. R47: the figure should now be moving.

### Not checked

- Only the Linux preview (mouse, software rendering). I saw: the creature hopping and opening its mouth; the pack tearing, cards rising, a card turning over; R52's blobs appearing, one being picked and run.
- **I could not make a throw register with the mouse**, so in R53 the flight, the catch, the hearts and the win are untested. This is the least verified thing in the build.
- Not tried: keeping all five cards and "Open another"; the confetti; R52's fold-back when pulling away.
- Haptics and frame rate throughout. Both games redraw every frame while open.

## Build 19 (13 November 2026)

**Files:** `releases/lumen-build-19.apk`, `releases/lumen-source-build-19.zip`

### Changed: R51 Button and lens, the lens changes shape when there is something to do

The lens now says what kind of thing it is over by its own shape, before you read anything.

- **Round and clear: just looking.** Over something that only has an explanation (the four bar spots, the blobs) it is the round magnifying glass, as before.
- **A coloured pill: something to do.** Over a widget with actions the glass stretches sideways into a pill, takes the widget's colour, stops magnifying, and the actions are written inside it: "Log weight | History". There is a second, firmer tick as it changes. Moving off the widget lets it spring back to round.
- **Let go on a pill** and it stays where it is. It is now the buttons: tap one half to run that action. Tap anywhere else and it flows back into the round button on the bar. You can also drag it away again.
- The card above the lens is now only the name and the sentence; the buttons that were in the card in build 18 are gone, because the lens carries them.

Confirmed on the phone by the owner: the picture inside the glass is the right way up (it was upside down only in my preview).

### What to test on the phone

1. Drag from a bar spot (round) up onto a widget (pill) and back. Is the change of shape readable at a glance? Is the spring on the stretch right, or too lively?
2. Let go on the pill and tap one half. Is it obvious the pill is now two buttons?
3. Kcal left has two actions, Weigh-in has one: compare the wide and the narrow pill.
4. Sweep quickly across all five widgets: the pill changes colour and words each time. Too busy?

### Not checked

- Only the Linux preview (mouse). I tried: round over a bar spot, pill over Weight, let go, tap "Log weight". Not tried: dragging the pill away after putting it down, the one-action pills, quick sweeps.
- Haptics and frame rate. The pill is a wider piece of glass than the round lens, so if frames are missed anywhere it will be while the pill is showing.

## Build 18 (13 November 2026)

**Files:** `releases/lumen-build-18.apk`, `releases/lumen-source-build-18.zip`

### Changed: R51 Button and lens, the lens can be put down

The lens now has two outcomes when you let go, depending on what it is over.

- **Something you can act on** (the five widgets). While you pass over it, the card shows its actions as outlined buttons and the line "Let go here to use these". Let go, and the lens stays where it is as glass, settles onto the widget, and the card stays open with the buttons filled in and pressable. Kcal left: Log food, Scan. Weight: Log weight, History. Weigh-in: Log now. Protein shake: Add to today. Today's list: Add a habit.
- **Something that only has an explanation** (the four bar spots, the blobs), or empty space. Nothing changes: the card is information only, and letting go sends the lens home.

While the lens is put down:

- Tap a button on the card: the action opens as a small window and the lens goes home.
- Tap the lens, or anywhere else: the lens goes home.
- Drag the lens: you pick it up from where it is and carry on exploring.

### What to test on the phone

1. Drag onto the Weight widget and let go. Does the lens staying put feel deliberate, or like it got stuck?
2. Are the outlined-then-filled buttons enough to tell "passing over" from "put down"?
3. Put it down, then pick it up again from where it sits and move to another widget.
4. Let go over a bar spot or a blob: it should go home as before.
5. Still open from build 17: is the picture inside the glass the right way up?

### Not checked

- Only the Linux preview (mouse). I tried: hover, put down, press an action. I did not try picking the lens up again from where it was put down, or tapping it to send it home; those are untested.
- Haptics, frame rate, and whether the thumb covers the card's buttons at the moment you let go.

## Build 17.1 (13 November 2026)

**File:** `releases/lumen-build-17.1.apk`

- R51 Button and lens: the magnifying glass is 12 % larger (96 to 107.5 across). Nothing else changed; the distance at which things react and the height it rides above the thumb are the same.

## Build 17 (13 November 2026)

One new example at the top of "The centre button": R51, the button revised. R50 (the version built from the brief) is kept below it. 51 examples in total.

**Files:** `releases/lumen-build-17.apk`, `releases/lumen-source-build-17.zip`

### New: R51 Button and lens

One button, two jobs.

- **Tap.** The button stays one flat colour. It splits into five solid coloured blobs on an arc, the design from R21, now with the spring mechanics: each blob has its own spring, stretches along its flight, goes slightly past its place and settles; the middle one leaves first and each step outward starts 14 ms later; the button recoils. Closing is quick and does not bounce. Tap a blob to run it.
- **Drag.** After 10 px of movement the button lifts off the bar and becomes glass: the same refracting, magnifying glass as room 1. It rides 62 px above the thumb so the thumb does not hide it, and leaves an empty ring on the bar where it lives.
- **It explains as it goes.** Everything on screen reacts to how close the glass is, continuously: a widget starts to swell and lift from 64 px away and is fully raised when the glass is on it. Once the glass is properly over something, a card appears beside it with its name and one sentence about what it does, with a tick. Move on and the card changes; nothing waits for you to let go. It works on the five widgets, the four bar spots, and the blobs when they are open (tap first, then drag).
- **Let go** and the glass springs home and is a flat button again.

### What to test on the phone

1. Tap: do the blobs feel right now? This is the "Balanced" spring from R50 (stiffness 950, damping 0.62).
2. Drag the button slowly toward the Weight widget and watch it swell before you arrive. Is 64 px the right distance, or should things react sooner or later?
3. Sweep across several widgets quickly. Do the cards keep up, and is one tick per thing right or too much?
4. Tap to open the blobs, then drag the button over a blob.
5. **Look inside the glass.** In my preview the picture inside it is upside down. I believe that comes from the graphics mode my preview uses, which your phone does not, but I cannot confirm it. If the magnified picture is upside down on the phone, tell me; it is a one-line fix.
6. The frame-rate readout while dragging.

### Not checked

- Only the Linux preview (software rendering, mouse, about 15 frames a second). Not checked: how the glass looks on the phone, whether the magnified picture is the right way up, frame rate while dragging, haptics, and whether a thumb covers the explanation card near the top of the screen.
- R51 has no editing; R50 shows that.

## Build 16 (13 November 2026)

One new example, in its own home section "The centre button": my suggestion for the contextual button, built from the brief and from the current `flude_menu.dart` / `glass_button.dart`. 50 examples in total. Nothing was removed.

**Files:** `releases/lumen-build-16.apk`, `releases/lumen-source-build-16.zip`

### New: R50 The button

From the brief:

- One tap and the button splits into a single row of up to five blobs. No second layer, no folders.
- A blob can be an app, a Gym Buddy screen or a quick action. An app keeps its own icon, set behind the glass, and the glass takes a light tint of the icon's colour. A quick action is solid tinted glass in its category's colour (all Food actions are orange).
- Two spots on each side of the button in the bottom bar.
- Editing in place: hold the button. A pencil appears on it; every blob gets a minus and a pencil; an empty "plus" blob appears in the rightmost free slot while there are fewer than five. Tapping a blob opens "What should it do?" with Quick actions, Gym Buddy screens and Apps.
- A quick action opens as a small window over the home screen. An app or a screen grows out of its blob.

Motion (the "Springs" mechanics):

- Every blob has its own spring. It leaves the button stretched along its line of flight, goes slightly past its place and settles. The middle blob leaves first; each step outward starts 14 ms later. The button recoils as it fires. Closing is faster and does not bounce.
- Press the button, slide to a blob and let go: one movement. The blob under the thumb swells and its neighbours lean away from it, with a tick as you cross each one.
- A **Motion** switch at the top compares three tunings: Snappy (stiffness 1500, damping 0.92), Balanced (950, 0.62) and Bouncy (520, 0.45). Tell me which one, or where between two.

My additions (not in the brief; say if you want them out):

- **A suggestion pill** between the button and the row: one action that fits the moment (Morning: weigh-in; Workout: finish set 3; Lunch: log lunch). It is the largest target and the nearest to the thumb. The **Situation** switch at the top changes it; "Off" shows the button exactly as briefed.
- **A ring on the button itself** while a rest timer runs, readable without opening anything.
- **A short label under each blob.** The brief asks for the same icon for actions of one category; with identical icons, Scan and Quick log could not be told apart, so I kept one colour per category and a distinct glyph per action.

### What to test on the phone

1. Tap the button a few times in each Motion setting. Which one feels right for something used all day?
2. Press, slide to a blob, let go. Can you do it without looking? Do the ticks help?
3. Is the suggestion pill useful or in the way? Switch Situation to compare, and to Off.
4. Hold the button to edit. Remove one, add one with the plus, change one.
5. Watch the frame-rate readout while opening and closing quickly, many times.

### Not checked

- Only the Linux preview (software rendering, mouse), which runs at about 15 frames a second: I could confirm positions, order and that everything responds, not how the springs look or feel at 120 Hz. The stretch in flight is the part I could least see.
- The glass here is a single blurred layer cut to the shape of the blobs, not the refracting glass from room 1; that was a choice for speed. If it looks flat on the phone, say so.
- Haptics.

## Build 15 (13 November 2026)

A new home section, "During a workout", with three proposals for the hard parts of a training screen (49 examples in total). Nothing was removed.

**Files:** `releases/lumen-build-15.apk`, `releases/lumen-source-build-15.zip`

### New

- **R47 Demo video.** A demo clip that never takes over the screen. It has three sizes: a small loop beside the exercise name; grown in place (tap it) with a coaching cue, 1× / 0.5× speed, a scrub bar and tap-to-pause, while the sets stay visible underneath; and a floating bubble you can drag to any corner. Ticking a set while it is large shrinks it to the bubble by itself. The clip is a drawn figure, not a real video: Lumen ships no footage.
- **R48 Swap.** "Swap" on the exercise opens a sheet of four alternatives. Three reasons at the top (Equipment busy, Discomfort, Variety) re-rank the list and change the one-line reason under each; the top one is marked Best fit. Picking one turns the card over with your three sets kept and the weight adjusted. Only then does it ask "Just today" or "Every time", with Undo.
- **R49 Edit mid-workout.** No edit mode. Tap a set's badge to step through normal, warm-up (W), drop set (D) and to failure (F); "Add a set like the last"; a minus removes one. In "Up next": drag a handle to reorder, the arrow skips an exercise for today (and brings it back), and the chain between two rows links them into a superset, drawn as a bracket round both. Reordering clears supersets.

### What to test on the phone

1. R47: tap the loop, then tick set 1. Does the video stepping aside by itself feel helpful or presumptuous? Drag the bubble and throw it toward a corner.
2. R47: slide along the bar at the bottom of the large video to step through the movement.
3. R48: open Swap and switch between the three reasons; the order should change. Pick one and watch the card turn. Is asking "today or every time" afterwards the right moment?
4. R49: tap the set badges; tap a chain; drag a handle (the page should not scroll while dragging).

### Not checked

- Only the Linux preview (software rendering, mouse). Haptics, real frame rate and feel were not checked, in particular throwing the video bubble and the card turning over.
- A real video would add loading, buffering and battery cost that a drawn loop does not have.

## Build 14 (13 November 2026)

Four more examples at the end of "More patterns" (46 in total). Nothing was removed.

**Files:** `releases/lumen-build-14.apk`, `releases/lumen-source-build-14.zip`

### New

- **R43 Wheels.** Wheel pickers for a rest duration, a time of day (the wheels loop round) and a body weight split into whole kilos and tenths. Each step ticks and the wheel snaps to a value.
- **R44 Plates.** A plate calculator. Dial a weight and a drawn barbell loads itself with colour-coded plates, with "Each side: 25 + 5 + 1.25" in words underneath. Bar of 20, 15 or 10 kg.
- **R45 Progress screen.** A complete progress screen: chips to pick the lift, one headline number with its change, a line chart you can run a finger along (the headline follows your finger, one tick per point), a Month / 3 months / Year switch that reshapes the line, and bests as plain rows. Tagged R45.1 to R45.4. Data is made up.
- **R46 Nutrition screen.** A complete food day: a ring with calories left (turns red and says "over" past the goal), three macro bars, meals where one tap on plus adds the usual item, and eight water glasses. Tagged R46.1 to R46.4. Data is made up.

### What to test on the phone

1. R43: flick a wheel and let it coast. It should tick per step and settle exactly on a value. Do the ticks keep up when it spins fast, or turn into a buzz?
2. R45: slide a finger along the chart. The big number should follow without lag. The page should not scroll sideways or fight you; vertical scrolling from the chart should still work.
3. R45: switch lift and period; watch the line reshape and the frame-rate readout.
4. R46: tap plus on Dinner several times until the ring goes over the goal.
5. R44: drag the dial quickly; plates should pop on and off without flicker.

### Known rough edge

- Rolling numbers that start with a 1 (for example "1 160 kcal left") show a small gap after the 1, because every digit gets the same width so the number does not wobble while rolling.

### Not checked

- Only the Linux preview (software rendering, mouse). Haptics, real frame rate and feel were not checked. Wheel flicks in particular behave differently under a finger.

## Build 13 (13 November 2026)

Three more examples at the end of "More patterns" (42 in total). Includes the 12.1 fixes. Nothing was removed.

**Files:** `releases/lumen-build-13.apk`, `releases/lumen-source-build-13.zip`

### New

- **R40 Navigation.** Three bottom bars for the same four places, side by side: (A) labels with one pill that travels between tabs; (B) a floating bar with one main action in the middle; (C) a bar where only the selected tab opens its name.
- **R41 Reorder.** Editing a list by hand. Drag a row by the handle on its right; the others spring out of the way with a tick per position. Swipe a row left to remove it: red appears underneath, a tick marks the point of no return, and an Undo row replaces any "Are you sure?" question.
- **R42 Summary screen.** The screen after the last set: a tick that lands first, four numbers that count up once, the one special thing today (a personal best), a one-tap "How did it feel?", and Share plus Done. Tap the tick to replay the entrance. Pieces tagged R42.1 to R42.5. Data is made up.

### What to test on the phone

1. R41: drag a row by its handle up and down the list. Does it stay under your thumb, and do the others move aside without jumping? The page should not scroll while you drag a handle.
2. R41: swipe a row left slowly; you should feel one tick where letting go will remove it. Then Undo.
3. R40: tap through the tabs of A, B and C. Which selection movement do you prefer? That is the answer I need for the fitness app.
4. R42: tap the tick to replay. Thud, then the page rises in order, then the numbers count.
5. The sun/moon in the top right corner, and a two-finger tap anywhere, on any screen.

### Not checked

- Only the Linux preview (software rendering, mouse). Haptics, real frame rate, feel, and the two-finger tap were not checked.

## Build 12.1 (13 November 2026)

**File:** `releases/lumen-build-12.1.apk`

- **Fixed: cards repeating on the home screen.** Since build 11, Foundations also listed the first four Patterns cards and Patterns also listed the first four Screens cards. My mistake when adding the new section; each example is now listed once.
- **New: quick light/dark switch on every screen.** A small sun or moon in the top right corner, level with the frame-rate readout. A tap with two fingers together anywhere on the screen does the same. The two-finger tap could not be tried in the preview (mouse only).

## Build 12 (13 November 2026)

Four more examples at the end of "More patterns". Nothing was removed or changed elsewhere.

**Files:** `releases/lumen-build-12.apk`, `releases/lumen-source-build-12.zip`

### New

- **R36 Theme lab.** One small screen restyled live: six accents, corner radius, three spacings, light or dark, and whether the background borrows a little of the accent. The line under the preview states the exact values (for example "accent #9B6BFF · corner 23 · gap 12 · dark, tinted"), so a screenshot carries the recipe.
- **R37 Notifications.** Five ways for an app to speak up, quietest first: a badge; a bottom message with Undo whose background drains as the time runs out; a banner from the top (swipe up to dismiss, or it leaves after four seconds); a stack of three that unfolds on tap; and a polite request before the system permission dialog.
- **R38 Calendar.** History as a month. Dots mark days with a session, today has a ring, one highlight travels between days, the month changes by swipe or arrows, and the day's summary sits underneath. Future days and future months cannot be picked (the month bumps back with a thud).
- **R39 Workout screen.** A complete workout-in-progress screen. Progress through the session and elapsed time; last time's numbers as a hint; set rows with the kg and reps dials; one tap finishes a set; the rest timer then starts by itself as a floating pill (+15 s, Skip); when every set is done, the "Next" button lights up. Pieces are tagged R39.1 to R39.5 with "Show names" on. The session data is made up.

### What to test on the phone

1. R39: tick a set. The rest pill should rise from the bottom without covering a row you need. Does it feel right that it starts unasked? Tick all four: "Next" should wake up with a thud.
2. R39: the dials inside the rows should feel the same as in R23.
3. R38: tap days far apart and watch the highlight travel. Swipe sideways for the previous month; try to go into December.
4. R37: "Archive this session", then Undo before the bar drains. "Show a banner", then swipe it up.
5. R36: move the corner slider end to end and switch spacing; watch the frame-rate readout.

### Not checked

- Only the Linux preview (software rendering, mouse). Haptics, real frame rate and feel were not checked.
- R36 in Lumen's light mode, and all four at a large system text size.

## Build 11 (13 November 2026)

Six new examples, in a new home section called "More patterns". Nothing was removed; rooms 1 to 29 and the bonus are unchanged.

**Files:** `releases/lumen-build-11.apk`, `releases/lumen-source-build-11.zip`

### New

- **R30 Settings screen.** A complete settings screen. Profile header; rows in small groups; controls that work inside the row (a dial for rest seconds, kg/lb, a switch); a back-up row that shows its progress in place; and a "Danger zone" where erasing needs a held press that fills the button, followed by an Undo for six seconds. The Haptics and Reduce motion switches are real and affect all of Lumen. Pieces are tagged R30.1 to R30.5 when "Show names" is on.
- **R31 Number pad.** A keypad of our own for numbers too far to dial. Large live number, +10 / +50 / +100 chips, and a shake with a thud when a key is refused (a sixth digit, or a decimal point on calories).
- **R32 Scan.** A scanning flow with a drawn stand-in for the camera (Lumen does not ask for camera permission). The corner frame closes on the barcode, a result sheet springs up, and a portion dial updates the calories live.
- **R33 Widgets.** A grid of tiles. Long-press one to edit; drag its round handle to resize in whole cells; the minus removes it; "Add a widget" opens a picker. Other tiles spring out of the way.
- **R34 Lists.** A long list: search as you type, filter chips, letter headers that stick, a letter rail on the right to jump with a thumb (one tick per letter), and an empty state when nothing matches.
- **R35 Celebrate.** Three short rewards: a personal best (medal pop, confetti, rolling number), a weekly streak filling in, and a goal ring closing into a tick. Each lasts about a second and then stops.

### What to test on the phone

1. R30: hold "Hold to erase everything". Does the ticking build-up feel like a warning? Let go halfway: it should drain back. Does a quick tap do nothing?
2. R30: while holding the erase button, the page should not scroll.
3. R33: long-press a tile, then drag the handle. Does the size snap where you expect, with a tick each time?
4. R34: slide a thumb down the letters. One tick per letter, and the list should keep up.
5. R35: "Lift 5 kg more". A thud, then three light ticks, in time with the confetti. Watch the frame-rate readout during the burst.
6. R32: watch the readout while the scan line sweeps.

### Not checked

- Everything was checked only in the Linux preview (software rendering, mouse). Haptics, real frame rate, and how any of this feels under a thumb were not checked.
- R31 and R34 with a large system text size.

## Build 10.2 (13 November 2026)

**File:** `releases/lumen-build-10.2.apk`

- R23 Inputs: removed the "step / fine" bubble above the dials. The steps, the haptics, the lift and the turning wheel edge are unchanged.

## Build 10.1 (13 November 2026)

**File:** `releases/lumen-build-10.1.apk`

- R23 Inputs: the kilo dial now moves by 1 kg at normal speed and 0.5 kg when the thumb moves slowly (was 0.5 and 0.1). Reps unchanged: 1, and 0.5 slowly. Nothing else changed.

## Build 10 (13 November 2026)

Lumen as a visual vocabulary: things to screenshot, record or point at. A catalogue of named components, four
complete screens, labels you can switch on, and thumb dials for workout numbers.

**Files:** `releases/lumen-build-10.apk`, `releases/lumen-source-build-10.zip`

### Changed on request

- **R23 Inputs: the set rows are now thumb dials.** Drag a number sideways. Kilos move by 0.5, and by 0.1 when the
  thumb moves slowly; reps by 1, and by 0.5 slowly. Slow means under about 45 px a second for a tenth of a second;
  speeding up past about 160 px a second returns to normal steps (which land on the 0.5 grid again). A bubble above
  the dial says which step is active, a different haptic marks the switch, and the edge of a wheel turns under the
  thumb. A tap on the left or right half steps once.

### New: Screens (a new section on the home screen)

- **R25 Components.** Every control with its id and name printed under it (C01 to C24): buttons, the newer button
  group, split button, FAB menu and floating toolbar, chips, switch, checkbox, radio, segmented picker, slider,
  stepper, search field, list row, badges, progress, tabs, toast, banner. All of them work.
- **R26 Dashboard.** A complete home screen: greeting, summary card with a ring, stat tiles, an action tile, a
  list section, a floating glass toolbar.
- **R27 Detail page.** A hero picture with parallax, title block, fact chips, highlights, and a floating glass
  action bar.
- **R28 Assistant.** An AI chat: thinking state, an answer that streams, numbered citations, a sources list and
  the reasoning as fold-outs, a generated card with an action, suggestions, and a send button that becomes stop.
  Prepared answers only; it says so.
- **R29 Onboarding.** Three swipeable steps whose illustration morphs with the swipe, progress dots, skip, and a
  finish state.
- **Show names.** The tag button at the top right of R26 to R29 draws a blue label on every piece (for example
  "R26.3 Stat tile"), so a screenshot names what it shows.

### What to test

1. **Dials:** change a weight quickly, then slow right down. Is the switch to 0.1 at the right speed, or does it
   trigger too easily or too late? Same for reps.
2. **Show names:** switch it on in the Dashboard and take a screenshot. Are the labels useful, too many, too big?
3. Scroll the Detail page: the picture should move slower than the text.
4. Assistant: tap a suggestion; try Stop mid-answer; open "How I worked this out" and the sources.
5. Components: press everything in "Newer button patterns".

### Not checked here

Feel, haptics and frame rate. The two glass bars (R26.6, R27.5) were only seen on my software renderer.

## Build 9 (13 November 2026)

Lumen becomes a reference library: every example has an id, and there are six new "Patterns" rooms.

**Files:** `releases/lumen-build-9.apk`, `releases/lumen-source-build-9.zip`

### New: the reference system

- Every room has a stable id (R01 to R24, B01 for the bonus), shown as a small chip next to the room number.
  Tap the chip: it copies a line with the id, the name, what the example shows and its source files, ready to
  paste into another chat.
- `REFERENCE.md` in the source lists every id with its files and a short "how to reuse" note.
- `lib/reference.dart` is the same index in code.

### New: Patterns

- **R19 Performance lab.** Three cases (shadows, live blur, an idle animation), each built the costly way and the
  cheap way. A button runs a 3 second test and reports frames drawn, average build and raster time, the slowest
  frame and missed frames, from the engine's own timings on the device.
- **R20 Launcher.** A home screen: long-press an icon and drag, the others make room on springs; hold it over
  another icon to make a folder; tap a folder to open it, long-press an app inside to take it out; a dock; an
  "All apps" drawer with search.
- **R21 Blob menu.** One button splits into three, four or five actions on an arc. Tap, or press, slide and
  release in one movement. Labels are placed so they cannot collide.
- **R22 Timers.** A rest timer that stores its end time, wakes once a second, and stays reachable as a pill when
  you scroll away. Pause, resume, add or remove 15 seconds.
- **R23 Inputs.** A weight ruler (drag or flick, a tick per half kilo, resistance at the ends), steppers that
  repeat while held and speed up, and workout set rows with a tick.
- **R24 Do and don't.** Four mistakes next to their fixes: spinner and skeleton, confirm and undo, vanishing and
  persistent labels, small and proper touch targets.

### What to test

1. Tap an id chip in any room, then paste somewhere: is the line useful as it is?
2. **Performance lab:** run Shadows and Blur, costly then cheap. Send me a screenshot of the results table; these
   are the first real numbers for those effects on your phone.
3. **Launcher:** drag an icon across the grid; make a folder; open it; take an app out; open All apps and search.
4. **Blob menu:** press the button, slide to an action and release without lifting in between.
5. **Timers:** start one, scroll down, tap the pill. Lock the phone for 20 seconds and come back: the time should
   be right.
6. **Inputs:** flick the ruler; hold a plus button.

### Not checked here

Feel, haptics and frame rate. The Performance lab's numbers on my machine come from a software renderer and are
meaningless; I only checked that the test runs and reports.

## Build 8 (12 November 2026)

Fixes from testing, plus a new home section, "Foundations": six rooms on the basics.

**File:** `releases/lumen-build-8.apk`

### Fixed

- **Haptics everywhere.** Every haptic (dial notches, lens tick, toggles, dance floor)
  now drives the vibration motor from native code, like the disco beat. Three strengths:
  tick, click, thud. They play even in silent mode; Settings has a new Haptics switch.
- **Foil cards.** The card now tilts away from your finger, as if you pressed it down
  there (it used to lift toward the finger). Dragging on the card no longer scrolls the
  page. The glare sits near your finger. Starlight's stars no longer sit on a grid.

### New: Foundations

- **13 Type.** One article, with hierarchy on or off. Pick a scale ratio and every size
  re-derives from it. Line-height slider.
- **14 Space.** A contact card built from one base unit (4, 8 or 12). Switch grouping off
  to see why distance matters. Grid overlay.
- **15 Contrast.** Sliders for text and background with the live contrast ratio and pass
  marks. A colour-blindness simulation shows why status needs more than colour.
- **16 States.** A button in its six states. A screen that loads with a skeleton and
  ends as content, empty or error.
- **17 Forms.** Floating labels, checks as you type, errors only after you leave a field,
  password strength, a button that shakes and shows what is missing.
- **18 Sheets.** Rows you swipe away with Undo. A bottom sheet with three resting
  heights you can drag or flick.

### What to test

1. Dials: do you feel the notches now? Too strong, too weak?
2. Foil: does tilting feel natural now? Try "Tilt with the phone" again.
3. Forms: type in the fields with the keyboard open. Nothing should be hidden.
4. Sheets: flick the sheet up and down; swipe a row away and undo.

## Build 7.1 (12 November 2026)

**File:** `releases/lumen-build-7.1.apk`

- **Feel the beat** now drives the vibration motor directly from native Android code
  with a heavy "thud" (or the strongest effect the phone supports), and plays it as
  media vibration so silent mode should not mute it. It previously used the lightest
  system tick, which Samsung phones can play very faintly or skip when no finger is on
  the screen.
- **Smoother opening and closing:**
  - All custom shaders are prepared off screen while the app starts, instead of on
    their first use inside a room.
  - Every open and close holds still for about 25 ms (three frames) before moving, so
    the expensive first frame of a new screen happens before anything is in motion.
    A back swipe still continues immediately.
- **Measured, not guessed:** after each open and close, the readout shows how many
  frames were missed during it ("Open: 0 missed frames" in green, otherwise yellow).

### What to test

1. Disco room, Party mode on, Feel the beat on: is the beat strong and regular now?
   Try once with the phone in silent mode and once in vibrate or sound mode.
2. Open and close several rooms, especially Glass, Shaders and Flow. Note the numbers
   in the readout. A screenshot of a yellow one tells me where to look next.

## Build 7 (12 November 2026)

The last three trend rooms. All twelve rooms and the bonus are now in.

**File:** `releases/lumen-build-7.apk`

### What is new

- **Room 09, Colour.** Pick one of six pictures. The phone renders it small, groups its
  pixels into five colour clusters (k-means, written for this app) and picks a seed: the
  largest cluster that is also colourful. Material's colour engine then grows the seed
  into a full scheme, and a sample screen plus every colour role glide to the new
  colours. Four scheme styles: Calm, Vibrant, Playful, Faithful.
- **Room 11, Data.** A line chart that morphs between Week, Month and Year (the line
  reshapes and the scale slides rather than redrawing). Drag across it: a magnetic
  cursor snaps to each day with a tick, and the headline number rolls to that day's
  value. Below, bars grow in a wave; tap one to focus it.
- **Room 12, Access.** The same small screen four times: standard, 170% text, high
  contrast and reduced motion. "Play" triggers the same action on all four: the
  reduced-motion one changes in place with a fade instead of bouncing. Switches show
  what a screen reader announces (numbered, in order) and outline every touch area.
- Fixed: progress fills were invisible on the Foil card stats and the Live pill music bar.

### What to test

1. **Colour:** switch pictures and styles quickly, mid-animation. Colours should glide,
   never flash.
2. **Data:** scrub slowly over Month: about 30 ticks across the chart. Too many?
3. **Access:** turn on "Show what a screen reader says". If you have time, turn on
   TalkBack in phone settings and swipe through the standard panel: it should read the
   same list.

## Build 6 (12 November 2026)

Home gets a second section, "Trends, part two", with six new rooms. Three of them are in
this build; Colour, Data and Access follow in build 7. Discomorphism moves to its own
Bonus section at the end. Each new room opens with one or two lines on the trend it shows.

**File:** `releases/lumen-build-6.apk`

### What is new

- **Room 07, Foil.** Collectible cards with a holographic foil drawn by a shader:
  rainbow bands that shift with the angle, a moving glare, and per-card patterns
  (diffraction lines, flashing stars, a mosaic). Drag on the card to tilt it in 3D. Or
  switch on "Tilt with the phone": the app reads the gravity sensor directly (no
  library) and the card follows the phone.
- **Room 08, Dials.** A volume knob with 40 notches: a tick per notch, a heavier thud at
  each end, rubber-band resistance past the ends. Flick it and it coasts, then settles
  into the nearest notch. The shading stays put while the knurled edge turns, like a
  real knob under a fixed light. Below it, an alarm set with 3D wheels that click.
- **Room 10, Live pill.** A black status pill on a lock-screen mock. Start a timer,
  music or a call: the pill grows to show it. With two activities the second one
  splits off into its own bubble. Tap the pill to open it into controls; tap the
  background to close. "Notify" shows a short-lived notification. A call opens by
  itself and takes priority.

### What to test

1. **Foil:** drag slowly across the card. With "Tilt with the phone" on, rock the phone.
   Is the effect convincing, too strong, or too weak?
2. **Dials:** turn slowly and count the ticks; then flick hard. Does it feel like a real
   knob? Is the haptic too busy?
3. **Live pill:** start Timer and Music, then Call. Watch the bubble split off and the
   pill reshape. Answer and decline a call.
4. The lock-screen background in the Live pill room and the Flow pages may show a hard
   edge in their gradient on my preview. Tell me if you see that on the phone.

## Build 5 (12 November 2026)

Adds a bonus room: Discomorphism.

**File:** `releases/lumen-build-5.apk`

- **Discomorphism** (bonus card at the bottom of home). A mirror ball drawn live by a
  shader: about 900 flat tiles, each reflecting three circling coloured spotlights and a
  white key light, with random glints. Its light spots sweep across the walls as it
  turns. Chrome headline with a sweeping highlight, a Party mode button tiled with tiny
  mirrors, and a dance floor in perspective that lights up under your finger.
- **Party mode:** the ball spins faster, colours come up, the floor lights to a 120 BPM
  beat, and with "Feel the beat" on the phone pulses a light haptic on every beat.

### What to test

1. Swipe across the dance floor: tiles should light where your finger is, with a tick per
   new tile.
2. Party mode on, phone in your hand: does the haptic beat feel like a beat or like noise?
3. Watch the readout with Party mode on.

## Build 4.1 (12 November 2026)

**File:** `releases/lumen-build-4.1.apk`

- Fixed: the like counter showed misaligned digits (for example "1276") when the phone's
  text size is larger than default. Digits are now measured at the phone's text size.
- Same fix for the Copy/Copied label and the rolling suggestions in the prompt bar.
- Test: tap like several times quickly; the digits should always land on a clean number.

## Build 4 (12 November 2026)

Adds Room 06 (Details). All six rooms are now in.

**File:** `releases/lumen-build-4.apk`

### What is new

- **Room 06, Details.**
  - **Fluid type:** the headline is drawn letter by letter. Its weight thins as you
    scroll down; scrolling fast condenses the letters and sends a wave of weight
    through them, which wobbles out on a spring when you stop.
  - **Pull to refresh:** a ring fills as you pull, turns into a coral shape with a tick
    once you have pulled far enough, becomes a loader, then a check. A new message opens
    up space for itself at the top of the inbox.
  - **Prompt bar:** suggestions roll through the empty field. The send button turns from
    a round grey button into a coral square when you type. Sending starts a light that
    runs around the bar, then the answer streams in word by word, and labels (AI draft,
    sources, check before using) fade in at the end. The four suggestions have their own
    answers; anything you type gets an honest "demo reply" answer.
  - **Small things:** a like button with a burst and a rolling counter; a copy button
    that turns into a confirmation and actually copies text.

### What to test

1. **Pull to refresh:** pull slowly. Feel for the single tick when it arms. Pull a bit,
   then release before the tick: nothing should happen.
2. **Headline:** from the top of the room, flick the page up and down. Watch the
   letters during and just after the flick.
3. **Prompt bar with the keyboard:** tap the field and type. The bar should stay visible
   above the keyboard. Send with the button and with the keyboard's send key.
4. **Like:** tap repeatedly and quickly. The digits should roll, not jump.

## Build 3.1 (12 November 2026)

**File:** `releases/lumen-build-3.1.apk`

- Springs room: removed the target marker (ring and cross) behind the balls. Tapping still sets where both balls go.

## Build 3 (12 November 2026)

Adds Room 04 (Flow) and Room 05 (Shaders), and predictive back on every screen.

**File:** `releases/lumen-build-3.apk`

### What is new

- **Predictive back everywhere.** With gesture navigation, swiping back makes the
  current screen shrink, round its corners, drift with your finger and reveal the
  screen underneath. Let go early or drag back and it springs open again; finish the
  swipe and it flies back into the card it came from. With the back button, the same
  closing animation plays on a spring.
- **Room 04, Flow.** Six story cards in a two-column grid. A card grows into a full page
  (the page itself grows out of the card, not just a window into it). Back puts it
  back into its slot. The room shows which navigation mode the phone is using.
- **Room 05, Shaders.** Three full-screen exhibits, switched with a glass bar:
  - **Aurora:** domain-warped noise at full resolution, six noise layers. Touch swirls
    and pulls it.
  - **Ripple:** tap or drag. Real text and shapes are bent and lit by up to six waves.
  - **Blur:** a progressive blur at the top, sharp at its lower edge and fully blurred at
    the top, computed in one pass with 56 samples per pixel.
- Shader exhibits follow the quality setting: Auto starts at Full and steps down if
  frames are missed.

### What to test

1. **Back with the button**, from every room: it should close into its card on home.
2. **Back with gestures:** switch the phone to gesture navigation (Settings, Display,
   Navigation bar, Swipe gestures). In every room, swipe slowly from the left or right
   edge, hold, move up and down, then let go. Try once releasing early (should spring
   open again) and once completing (should fly into its card).
3. **Glass room with the back swipe:** the glass must stay aligned with its outline
   while the page shrinks.
4. **Flow:** open each card and go back. The card's slot should stay empty while it is
   open, and the card should reappear exactly as the page lands.
5. **Flow page header:** on my preview renderer, tall colour gradients show a hard
   horizontal edge. If the landscape at the top of a story page is cut off by a straight
   line on your phone, tell me.
6. **Shaders:** watch the readout in each exhibit, especially Aurora while touching and
   Blur while scrolling fast. If a "Glass lowered" notice appears, note which exhibit.

### Known limits

- Settings are still not remembered between launches.

## Build 2 (12 November 2026)

Adds Room 02 (Springs) and Room 03 (Shape morph). Rooms 04 to 06 are still placeholders.

**File:** `releases/lumen-build-2.apk`

### What is new

- **Room 02, Springs.** Two balls get exactly the same input. The top one moves the
  classic way (420 ms, ease in-out); the bottom one is a spring.
  - Tap to move the target. Tap again before it arrives.
  - Drag on empty space to drag the target around continuously.
  - Grab a ball (both are caught where they are), move it, then throw it.
  - Four spring presets: Bouncy, Natural, Snappy, Gentle. The plot under them shows
    position over time for the curve and the chosen spring.
  - Haptic tick when the spring ball settles. The curve ball gets none.
- **Room 03, Shape morph.** All shapes are hand-built and morph by blending outlines.
  - Hero shape: tap to step through eight shapes, or drag sideways to scrub; release
    and it springs to the nearest shape, with a tick when it lands.
  - Toggles: round when off, squircle when on, squeeze on press.
  - Send button: becomes a circle with a morphing loader, then a green tick, then
    returns to a pill.
  - Three loading indicators that spin while changing shape.

### What to test

1. **Springs, interruption:** tap one spot, then quickly tap another before the balls
   arrive. The top ball should visibly stop and restart; the bottom one should curve
   smoothly into the new direction. This is the whole point of the room.
2. **Springs, drag the target:** drag on empty space. The top ball should lag and crawl;
   the bottom one should follow fluidly.
3. **Springs, throw:** grab the bottom ball and flick it. It should fly in the direction
   of the flick before coming back. The top ball ignores the flick.
4. **Shape morph, scrub:** drag sideways slowly over the shape, then flick. Every
   in-between frame should be a clean outline, with no kinks or flicker.
5. **Send button:** tap it and watch the whole sequence. Does the timing feel right?
6. **Frame rate:** the Shape room keeps animating because of the loaders, so the readout
   shows fps there all the time. Note the numbers.

### Known limits

- Same as build 1: back does not follow the finger yet, settings are not remembered.

## Build 1 (12 November 2026)

First build: home screen and Room 01, Glass. Rooms 02 to 06 are placeholders.

**File:** `releases/lumen-build-1.apk`

### What is in it

- Home: bento grid of six rooms. Glass opens; the others shake to say "not yet".
- Room 01, Glass: a colourful feed with glass only on the controls.
  - Navigation bar whose selection indicator is a lens you can drag or throw.
  - Two round glass buttons (back, tune) and a tuning panel.
  - Clear-to-tinted slider, quality picker (Auto, Full, Medium, Low), solid fallback switch.
  - Four feeds. Paper is nearly white on purpose: it is the hardest case for glass.
- Settings (top right on home): theme, reduce motion, reduce transparency, glass quality, frame-rate readout.
- Frame-rate readout at the top of every screen, on by default.

### How it is built

- Flutter 3.50, Dart 3.14, `material_ui` 1.11 (no deprecated imports), Impeller.
- Glass shader, spring system and controls are hand-written. No community UI packages.
- Glass is two passes: the engine blurs what is behind the control, then the shader bends,
  tints and lights it. Quality tiers: Full (refraction, colour split, rim light), Medium
  (lighter refraction, no colour split), Low (blur and tint only), Solid (opaque).
- In Auto, quality steps down by itself if more than about 12% of frames are missed for
  two seconds running, and a notice appears above the bar.

### What to test

1. **Readout when idle.** It should say `idle · 120 Hz`. If it says 60 Hz the phone is not
   giving the app its fast display mode.
2. **Does the glass look like glass?** Rim light on the edges, content bending near the
   rim, slight colour fringes on the lens. If any glass is black, offset from its outline,
   or upside down, switch quality to Low and tell me. This is the one part verified only
   on a software renderer here, not on a real phone GPU.
3. **Drag the lens** slowly, then throw it. It should follow the finger with a little
   weight, stretch when fast, and land on a tab with one haptic tick as it settles.
4. **Scroll the feed** under the bar while watching the readout: fps and `missed`.
5. **Tune panel:** move the slider end to end; try each quality tier; try Solid fallback.
6. **Paper feed:** are the bar labels still readable over white?
7. **Open and close the room** several times, including pressing back mid-opening.
8. **Light theme and Reduce motion** in Settings.

### Known limits

- Smoothness, haptic strength and shader cost are unverified on a real device.
- Back uses the system gesture but does not yet follow the finger (that is Room 04).
- Settings are not remembered between launches.
- The readout updates about once a second; it shows `idle` when nothing is moving.
