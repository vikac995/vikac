# STEADY · Glass Concept (v5.13.0 engine)

This is a **separate experimental design build**, based on the `vikac-high-kikac-v5.13.0.zip` supplied by the user.

## What changed

- Replaced the partial orange/comic design with a cohesive forest-green liquid-glass design system, with light and dark modes.
- New app icon and PWA metadata, STEADY branding, glass surfaces, charts, onboarding, navigation, workout logging, planning and settings.
- Swapped the visible Dragon Ball-style assets (balls, dragon, character) for original neutral milestone/fitness art. The seven-step milestone **mechanics are unchanged** to preserve saved data compatibility.
- Renamed visible Journey/Scouter language to Plan/Progress and replaced much of the Dragon Ball copy in the UI with neutral terminology.
- Added Appearance → System / Light / Dark (separate `steady.theme` preference).

## What did not change

- The original v5.13.0 data structures, workout programming rules, nutrition math, workout completion and logging functions, historical records, IndexedDB, cloud backup and update code are retained.
- This is NOT a new intelligent workout generator or the future commercial product. The underlying architecture is still the original compiled single-page application.
- Existing strength and nutrition calculations have not been independently scientifically validated by this UI work.

## Installing for tests

Upload the **contents of the `vikac/` folder** to a new repository / GitHub Pages test site. Do not overwrite a live app. Test using synthetic data first; preserve a backup of your active workouts.

## Files

- `index.html`: original v5.13.0 compiled JS, with a clearly marked STEADY visual-adapter block before app boot.
- `steady-glass.css`: standalone component design system, including both themes.
- `sw.js`: distinct cache key and CSS pre-cache.
- `manifest.webmanifest`, `icon-*.png`: STEADY visual branding.
- `ORIGINAL-v5.13.0-README.md`: original readme saved verbatim.
- Existing OCR assets are unchanged.

## Limitations

These are prototype-level UI changes. Some rarely used features and live sync / upgrade paths are not fully regression-tested. Existing HTML contains old illustration helper functions for compatibility; the STEADY visual adapter supersedes their output at runtime. Do not interpret unchanged internal function names as new game rules. A production migration should be made in Claude's modular source code, not maintained only in this compiled artifact.
