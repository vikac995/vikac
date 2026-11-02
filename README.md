# Vikač High Kikač — install guide (v1.2.1)

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

## 3. Keeping your data safe

- Data lives on the phone (Chrome's storage for this app). It survives restarts and being offline. It is lost only if you uninstall the app or clear Chrome's site data.
- **Profile → Backup now** downloads `vikac-backup-DATE.json`. Drop it in Google Drive now and then; the Today screen nags you after 7 days without a backup. **Restore** brings everything back from that file, on any phone.

## 4. Updating the app

When a new version arrives, upload the new files to the same repository (Add file → Upload files, same names, Commit). The phone picks up the new version the next time you open the app while online. Your data is untouched by updates.

## Files

| File | What |
| --- | --- |
| index.html | the entire app (logic, styles, art) |
| manifest.webmanifest | tells Android it's an installable app, full screen, orange icon |
| sw.js | offline cache; its version string changes on every release |
| icon-*.png | app icons |
| src/, build.sh, font/, img/ | source parts the app is built from (fonts and photos are already inside index.html); not needed on the phone |
