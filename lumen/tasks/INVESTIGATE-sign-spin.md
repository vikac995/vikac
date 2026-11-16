# Investigation (no build): the rainbow triangle turns too far as the app drawer opens

From the review chat, 16 November 2026. Investigate only, no build.

> New bug from the owner (screen recording, 182, Prism look with the rainbow triangle).
>
> **What happens:**
> - At rest, the triangle is drawn pointing down.
> - Opening the app drawer with Prism's button: it turns past about 270°, swings back and stops
>   pointing up (π). Closing does the same in reverse.
> - I extracted frames at 60 fps. Over about 0.25 s the path is: down → right → up-left → left
>   (pointing left), then back to right, and slowly to up.
> - Tapping (π/3, the blobs) is fine.
>
> **What to look at:** shell.dart `_signSync`, where `_signTurn.animateTo(now==2||_panelOpen ? π :
> (now==1 ? π/3 : 0), spring: Motions.spatial)`.
> - Is `_signSync` called twice in a row as the drawer opens, e.g. now=1 and then now=2, or with a
>   second target? Does the velocity carry over?
> - Is `Motions.spatial` underdamped?
> - Is `_signShot` also running?
> - Is the angle wrapped somewhere?
>
> Please report the cause, and how the test could catch it: record the angle every frame, and fail
> on any overshoot past the target or any reversal.
>
> **The owner's intended behaviour** (awaiting their OK on my mock-up, don't build yet): rest at 0
> (pointing down); tap +60°; drawer +120° (a bit slower); drawer from open blobs, the remaining 60°.
> Always clockwise, no overshoot, and closing reverses.
