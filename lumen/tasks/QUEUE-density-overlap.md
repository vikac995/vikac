# Queued: apps drawn twice while the app list's density changes (bug, seen in build 178)

From the owner, sent by the review chat, saved as given (16 November 2026). Build nothing until build
178's phone run is back.

During the app list's density change, apps are drawn twice. The owner's screenshot shows Bolt on top of
BMR calculator, and Calendar on top of Calculator, both labels overlapping. It's the ChatGPT Part 7
finding A4: `_FlowPainter` draws the outgoing and incoming tile of an app that changes rows in the same
frame (`out = 1 - t*2.4`, `up` starting at t=0.3). DESIGN: "Nothing is ever drawn twice during a change."

**Fix:** each app moves straight from its old rect to its new one, one copy, no cross-fade (the mock-up
does exactly this). Also the interrupted-retarget jump (A4's second half).
