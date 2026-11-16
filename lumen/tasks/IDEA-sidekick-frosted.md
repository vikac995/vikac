# Idea, not to build yet: the Sidekick's panel frosted

From the owner, sent by the review chat (16 November 2026). A mock-up is pending the owner's choice; the
review chat confirms before anything is built.

The Sidekick's panel could become frosted rather than solid (about 75% with a backdrop blur, the shade
lighter at about 25%), with a solid fallback where window blur is unavailable.

(If built: Android's window blur, `FLAG_BLUR_BEHIND` / `setBlurBehindRadius`, Android 12 and later, where
the phone allows it; DESIGN.md §8 has glass only on things that float over content, which this panel
does. Graphics memory is the roadmap's next target: measure it.)
