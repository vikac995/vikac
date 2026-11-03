# What to do now — updating to v1.6.0

Your phone is on an older version; this zip contains everything up to v1.6.0 (cloud backup, the science update, the cycle view with dragon balls). One upload covers all of it. Your logged days, weigh-ins and workouts stay on the phone — nothing is wiped by an update.

## A. Upload the new files (3 minutes)

1. Unzip this file on your computer. Inside the `vikac` folder you need these 7 files: `index.html`, `sw.js`, `manifest.webmanifest`, `icon-192.png`, `icon-512.png`, `icon-512-maskable.png`, `README.md`.
2. Open https://github.com/vikac995/vikac in your browser.
3. Click **Add file → Upload files**.
4. Drag those 7 files into the upload box (same names as the ones already there — GitHub replaces them).
5. Click **Commit changes**. Wait about a minute for GitHub Pages to publish.

## B. Get the new version onto the phone (1 minute)

1. Open the app on the phone. Go to **Profile** (it becomes **Settings** after the update) → **Check for updates**. It should say "Version 1.6.0 found — reloading".
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

- Today is built around the cycle: Cycle n · Day d/8, the 8-box strip, the colour-coded day label, the time ring, and the dragon-ball slot. One ball per perfect day; seven balls plus a perfect day 8 summons the dragon.
- Dashboard: Push / Pull / Legs each start with an overall bar; weight, fat and muscle first, skeletal and visceral behind a toggle; the science check shows your real expenditure once 10 days are logged.
- Workouts: rest timer defaults by set type (3 min on the heavy lifts), the recommended rest is shown next to each exercise, exercises tick themselves when all sets are filled, "Use" copies last time's numbers.
- Weigh-in replies with your trend and weekly pace. Nutrition shows the kcal and protein targets before you type.
- Profile is now Settings (gear icon). Tabs switch without the slide. Only one pop-up at a time.
