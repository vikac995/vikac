# Build 187: the dials, fixed again

From the review chat (16 November 2026, 17:14): the owner's feedback on 186 (video 18:12, by hand).
Prepare it on a local branch and hold the push: the owner may still be running the 186 button test.

1. **"It stays transparent for much too long after I let go."** The 0.6 s hold is wrong for the owner.
   - New rule: let go of a dial and the panel goes back to solid right away, on the quick spring (about
     0.15–0.2 s, the snappy rule, no hold). The Sidekick goes back on the same timing.
   - Set `SETTLE_MS` to 0, or to the smallest value that still removes the hard flash, no more than about
     120 ms. Explain the choice in the report.
   - Accept that very fast strokes may show a slight dip between them. A hard flash is still wrong.
2. **"The dials turn transparent. They shouldn't."**
   - While any dial is held, the whole "Where it rests" section stays fully solid: both dials and their
     labels, plus the section title. Only the rest of the panel (body, Labels, Icons, Colours, Look, the
     switches) goes to 0.4.
   - The solid section needs its own backing, so it reads as one solid block.
3. **Checks:**
   - With a dial held, both dials' alpha is 1.0 and the rest is ≈ 0.4.
   - After let-go, the panel is above 0.97 within 300 ms.
   - Keep the 1.5 s drag check as it is (≤ 0.45 while the finger is down).

**Renumbering:** 187 = this fix, 188 = the Hovering range, 189 = dismiss at the top.

**Added to 187** (review chat, 17:38): the 186 phone run on the S26 (658/662) had one WRONG, 4 of 4 times:
"sidekick panel: dragged by hand with the panel open, the Sidekick moves and the panel follows it" [the
Sidekick moved -119 points (dragged -120), the panel 0; open true]. In 185 it passed as "as tall as the
screen allows". Confirm by reading, and fix whichever side is wrong: the check's exemption, or real
following if the panel is in fact shorter than its allowed space. (Waiting for the S25 report before the
go.)

**GO for 187** (review chat, 17:38–17:44), after the 186 S25 run (654/662). Two WRONG, each 4 of 4: the
follow check (as on the S26), and "both dials on the screen as it opens, without scrolling": box
[127.8, 56, 275.6, 692.7] (bottom 748.7), dials at y 718.8, h 52 (bottom 770.8), so cut off by about
22 pt on the S25 (the S26 passes). Added to 187:
- **Both dials fit on the S25 at font scale 1, with at least 8 pt to spare**: about 30 pt saved above the
  dials. Tighten the vertical spacing between sections first; only if needed, slightly smaller Look
  tiles or segment rows. Don't remove anything or change the order. The report says how much room is
  left on each phone.
- **The follow check:** confirm the cause, then fix the exemption or the following (done: the exemption).
- **Test kit:** both 186 reports show "untuck x4 … NOT DONE: null" in the floating-lens table. Make the op
  report what it did ("was tucked: yes/no, brought out"), so it shows as done.
- FYI: a phone call on the S26 during the 186 run (21 min 11 s against 21 min 6 s); no sign it disturbed
  anything.
- Then build, report, push, and send the link.
