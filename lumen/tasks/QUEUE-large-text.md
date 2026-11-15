# Queued: long buttons at a large system text size (after step 2b)

Bug report from the owner on build 177, sent by the review chat, saved as given (15 November 2026). For
the queue, not for 2b's build: its own small build after 2b, or a separate commit if 2b is still in review.

It's likely their S25, likely with a larger system font size (the review chat has asked to confirm).

In the testing panel, the long pill buttons wrap onto two lines at a larger text scale:
- "Run the long test (about 20 min, hands off)" wraps "off)" onto a second line;
- the same for "…battery test (about 35 min)", "…leak test (about 11 min, hands off)" and "…button test
  (about 14 min, hands off)".

The second line is **left-aligned** against the pill's edge instead of centred, and the text has **no
horizontal inner padding**: "Run the glass settings test (about 20 min)" touches both ends of the pill.
"Run the test (about 2.7 min)" and "Run the hour-long test (overnight, silent)" fit. Screen width as usual,
about 412 pt.

**Fix:**
- these buttons, and every pill or button with free text: centred multi-line text, real horizontal
  padding, and a graceful two-line layout;
- check every panel at the largest Android font scale, and say what else breaks.

**Also, a standing test from now on:** a large-text pass in the preview (textScaler about 1.3 and the
maximum), with screenshots of each panel in the report. LESSONS.md entry: "Everything is checked at large
system text sizes, not only the default."
