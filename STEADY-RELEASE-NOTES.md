# STEADY v5.11.2 — visual QA test release

Based on the previous experimental STEADY edition, built from the supplied v5.10.0 compiled app. This package is **not a complete product redesign** and is **not validated against real user data**.

## Corrections

- Progress: foreground colors of power level, goals, weekly cards, stats, chart labels, and details; off-white white-card visual system.
- Settings: removed comic-outline Settings heading, normalized contrast and typography.
- Workout: replaced black segment bar with light progress track and distinct completed/current segments; retained set logger and rest timer.
- Calendar: restored readable title/arrows over seasonal images when custom seasonal artwork is available.
- Feedback: dark toast with white text.

## Validation performed

- Inline JavaScript syntax check.
- Browser renders at 393x852 (Today, Progress, Settings, Journey, Month, workout) with synthetic data; no page-level JavaScript exceptions in those tested views.
- Further checks: ZIP integrity and local packaging.

## Not validated

- Real phone testing, device installation, persistent user history, GitHub cloud sync, screenshot OCR, service-worker upgrades on a live origin, all translations and edge cases.

## Source caveat

The supplied release is compiled `index.html`. CSS changes are included in the compiled file and `STEADY-VISUAL-PATCH.css` for later porting into Claude's original `src/head.html`. Avoid re-building the original source without porting these changes.

## Safe testing

Use a separate GitHub Pages repo/site. Back up current data. Do not replace the live application until real-device and data-restore tests pass.
