# What to do now — updating to v1.9.0

This zip is the complete app at v1.9.0 — whatever version the phone is on, one upload brings it up to date. Your logged days, weigh-ins and workouts stay on the phone — nothing is wiped by an update.

## A. Upload the new files (3 minutes)

1. Unzip this file on your computer. Inside the `vikac` folder you need these 11 files: `index.html`, `sw.js`, `manifest.webmanifest`, `icon-192.png`, `icon-512.png`, `icon-512-maskable.png`, `README.md`, and the four reader files `tess.js`, `tess-worker.js`, `tess-core.wasm.js`, `eng.traineddata.gz` (new since 1.7 — about 6 MB together).
2. Open https://github.com/vikac995/vikac in your browser.
3. Click **Add file → Upload files**.
4. Drag those 11 files into the upload box (same names as the ones already there — GitHub replaces them).
5. Click **Commit changes**. Wait about a minute for GitHub Pages to publish.

## B. Get the new version onto the phone (1 minute)

1. Open the app on the phone. Go to **Settings** (called **Profile** in versions before 1.6) → **Check for updates**. It should say "Version 1.9.0 found — reloading".
   - If it says you already have the latest version, close the app completely (swipe it away from recent apps), wait a minute, open it again and tap Check for updates once more.
2. The app name on the home screen only changes when the icon is re-added: long-press the icon → remove it, open `https://vikac995.github.io/vikac/` in Chrome → menu ⋮ → **Add to Home screen** → Install. It will now be called **Trening**. (Your data is in Chrome's storage, not in the icon, so it survives this.)

## C. Turn on cloud backup (5 minutes, once)

This saves every change as a commit to a private GitHub repository of yours, with full history. Nothing there is deleted unless you delete it.

1. On github.com: **+ → New repository**. Name: `trening-data`. Choose **Private**. Tick **Add a README file**. Create repository. (This is a second repository, separate from `vikac`.)
2. Click your profile photo (top right) → **Settings** → scroll down to **Developer settings** → **Personal access tokens** → **Fine-grained tokens** → **Generate new token**.
3. Token name: `Trening`. Expiration: pick the longest option offered. **Repository access: Only select repositories** → choose `trening-data`.
4. **Permissions → Repository permissions → Contents → Read and write**. Click **Generate token**. Copy it now — GitHub shows it only once.
5. In the app: **Settings → Cloud backup**. Repository: `vikac995/trening-data` (it should be pre-filled). Paste the token. Tap **Connect**. It should say "Connected. Cloud backup is on."

From then on, Settings shows "Saved to GitHub … ago". If the phone is ever lost or reset: install the app, open Settings → Cloud backup, enter the same repository and a token, and tap **Restore from GitHub**. When the token expires (GitHub emails you beforehand), make a new one with the same steps and tap Connect again.

## D. What changed since the version on your phone

- v1.9.0 — **Motion & projects.** Screens slide in (forward from the right, back from the left), day swipes and arrows glide in the swipe direction, pop-ups rise and fade, the dashboard's skeletal/visceral section expands in place. The stretch timer stays pinned under the title. Calendar: tapping a day keeps you in the calendar and glides its card to the top; the month header has seasonal scenes (leaf piles, snowmen, cherry trees, parasols) on a matching ground. Dashboard body cards redesigned: big current value, status chip, start → goal beam, plan / pace / heading line; no more character beside the bars. Settings: **Current project** with Edit, **New project** and **End this project today**; **Past projects** with summaries, Reopen and Delete; starting point can be filled from a Mi Fitness screenshot (Edit and setup). Intro removed. "Read from MFP export". Dragon-ball pop-up has more air.
- v1.8.0 — **MyFitnessPal.** Screenshot MFP's Today screen → share → Trening: the nutrition form opens with calories and protein filled in (date from the header), Save or Cancel. The nutrition screen has its own **Fill from export** for a screenshot from the gallery. For catching up: MFP → More → Settings → File Export → Export, open the emailed link on the phone, download the zip, then Trening **Settings → Read from MFP export** fills every unlogged project day at once (hand-logged days are kept; today is skipped before 21:00).
- v1.7.0 — **Fill from export.** In the Xiaomi app, share the body-composition image → pick **Trening**: a screen opens with the date from the image (change it if needed) and all six values filled in; Save or Cancel. On any weigh-in screen, **Fill from export** picks the image from the gallery and fills the boxes. Everything is read on the phone — nothing is uploaded. First use downloads the 6 MB reader once. If Trening doesn't appear in the share sheet right after the update, give Chrome a day to refresh the app, or remove and re-add the home-screen icon.
- Today is built around the cycle: Cycle n · Day d/8, the 8-box strip, the colour-coded day label, the time ring, and the dragon-ball slot. One ball per perfect day; seven balls plus a perfect day 8 summons the dragon.
- Dashboard: Push / Pull / Legs each start with an overall bar; weight, fat and muscle first, skeletal and visceral behind a toggle; the science check shows your real expenditure once 10 days are logged.
- Workouts: rest timer defaults by set type (3 min on the heavy lifts), the recommended rest is shown next to each exercise, exercises tick themselves when all sets are filled, "Use" copies last time's numbers.
- Weigh-in replies with your trend and weekly pace. Nutrition shows the kcal and protein targets before you type.
- Profile is now Settings (gear icon). Tabs switch without the slide. Only one pop-up at a time.
- v1.6.2: the calendar shows a day card under the grid (Day n/58 | type | cycle) — swipe it to move through days, tap it to open the day; the dragon sits centred in its ring; the pop-up pill fades in and out cleanly; day 8 is labelled just "Rest".
- v1.6.1: no more motivational lines or captions — the balls speak for themselves. Swipe left/right on Today to move through days. In the Calendar, tapping a day opens its list (phone back button returns to the calendar), tapping a cycle jumps to its first day, and every day has a "View in Calendar" button.
