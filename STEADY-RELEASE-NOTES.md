# Trening v5.11.0 — STEADY visual test build

This is an **experimental redesign of the existing personal app**, not the new commercial product.

## Changed
- Light off-white / forest-green / lime design language inspired by the STEADY concept.
- Restyled Today, Plan (formerly Journey), Progress (formerly Scouter), Settings, onboarding, workouts, exercise logging and sheets.
- Moved Today's training tile above the calorie budget to prioritize the next workout.
- Simplified bottom-navigation presentation while preserving existing routes.
- Version and PWA cache bumped.

## Not changed
- Original personal-app data model, training programming, state migration, IndexedDB/localStorage persistence, cloud sync, imports, energy calculations, achievements or reward logic.
- Dragon-ball game assets remain in this personal build; their use is not appropriate for a future public product.
- RepDB is not included. No new knowledge lessons or workout generator logic added.

## Important limitations
- The production source modules were not present in the supplied release ZIP. This build patches the compiled `index.html`; your Claude source must be updated before the next normal build or these changes will be overwritten.
- Do not immediately overwrite the live app. First test in a staging GitHub Pages repository/origin and export a JSON backup.
- Visual redesign is not a complete accessibility audit.
