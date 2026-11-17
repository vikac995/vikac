# Build 199: the Sidekick rests above the navigation bar

From the review chat (the lead, 17 November 2026, 12:24 and 12:50), part 2 of the owner's low-Sidekick
bug: "How low the Sidekick may rest: it shouldn't sit over the gesture/nav bar. Check the bottom clamp
uses the navigation-bar inset." "If it's two separate causes, 198 is the overlap and 199 the bottom
clamp."

**Read (sent before 198):** the three ways it comes to rest (going to its side, thrown, tucked) clamp
`lp.y` to the screen's full height less its window and 48 points. But `lp.y` counts from below the
status bar (the ~39-point offset measured in the 190s), and the navigation bar's inset is never used: so
its window could come down to about 9 points from the screen's bottom, its glass over the gesture bar.

**The fix:** the lowest its window's bottom may be is 48 points above the navigation bar, on the screen,
with its window's measured offset taken off; the highest is as before. A Sidekick left lower by an
earlier build rises to the lowest as it comes back. A check carries it to the very bottom.
