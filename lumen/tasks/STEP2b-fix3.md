# Step 2b fix 3 (build 182): the S26's one missed tap

From the review chat, 16 November 2026, after build 181 was already pushed. It asked for this "in
181"; 181 had gone, so it is 182, on top of 181 (the rule: what is asked once a build is out goes
into the next one).

> The S26 report for 180 is in (SM-S942B): 600 right, 18 wrong, out of 618.
>
> **The same two stale checks as on the S25,** 4/4 each.
>
> **Plus one round where the Sidekick's tap didn't open its blobs,** which then cascaded. The S25
> didn't have this. Lines:
> - "sidekick: a tap opens its blobs" (1 of 4)
> - "as many blobs as its menu has" (1 of 4) [0 shown, 5 in its menu]
> - "holding a blob brings its small menu" (1 of 4) [small menu -1; the Sidekick at 400 points from
>   the top; blobs ?]
> - "a tap beside it puts the small menu away" (1 of 4)
> - "pressed on Remove and let go on Change…" (1 of 4) [small menu -1, its menu action:4 action:3
>   action:2 action:1 screen:0, Prism asked 0 times]
> - "menu hold / menu outside / menu popSlide: Android could do it" (2 of 2, 2 of 2, 1) [the lens's
>   menu is not open]
>
> **Memory on the S26:** about 950 MB total; graphics 560–590 MB, against about 390 on the S25.
>
> **Please, in 181:**
> - Find out why that one tap didn't open the blobs: a timing race with the previous step, a
>   `pressed` state left stuck (the old raise path?), or the Dot not attached. If raise could leave
>   `pressed` set, option (a) may fix it as a side effect. Say which.
> - Make the "a tap opens its blobs" check report the Dot's state when it fails (attached, pressed,
>   guest, menu state), so the next failure is explained.
>
> Don't add anything else to 181.
