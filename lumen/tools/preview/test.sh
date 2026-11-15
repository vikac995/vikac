#!/bin/bash
# Runs one of Prism's own automatic tests in the preview and prints the result.
# usage: tools/preview/test.sh long     (the long test; about 8 minutes)
#        tools/preview/test.sh buttons  (the button test, one round; about 2 minutes)
#        tools/preview/test.sh leak     (the leak test; about 5 minutes here)
# Run from lumen/ after: flutter build linux --release -t lib/fit/main.dart
export DISPLAY=:99 GDK_SCALE=2 LIBGL_ALWAYS_SOFTWARE=1 FLUTTER_ENGINE_SWITCHES=1 FLUTTER_ENGINE_SWITCH_1=enable-impeller=true
pgrep -f "Xvfb :99" >/dev/null || (Xvfb :99 -screen 0 824x1830x24 >/dev/null 2>&1 &)
sleep 1
pkill -f bundle/lumen; sleep 1
rm -f /tmp/prism_long_test.txt
if [ "$1" = "buttons" ]; then
  PRISM_BUTTON_TEST=1 timeout 420 build/linux/x64/release/bundle/lumen > /tmp/prism_test.log 2>&1 &
elif [ "$1" = "leak" ]; then
  PRISM_LEAK_TEST=1 timeout 900 build/linux/x64/release/bundle/lumen > /tmp/prism_test.log 2>&1 &
else
  PRISM_LONG_TEST=1 timeout 590 build/linux/x64/release/bundle/lumen > /tmp/prism_test.log 2>&1 &
fi
sleep 5
W=$(xdotool search --onlyvisible --name lumen | head -1)
xdotool windowmove $W 0 0 windowsize $W 824 1830
for i in $(seq 1 120); do
  sleep 5
  if [ "$1" = "buttons" ] || [ "$1" = "leak" ]; then
    grep -q "CHECKS" /tmp/prism_long_test.txt 2>/dev/null && ! grep -q UNFINISHED /tmp/prism_long_test.txt && break
  else
    grep -qa "CHECKS:" /tmp/prism_test.log && break
  fi
  pgrep -f bundle/lumen >/dev/null || break
done
pkill -f bundle/lumen
if [ "$1" = "leak" ]; then grep -n "CHECKS\|WRONG\|SKIPPED" /tmp/prism_long_test.txt; sed -n '/^LEAK TEST/,/^$/p' /tmp/prism_long_test.txt;
elif [ "$1" = "buttons" ]; then grep -n "CHECKS\|WRONG\|SKIPPED" /tmp/prism_long_test.txt; else grep -a "CHECKS:\|WRONG\|SKIPPED" /tmp/prism_test.log; fi
