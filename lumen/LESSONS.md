# Lessons

What went wrong → why → the rule that prevents it. Short. Agreed rules only; added after each workflow check.

- **Code reading missed runtime facts.** The review of 171 passed code that failed on the phone, because two Prism engines existed. → **Rule:** anything crossing Android ↔ Prism gets recorder lines at both ends (sent / got / answered) in the same build that adds it.
- **Tests that checked only the end state let real bugs pass.** The slow flick could buzz twice and still end "right". → **Rule:** check the path too: transient states, haptic counts, which engine, which window.
- **Missing answers looked like success** (`s['lens'] != true`, timestamps defaulting to 0). → **Rule:** a missing or failed reply is SKIPPED or WRONG, never ok.
- **One failure cascaded into twelve.** → **Rule:** every test part starts from a known state; parts that depend on a failed one are SKIPPED with a reason.
- **The test's own Stop button caught taps.** → **Rule:** test furniture is `IgnorePointer` except to a real finger; checks find targets by key, not by offset.
- **A clean preview isn't proof** for Android code, windows, the GPU or memory (174's leak never showed in the preview: a picker's slide there is 3 frames, on the phone dozens). → **Rule:** label these "only the preview ran it"; a phone run gates the next step.
- **Prism started itself in more than one way** (two tasks, two engines). → **Rule:** one path brings Prism forward (`PrismScreen.bringForward`); nothing starts `MainActivity` by name.
- **One kind of change per build.** → **Rule:** test-only builds stay test-only; behaviour changes stay small and named.
- **A value that changed every frame made a cached resource every frame** (a font weight following an animation: a new font per frame, kept for good; 175). → **Rule:** anything whose value changes each frame (font variations, shaders, paths keyed by values) must not create a cached resource per value. Step it, or keep the resource fixed.
- **Briefs lived only in chat messages.** A context summary or a new session lost their exact words. → **Rule:** every brief is saved to `tasks/` before work starts.
- **A request crossed the build it was meant for** (LESSONS.md, asked for in 175 after it was built). → **Rule:** anything asked mid-build goes into the next commit, and the reply says so.
- **Builds mixed several fixes with investigations** (1b had seven items), so a phone run couldn't say which change did what. → **Rule:** at most one behaviour change and one investigation per build.
