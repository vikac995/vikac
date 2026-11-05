# Trening v5.11.1 — STEADY visual revision 2 (TEST BUILD)

This is a corrected test of the existing personal PWA and **not** a complete rewrite of its UI or the planned public app.

## What is actually changed
- Fixes the original `.bud` calorie-budget panel using a solid white background and explicit contrast-safe text, numbers, chips and progress bar.
- Rebuilds the workout sticky header styling so the title, rest-timer label, back button and progress are readable against a white surface.
- Restyles set-entry controls and exercise cards with a consistent type scale, borders and compact spacing.
- Fixes the completed-workout result tiles' muddy grey backgrounds and faint labels.
- Preserves the earlier STEADY navigation, Today-first training hierarchy, settings, and calendar reskin.
- Updates the service worker cache to `vikac-v5.11.1-steady-v2`.

## Visual checks actually executed
- Chromium via Playwright `set_content` at 393×852 CSS pixels: first-project setup, Today (seeded test data), active Full body B workout, Journey, and Settings.
- Saved actual PNG screenshots of Today and workout in the release QA preview package.
- No JavaScript `pageerror` events in these tested views.
- Inline app JavaScript compiled with Node `new Function` syntax validation.

## Known limitations
- Browser navigations to local addresses were blocked by runtime policy, so rendering used Playwright `set_content` (about:blank). This cannot validate service worker installation, IndexedDB persistence, GitHub sync, local asset loading, or actual mobile-browser behavior.
- Screens were rendered with temporary synthetic data, not the user's real workout history.
- This is still a **visual refurbishment of the compiled app** rather than a component-level rewrite. The original JS, game assets and much of the layout remain.
- Original modular source and full automated regression suite were not included with the supplied ZIP. Backport the visual changes to the source before any further release from Claude.
- No complete accessibility or visual audit of every screen; no license assets added.

## Safe testing
1. Do NOT overwrite the current production repository. Create a separate private staging repo; publish only the app files and not licensed media or secrets.
2. Back up the current app's JSON first.
3. Test the first-run setup, live workout logging, completed workout, plan, progress, settings, backup/restore and offline behavior on the phone.
4. Only merge if you are satisfied with those checks.
