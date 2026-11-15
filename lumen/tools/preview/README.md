# The preview

Prism built for Linux and driven on a virtual screen. It runs everything Prism draws itself; it cannot
run anything Android does (the Sidekick, the timer over other apps, the floating sheets), so those
checks always come back "no answer" here and must be checked on the phone.

```
export PATH=/opt/sdk/flutter/bin:$PATH
cd lumen
flutter build linux --release -t lib/fit/main.dart
tools/preview/test.sh long      # expect 65 of 69 (3 Android-only measurements, 1 flick timing check)
tools/preview/test.sh buttons   # expect 68 of 69 (1 Android-only measurement)
tools/preview/test.sh leak      # the leak test: prints its LEAK TEST table (no Android readings here)
NOBUILD=1 tools/preview/shot.sh /tmp/a.png "xdotool mousemove 412 1738 click 1; sleep 1.2"
```

A check that could not be made because a step before it went wrong is listed as SKIPPED, with why,
and is not counted as wrong. The preview's saved state is in `/tmp/prism_*` files (blobs, look, density...). A "hold, then carry"
check sometimes misses once from timing in this slow preview: run again before believing it.
