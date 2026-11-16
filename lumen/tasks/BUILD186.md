# Build 186: the dial's see-through flickers (fix)

From the review chat (16 November 2026, 16:10): a 185 bug from the owner's phone videos (17:08, S25
probably, two recordings), Prism in front, the Sidekick panel open, Lotus look.

> While the finger is on the Hovering or Tucked in dial and moving it, the panel switches between fully
> opaque and see-through in bursts. At 10 fps the frames go O O O T T T O O O O T T T O… for the whole
> drag, roughly every 0.3 s, instead of staying see-through until release. In the other recording it
> mostly stays see-through, with a couple of opaque frames at the start.

- **Asked:** find the cause by reading, and fix it.
- **A phone check:** a synthetic 1.5 s dial drag; `panelAlpha` must stay ≤ 0.55 on every sampled frame
  until release, then rise to > 0.97.
- **Pending the owner** (don't build yet): the held dial fully solid, the rest of the panel more
  see-through.
- **Plan:** 186 = the flicker fix (plus the held-dial tweak if the owner agrees); 187 = the Hovering
  range; 188 = dismiss at the top.
- Prepared on a local branch; wait for the go.

**The scope, confirmed by the owner** (review chat, 16:16): one change, "the Sidekick's panel, fixed up".
Prepare it on a local branch and hold it: the owner is running the 185 button tests, so no push until the
review chat says.
1. **The flicker fix** (`panelAlpha` stays ≤ 0.55 for the whole dial drag), plus the phone check.
2. **The held dial stays fully solid** (alpha 1, its value readable). The rest of the panel (body and all
   other contents) goes see-through, at 0.4 rather than 0.5, so it clearly reads as background. Same
   `clear` spring.
3. **The panel never covers Prism's bottom bar.** In Prism, its bottom ends above the bar (Home / Train /
   the triangle / Food / Progress). Outside Prism, above the system navigation or gesture bar (insets).
   In the owner's screenshot (S25, 17:08), the panel ran down over the bar.
4. **The new order of the contents,** so the dials are on screen without scrolling, within thumb reach:
   Labels → Icons → Colours → Look → Where it rests (the Hovering / Tucked in dials) → the In Prism / Over
   other apps switches at the very bottom. Scrolling to reach the switches is fine; they're rarely used.
5. **Checks:**
   - with the panel open, on both phones, both dials are fully visible at scroll 0;
   - the panel's bottom is at least 8 pt above the bar's top, in Prism and outside;
   - the held dial's alpha is 1.0 while the rest is ≈ 0.4.

Then: 187 = the Hovering range, 188 = dismiss at the top.

**Added to 186** (review chat, 16:18, from the owner): remove the dimming (shade) when Prism's own settings
panel opens, so it matches the Sidekick's (185 removed it there).
- The panel route in `shell.dart` (`_showFloating`) has `barrierColor: Colors.transparent` and its own
  shade, which is the one to drop.
- Keep the panel closing on a tap outside it, as today.
- Don't touch other dialogs unless they're the same Prism panel; say which are left.
- **Add a check:** with Prism's panel open, nothing dims the screen behind it (a pixel outside the panel
  matches the same pixel with the panel closed, within a small tolerance).


**GO for 186** (review chat, 16:45), after the 185 phone results (S26 638/638; S25 633/643, all 10 WRONG
the tucked-tap cascade: "ignoring yes", the last touch "…, tucked", so the test's first tap only brought
the Sidekick out):
- **One test-only fix:** before the "a tap opens its blobs" section, bring the Sidekick out of tuck
  (untuck and wait for it to settle), so the test starts from a known state. Note it in the report as
  test-kit only.
- Then build, report and push as planned (badge 186, `askedTest = 'button'`), and send the link.
