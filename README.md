# Vikač High Kikač — install guide (v2.1.1)

This folder is the whole app. Put it on any HTTPS address and add it to your phone's home screen once; after that it opens full screen from its own icon, works offline, and keeps all data on the phone.

## 1. Put it on GitHub Pages (about 10 minutes, once)

1. Go to github.com and sign in (create a free account if you don't have one).
2. Top-right **+** → **New repository**. Name: `vikac`. Public. Tick **Add a README file**. Click **Create repository**.
3. On the repository page click **Add file** → **Upload files**.
4. Open this folder on your computer and drag the files inside it (index.html, manifest.webmanifest, sw.js, the three icon PNGs) into the upload area. Since v1.2.0 the fonts and photos are built into index.html, so there are no folders to upload.
5. Click **Commit changes** at the bottom.
6. Repository **Settings** → left menu **Pages** → under *Build and deployment* set **Source: Deploy from a branch**, **Branch: main**, folder **/ (root)** → **Save**.
7. Wait 1–2 minutes, refresh the Pages settings page: it shows your address, `https://YOURNAME.github.io/vikac/`.

## 2. Install it on the S25

1. Open that address in **Chrome** on the phone (not Samsung Internet — Chrome gives the proper full-screen install).
2. Chrome menu **⋮** → **Add to Home screen** → **Install**.
3. Open it from the new icon. It runs full screen. The first open plays the intro and asks for your starting numbers (already pre-filled with your S400 data from 2 Nov).

## 3. Projects

Settings shows the **current project** (name, dates, deficit, goal) with Edit, **New project** and, while it runs, **End this project today**. Edit changes dates (extend or shorten), targets and the starting point — the starting numbers can be filled from the Mi Fitness share image with **Fill from export**, in Edit and in the setup wizard. New project parks the current one under **Past projects** with everything logged; a past project opens a summary (days, perfect days, weight / fat / muscle start → end) with **Reopen** (it becomes current again, the current one is parked) and **Delete**. The setup wizard for a new project starts today with the last readings of the previous project pre-filled, and can be cancelled back to it.

## 4. Earning the ball, and the report card

On a training day the ball needs the session and the nutrition entry (required, ball badge in the corner, green tick); the weigh-in, hangs, stretching and mobility are bonus (blue tick). On a rest day everything is required. Progress → Overview grades Training, Nutrition and Stretch as done ÷ possible so far on the American scale (A+ ≥ 97, A ≥ 93, A− ≥ 90, B+ ≥ 87 … D− ≥ 60, F below), and the Today screen shows the same grades as of the day you are looking at.

## 5. Keeping your data safe

- Data lives on the phone (Chrome's storage for this app). It survives restarts and being offline. It is lost only if you uninstall the app or clear Chrome's site data.
- **Profile → Backup now** downloads `vikac-backup-DATE.json`. Drop it in Google Drive now and then; the Today screen nags you after 7 days without a backup. **Restore** brings everything back from that file, on any phone.

## 6. Cloud backup to GitHub (optional, recommended)

Every change can also be saved as a commit to a **private** repository of yours, with full history — nothing is lost unless you delete that repository. One-time setup, about 5 minutes:

1. On github.com: **+ → New repository**, name `trening-data`, choose **Private**, tick **Add a README file**, create it. (Keep it separate from the public `vikac` repository that hosts the app.)
2. Profile photo → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
3. Name it "Trening", set the longest expiry offered, **Repository access: Only select repositories → trening-data**.
4. **Permissions → Repository permissions → Contents: Read and write**. Generate and copy the token (it is shown once).
5. In the app: **Profile → Cloud backup**, enter `yourname/trening-data` and the token, tap **Connect**.

The app then pushes a commit about 10 seconds after your last change (and when you leave the app), shows "Saved to GitHub … ago" in Profile, and nags you on the Today screen if syncing has failed for 3 days. **Restore from GitHub** brings everything back on a new phone. The token is stored only on the phone and can only touch that one repository; when it expires, make a new one and tap Connect again.

## 7. Fill from export (Xiaomi scale and MyFitnessPal)

The weigh-in form can read the Mi Fitness share image instead of you typing six numbers. Two ways in:

- **From the Xiaomi app:** on the body-composition screen tap share → choose **Trening**. The app opens on a "Fill from export" screen with the date from the image (editable) and the values already in the boxes — check, then **Save**. If Trening isn't in the share sheet yet, Chrome hasn't picked up the new manifest: wait a day, or remove the home-screen icon and add it again.
- **From the weigh-in screen:** tap **Fill from export** and pick the image from your gallery.

**MyFitnessPal works the same way.** Take a screenshot of MFP's Today screen (or the diary with its Totals row), share it to **Trening** — the app recognises it as MFP and opens the nutrition form with the calories and protein filled in, date from the header ("Today", "Yesterday" or a date). On the nutrition screen, **Fill from export** picks a screenshot from the gallery.

**Many at once:** share several screenshots to Trening in one go, or Settings → **Read screenshots** and pick them. Each is read and logged to the day it shows — "Today", "Tomorrow", "Yesterday" or the date in MFP's header, the date printed on the Mi Fitness card — so food can be logged days ahead. Rows that could not be read (no date, unknown image) say *Check*; tap one to set the date or numbers by hand. Empty MFP days are skipped.

**Macros:** nutrition keeps calories, protein, carbs and fat. Targets per day: protein as set (≈2.2 g/kg), fat 0.65 g/kg of current weight (never under 0.5 g/kg — the floor for hormones, per Helms 2014's 20–30 % of calories), carbs take whatever energy remains after the deficit, so they rise on days with more band kcal. Progress shows the 7-day averages against the targets.

**Catching up several days:** MFP → More → Settings → **File Export** → pick the period → Export. MFP emails a link to a zip; open the link on the phone, download the zip, then in Trening **Settings → Read from MFP export** and pick it (the Nutrition-Summary CSV on its own also works). Every project day that isn't logged by hand gets its calories and protein; days you typed yourself are left alone, earlier imports are refreshed, and today is skipped unless it's after 21:00 (exports are usually taken mid-day).

Reading happens on the phone (tesseract.js) — the image is never uploaded anywhere. The first use downloads the reader (about 6 MB: `tess.js`, `tess-worker.js`, `tess-core.wasm.js`, `eng.traineddata.gz`); after that it works offline. The weight is cross-checked against fat-free weight + fat mass from the same image, so a misread digit shows up as a warning.

## 8. Updating the app

When a new version arrives, upload the new files to the same repository (Add file → Upload files, same names, Commit). The phone picks up the new version the next time you open the app while online. Your data is untouched by updates.

## Files

| File | What |
| --- | --- |
| index.html | the entire app (logic, styles, art) |
| manifest.webmanifest | tells Android it's an installable app, full screen, orange icon |
| sw.js | offline cache; its version string changes on every release |
| icon-*.png | app icons |
| tess.js, tess-worker.js, tess-core.wasm.js, eng.traineddata.gz | the on-phone text reader for Fill from export (loaded only when used) |
| src/, build.sh, font/, img/ | source parts the app is built from (fonts and photos are already inside index.html); not needed on the phone |
