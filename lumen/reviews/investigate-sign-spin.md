# Investigation: the rainbow triangle seems to spin past and swing back as the app drawer opens

Brief: `tasks/INVESTIGATE-sign-spin.md`. Investigation only: no build, no code changed. The angle was
recorded every frame in the preview with a temporary probe, which is removed again.

## Short answer

**The angle doesn't overshoot or reverse.** It goes from 0 to π in one move: 0.27° past, which can't be
seen. What the owner sees comes from the look itself:
- The "Window" triangle is equilateral, and its colour bands stand still behind it. So it looks
  exactly the same every 120°.
- Turned clockwise, the corner that seems to "point" moves three times as far the other way. Each 30°
  of real turn moves the point 90° anticlockwise.
- Half a turn (180°) therefore shows: down → right → up → left → down → right → up. That's one and a
  half rounds of the point, passing "up" (its end look) half way.
- The frames the review chat took from the recording match the spring frame by frame (table below).
  The "back to right" is the triangle at 142–165°, which looks exactly as it did at 22–45°.

**There is one real reversal, on another path:** the drawer flicked up from the button while the blobs
are out. More in "A real reversal" below.

## The four questions

1. **Is `_signSync` called twice?**
   - **From rest (the recording):** once. The probe shows one call (`drawer=true`, angle 0, speed 0),
     because `_setOpen(false)` returns at once when the blobs are already in.
   - **From open blobs, as the test does it:** twice in the same frame (target 0, then π). There's no
     frame between them, so the first does nothing (probe: the second starts at 60°, speed 0).
   - **From open blobs with a real flick:** twice, with the flick in between. See "A real reversal".
   - **Velocity:** it carries over on purpose (`SpringValue.animateTo` keeps it, so every animation
     can be interrupted).
2. **Is `Motions.spatial` underdamped?** Slightly: stiffness 700, damping ratio 0.9. That's 0.27° past
   on half a turn, 0.09° on a sixth. Not visible.
3. **Is `_signShot` running?** No. It runs only for looks that don't turn (Pearls, Lotus, Beam, Halo).
   Window and Petals turn.
4. **Is the angle wrapped?** No. `turn` goes straight in as `angle: -π/2 + turn` (`_ButtonSign` →
   `BlobSign.paint` → `_window`). Nothing takes it modulo anything. Only the shape repeats every 120°:
   - `_window` draws the triangle's corners at `a + π`, `a + π/3` and `a − π/3`;
   - its bands are upright and fixed to the glass;
   - `triangleNudge` is the same every 120°.

## The spring, frame by frame (60 fps, from rest to the app list)

| frame | ms | angle | turned this frame | looks like |
|---|---|---|---|---|
| 0 | 0 | 0° | – | down |
| 1 | 17 | 13° | 13° | down |
| 2 | 33 | 42° | 28° | right |
| 3 | 50 | 73° | 31° | up-left |
| 4 | 67 | 101° | 28° | left |
| 5 | 84 | 124° | 23° | down |
| 6–8 | 100–134 | 142–164° | 18°, 13°, 9° | right |
| 9–14 | 150–234 | 170–180° | 6° … 0.5° | up, settling slowly |

- **Against the recording:** the review chat's path was "down → right → up-left → left → right → slowly
  up", in about 0.25 s. That's this table with frame 5 (down, the fastest moment) missed.
- **The probe agrees:** in the preview, the same code read 170.49° at 150 ms, as frame 9 above. Every
  value went only upward, and the turn ended 0.27° past π.
  - The preview draws a frame only every 120–150 ms (software drawing), so it jumps 0 → 170° → 180°.
  - So the preview only confirms the values, not how smooth the turn looks.

**Why the blobs (a sixth of a turn) look fine:**
- 60° shows down → right → up and arrives at "up" without passing it.
- It turns at most 10° in a frame.

## A real reversal: the app list flicked open while the blobs are out

**What the code does:**
- A flick starts when the finger has moved 8 points. `_buttonMove` then calls `_setOpen(false)`, which
  tells the sign to go back to 0.
