#!/bin/bash
# Starts the Linux build of Prism on a virtual screen, runs xdotool commands, and takes a screenshot.
# usage: tools/preview/shot.sh out.png "xdotool commands"   (run from lumen/; build first, see README.md)
# The window is 824x1830 pixels: 412x915 points at 2x. Prism's button is at 412,1738.
OUT=${1:-shot.png}
export DISPLAY=:99
pkill -f "Xvfb :99" 2>/dev/null; sleep 0.3
Xvfb :99 -screen 0 824x1830x24 >/dev/null 2>&1 &
sleep 1
export GDK_SCALE=2 LIBGL_ALWAYS_SOFTWARE=1 FLUTTER_ENGINE_SWITCHES=1 FLUTTER_ENGINE_SWITCH_1=enable-impeller=true
build/linux/x64/release/bundle/lumen > /tmp/prism_app.log 2>&1 &
APP=$!
sleep ${WAIT:-6}
WID=$(xdotool search --onlyvisible --pid $APP 2>/dev/null | head -1)
[ -n "$WID" ] && xdotool windowmove $WID 0 0 windowsize $WID 824 1830 && sleep 2
if [ -n "$2" ]; then eval "$2"; fi
import -window root "$OUT"
[ -z "$KEEP" ] && kill $APP 2>/dev/null
echo "saved $OUT"
