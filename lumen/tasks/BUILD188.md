# Build 188: the dials, and one menu at a time

From the review chat (16 November 2026, 18:05): the owner's feedback on 187 (videos 19:00, S25 probably,
Prism in front): "better but still not good". Prepare it, build and push straight away: the owner will
skip the full 187 test.

1. **The dials vanish while held.**
   - In the video, the moment a finger is on a dial, the whole "Where it rests" block disappears. Only the
     faint panel and the app behind remain; the dial numbers are gone, with the touch dot on empty space.
   - The solid block from 187 is evidently not drawn on the phone, or it's drawn at the panel's alpha or
     behind it. Find out why by reading.
   - Make the title and both dials draw fully solid on top while held.
   - The check said "drawn solid at 1.0": find out why it passed while the phone shows nothing. It likely
     checks a state value rather than what is drawn. Make it check the pixels.
2. **The dials overflow their containers.**
   - The dial's tick marks run past the bottom edge of their rounded pill (seen at rest too, under "5"
     and "13").
   - Fit the ticks inside the pill, with padding, at every font scale.
3. **Swap, the owner's choice: only one menu open at a time.**
   - With Prism's blobs open, a tap on the Sidekick closes Prism's blobs **and** opens the Sidekick's, in
     one tap.
   - The reverse too: with the Sidekick's blobs open, a tap on Prism's triangle closes them and opens
     Prism's.
   - The same for a Sidekick hold (its panel) while Prism's blobs are open: close Prism's.
   - The triangle follows its rule.
   - **Checks:** never both menus open at once, in either direction; one tap does the swap.
4. **The farthest Hovering position:** not in this build. It's the Hovering range, which moves to
   **189**: closest 75% past the edge, farthest about half a Sidekick, as today. Dismiss at the top moves
   to **190**.

Report as usual, and send the link.