- The flick ends at the finger's lift. `_buttonUp` then calls `_setDrawer(true)`, which tells it to go
  to π, with the backward speed carried over.

**Computed** (same spring, from 60°), by how long the flick takes after its first 8 points:

| flick | the sign goes back to | then |
|---|---|---|
| 50 ms | about 36° | forward to 180° |
| 80 ms | about 20° | forward to 180° |
| 120 ms | about 8° | forward to 180° |

- **That is a real turn back of 25–50°,** then a forward turn of 160° or more.
- **The button test doesn't catch it,** because it opens the app list by calling `_setDrawer` and
  never flicks with the blobs out.
- **Not seen on a phone,** only computed. The owner's recording starts from rest, so it isn't this.

## How the test could catch it

All of these are in Prism's own button test, with no Android needed:

1. **The angle every frame:**
   - During each open and close (blobs, app list, the settings), listen to `_signTurn` and keep
     (frame time, angle, target).
   - **Reversal:** WRONG on any frame that turns more than 0.5° against the way to its target.
   - **Overshoot:** WRONG if it goes more than 1° past the target. (The spring's own 0.27° stays
     inside that.)
   - Write the path into the check, so a wrong one shows how.
   - **Today's code passes this from rest:** it really doesn't overshoot or reverse there.
2. **A real flick with the blobs out:**
   - Open the blobs, then flick up from the button with a real finger path (`Robot.drag`), instead of
     calling `_setDrawer(true)`.
   - With check 1, this fails today, as computed above. It's the one real reversal.
3. **What the owner saw: the end look shown on the way:**
   - For a look that repeats every 120° (`BlobSign.of(look).triangle`), a turn of more than 120° shows
     its end look before it arrives. That reads as passing it and coming back.
   - **Check:** WRONG if a single turn's span is over 120°. This needs no timing: start and target are
     enough, so the preview checks it as well as a phone.
   - Today's half turn (180°) fails it. The sixth (60°) passes.
4. **How far one frame turns it:**
   - Phone only: the preview's slow frames make this meaningless there, so SKIPPED with that reason.
   - The largest turn in a frame, written down. Today it's about 31° at 60 Hz and about 15° at 120 Hz.
   - Past 60° a triangle like this reads either way, and smaller steps read more surely.
   - A note, not a pass or fail, until the owner has seen what speed looks right.

## For the owner's intended behaviour (a note for the mock-up, not a decision)

The plan: rest 0, tap +60°, app list +120°, from the blobs the remaining 60°, always clockwise. Two
things the mock-up should show at real speed:
- **+120° from rest ends looking exactly like rest.** The Window triangle is the same every 120°, so
  "app list open" would look like "nothing open", pointing down. If the app list should look different
  from rest, the mock-up will show it.
- **A 120° turn still runs the point once round anticlockwise** (down → right → up → left → down), while
  the triangle turns clockwise. It doesn't pass its end look half way, so it shouldn't read as
  "swinging back". But it reads as spinning more than the tap's 60° does. "A bit slower" helps: the
  tap's at most 10° a frame reads as a plain turn.
- **"From the blobs, the remaining 60°" must not start back first.** The flick's first move shouldn't
  send the sign towards 0 (see "A real reversal").

## Where I could be wrong

1. **I haven't seen the recording.** I matched the review chat's description of its frames to the
   computed spring, and the match is close (one frame missed). If the recording shows the triangle at
   truly different angles, for example pointing left for several frames in a row, something else is
   going on.
2. **A slow frame on the phone,** for example as the app list builds, would make one step bigger. The
   angle follows the clock, not the frames. That changes how big the jumps look, not their direction.
3. **The flick reversal is computed, not seen.** If `_moved` came later than the 8 points I read, the
   turn back would be smaller.
4. **The phones run at 120 Hz;** the recording may be 60 fps. What the owner's eye saw is smoother than
   the frames, but it shows the same looks in the same order.
