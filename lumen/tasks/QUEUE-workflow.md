# Workflow items (owner approved), after 183

From the review chat, 16 November 2026 (12:55, item 2 replaced at 13:05 and updated at 13:08). Docs only
for now: the review chat slots them into builds. Build-cost estimates at the end.

## 1. Quick checks

- **Each build runs only the test parts it touched,** about 2 to 3 minutes.
- **The full button test runs** every few builds, before a milestone, and overnight (item 2).

## 2. Night test (the owner's spec, as updated)

**When it runs:**
- On by default in test builds.
- The window is 22:00 to 06:00, at most once per night.
- **It starts when the phone has been idle for 45 minutes.**
  - Idle is read with `UsageStatsManager` events: the last user interaction across apps. (Prism already
    has usage access, for screen time.)
  - If usage access is missing, it falls back to "Prism in front and untouched", and the report says
    which was used.
- **If another app is open** and the phone has been idle for 45 minutes in the window, Prism brings
  itself to the front and runs the test (the owner wants this; Prism has "display over other apps").
- **If the screen has already turned off** by the phone's own timeout, Prism wakes it: the test activity
  uses `setTurnScreenOn` + `setShowWhenLocked`. The keyguard is non-secure, by the owner's choice: the
  phone isn't locked at night.
- **Waking up to check, in Doze:** inexact `setAndAllowWhileIdle` checks during the window. They can
  drift about 10 minutes, which is fine. Exact alarms only if the permission is already there; today it
  isn't (`SCHEDULE_EXACT_ALARM` is not in the manifest). The report says which.

**The screen:**
- While Prism's home is in front during the window, Prism holds `FLAG_KEEP_SCREEN_ON` itself. The owner
  sets the phone not to lock; no "stay awake" developer setting is needed.
- During the test, the window's brightness is at minimum.
- After the test, a full black screen at minimum brightness, until touched.

**Battery:** no threshold. Record the battery % and the charging state at the start and the end. If the
battery dies, the test fails.

**Stopping:** any touch stops the test and returns to normal.

**Report:**
- It goes to Past reports, titled "Night test".
- **Owner choices:** the phone isn't locked at night; no battery rule; Samsung power saving is "we'll
  see".

**For the build's report: Samsung behaviour with Prism holding the screen on for hours.** To check and
say what could stop it. From what's known, to be confirmed on the phones:
- **Samsung's auto restart** (Device care › Auto optimisation, "Restart when needed" / at a set time,
  often about 03:00) can reboot the phone in the window. That ends the test, and clears its alarms until
  Prism starts again: Prism is the home app, so it comes back up and re-arms them.
- **Samsung's app sleeping** ("Put unused apps to sleep", "Deep sleeping apps", adaptive battery) can
  hold back Prism's alarms. Prism is the default home and used daily, so probably not, but it's a known
  risk.
- **With the screen on, there's no Doze.** Before the start, inexact alarms in Doze come at most about
  every 9 minutes, in maintenance windows: hence the "about 10 minutes" drift.
- **The phone heating up while charging** can throttle it, or pause charging (Samsung's "Protect
  battery" at 85%). That's recorded, not a stop.
- **`FLAG_KEEP_SCREEN_ON` holds only while Prism's window is visible and in front.** If something else
  comes up (a call, an alarm clock), the screen can turn off. The test should note it and stop cleanly.

## 3. "Look at this" list

Each build carries a short by-eye checklist, shown in the test area (next to the badge and the
asked-for test, `Diag` constants as with `askedTest`).

## 4. Batched polish

Small, independent visual tweaks may share a build.

## 5. Tuning panel (test kit only)

- **Live sliders for the "feel" constants,** plus "Copy my values", which copies them as text.
- **First set:**
  - the panel's open spring (stiffness, damping);
  - the triangle's turn spring;
  - the lens's magnification;
  - the glow's strength at each tone;
  - the glass tint's opacity.
- **Values override the constants at runtime only in test builds.**

## Build-cost estimates (from the code as of 183)

- **1, Quick checks: about half a build, all test code.**
  - **The work:**
    - each of the button test's parts gets an id;
    - a per-build `Diag.quickParts` list (next to `askedTest`);
    - a "Quick check" button that runs only those.
  - **The hard part is each part's known starting state** (LESSONS: every part starts from a known
    state). Some parts lean on the one before; for example, part 5 uses part 4's saved Sidekick menu.
    Those need their own small setup.
- **2, Night test: the biggest, about one to one and a half builds, mostly Android.**
  - **The scheduling:** inexact `setAndAllowWhileIdle` alarms in the window, re-armed when Prism starts.
  - **The idle check:** `UsageStatsManager.queryEvents` for the last interaction, with the fallback.
  - **The wake and the screen:**
    - bring Prism to the front over another app, which "display over other apps" allows;
    - `setTurnScreenOn` / `setShowWhenLocked`;
    - `FLAG_KEEP_SCREEN_ON` during the window;
    - minimum brightness, and the black screen after.
  - **Running it:** start the button test from Android, stop it on any touch, and title its report
    "Night test" in Past reports.
  - **Testing it:** a short test window, for example 2 minutes idle, on the phone, because none of it
    runs in the preview.
  - **Play Store:** waking the screen and coming to the front are fine for a home app with the overlay
    permission. Usage access is already the open policy question.
- **5, Tuning panel: about half to one build.**
  - **The work:**
    - a small registry of named values with their defaults (the constants stay as they are);
    - the use sites read from it;
    - a panel of sliders with "Copy my values".
  - **Some of the values live on Android's side** (the Sidekick panel's spring is in
    `SidekickPanel.kt`), so they need a channel to pass on, which adds a little.
  - **Gating:** it should sit behind the test-kit switch (the earlier estimate), so public builds compile
    it out. Until that switch exists, every build is a test build.
