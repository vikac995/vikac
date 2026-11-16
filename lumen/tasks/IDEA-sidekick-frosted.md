# Idea, not to build yet: the Sidekick's panel frosted

From the owner, sent by the review chat (16 November 2026). A mock-up is pending the owner's choice; the
review chat confirms before anything is built.

The Sidekick's panel could become frosted rather than solid (about 75% with a backdrop blur, the shade
lighter at about 25%), with a solid fallback where window blur is unavailable.

(If built: Android's window blur, `FLAG_BLUR_BEHIND` / `setBlurBehindRadius`, Android 12 and later, where
the phone allows it; DESIGN.md §8 has glass only on things that float over content, which this panel
does. Graphics memory is the roadmap's next target: measure it.)

**The Sidekick under a see-through panel** (from the review chat, after build 181):
- **What 181 does:** where the panel covers the Sidekick, it draws a stand-in of it (the Sidekick's own
  drawing). The real Sidekick's window stays underneath, so it isn't taken off and put back, which was the
  blink. On today's solid panel, the real one doesn't show.
- **What frosting changes:** behind a frosted or see-through surface, the real Sidekick would show
  through, blurred, next to its stand-in.
- **So, when the panel is redesigned, one of:**
  - the stand-in covers the Sidekick completely, on an opaque patch of its own;
  - the panel stays opaque around the Sidekick (the hole and a ring round it);
  - the blur behind is made to leave the Sidekick out.

  The mock-up decides which.
