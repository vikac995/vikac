# Step 2a (build 176): the Sidekick's settings move to Android

Brief from the review chat, saved as it was given (15 November 2026). The plan it builds on is
`STEP2-plan.md`.

The plan is good, and the owner has answered two of the four questions:
- **Back:** measure first, as you proposed (2a's keyboard probe decides between A and B).
- **Timer:** leave it exactly as it is. The owner will rework the whole workout flow later, after the
  basics are done.
- **Still open:** the way back when both switches are off, and where the panel sits. I've given the
  owner a mock-up of beside, centred and bottom. Don't build any panel UI yet.

**Go ahead with 2a (build 176)** as planned, since it depends on neither open question:
- the settings move to Android, with recorder lines for every value;
- Prism's panel keeps its Sidekick part, writing through Android;
- the Icons split;
- the palette sent;
- the keyboard probe;
- bc55710's guard.

Nothing should look different. Its report needs "Where I could be wrong", and the keyboard probe must say
plainly what it measured and how.

**Your three workflow rules: agreed.** Add them to LESSONS.md:
- every brief saved to tasks/ before work starts;
- anything asked mid-build goes into the next commit, and the reply says so;
- at most one behaviour change and one investigation per build.

Save this brief as `lumen/tasks/STEP2a.md`.
