# Build 198: the Sidekick's fan, never squeezed

From the review chat (the lead, 17 November 2026, 12:24 and 12:50). A bug from the owner (screenshot,
S26, gesture navigation, 13:24, probably 196): "the Sidekick resting very low at the right edge (its
centre about level with Prism's bottom bar, partly over the gesture bar), tap → the fan opens up-left but
the blobs are cramped and OVERLAP each other: the 5th (blue) sits half under the scan blob, the timer
(orange) half under the dumbbell (purple); WhatsApp is fine."

1. "The fan when the Sidekick is near the bottom: the arc seems squeezed (angles or radius clamped) so
   neighbours collide. Rule: blobs never overlap; at least the same gap as in the middle of the screen.
   If the arc can't fit, widen the radius or swing the arc further up, as it already does near the top
   ("turned")."
2. "How low the Sidekick may rest: it shouldn't sit over the gesture/nav bar. Check the bottom clamp uses
   the navigation-bar inset."

"Read first and tell me the cause(s) before building; if it's two separate causes, 198 is the overlap
and 199 the bottom clamp. Then the app list, the test store and search follow, renumbered after it."

**Read (sent 13:0x):** two separate causes. 198 is the overlap (the menu's last resort pushed each seat
onto the screen on its own; the fan's search stopped at 1.4 times its size). 199 is the bottom clamp
(in the window's own place, which starts below the status bar, against the full screen's height, with
no navigation-bar inset). The app list becomes 200, the test store 201, search 202.
