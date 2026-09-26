#!/usr/bin/env bash
# Prove the slicer really starts: launch it on a headless X server with a fresh profile
# and require, in order,
#   1. the first-run "Setup Wizard" window appears (main frame initialised, WebKit up),
#   2. its fonts loaded (resources found),
#   3. it is still running, window still up, $SMOKE_SETTLE seconds later,
#   4. the screen is not blank (catches the black-WebKit rendering failure).
# A screenshot is left at $SMOKE_SCREENSHOT either way.
# Usage: ci/smoke-test.sh <command...>
set -uo pipefail

WINDOW=${SMOKE_WINDOW:-Setup Wizard}
WAIT=${SMOKE_WAIT:-120}
SETTLE=${SMOKE_SETTLE:-15}
SHOT=$(realpath -m "${SMOKE_SCREENSHOT:-smoke-test.png}")
MIN_COLORS=${SMOKE_MIN_COLORS:-256}
HERE=$(cd "$(dirname "$0")" && pwd)
LOG=$(mktemp)

# Fresh profile, like a first launch; keep --user flatpak installs reachable
export FLATPAK_USER_DIR=${FLATPAK_USER_DIR:-$HOME/.local/share/flatpak}
export HOME=$(mktemp -d)
mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.cache"

export DISPLAY=:$((100 + RANDOM % 100))
Xvfb "$DISPLAY" -screen 0 1920x1080x24 -nolisten tcp >/dev/null 2>&1 &
XVFB=$!
setsid "$@" >"$LOG" 2>&1 &
APP=$!

finish() {
  import -window root "$SHOT" 2>/dev/null && echo "screenshot: $SHOT"
  kill -9 -- -"$APP" 2>/dev/null
  kill "$XVFB" 2>/dev/null
  echo "--- last lines of the slicer's output"
  tail -25 "$LOG"
  echo "--- $1"
  [[ $1 == PASS* ]]
  exit
}
alive() { kill -0 "$APP" 2>/dev/null; }
has_window() { python3 "$HERE/x11-windows.py" 2>/dev/null | grep -qF " $WINDOW"; }

for ((t = 0; t < WAIT; t++)); do
  alive || finish "FAIL: slicer exited after ${t}s before showing '$WINDOW'"
  has_window && break
  sleep 1
done
has_window || finish "FAIL: no '$WINDOW' window after ${WAIT}s"
echo "'$WINDOW' window up after ${t}s"

FONTS=$(grep -c 'add font of .* returns 1' "$LOG")
[ "$FONTS" -gt 0 ] || finish "FAIL: no font loaded (resources not found?)"

sleep "$SETTLE"
alive || finish "FAIL: slicer died within ${SETTLE}s of showing '$WINDOW'"
has_window || finish "FAIL: '$WINDOW' window vanished within ${SETTLE}s"

import -window root "$SHOT" || finish "FAIL: could not take screenshot"
COLORS=$(identify -format %k "$SHOT")
[ "$COLORS" -ge "$MIN_COLORS" ] || finish "FAIL: screen nearly blank ($COLORS colors) — UI did not render"

finish "PASS: '$WINDOW' up after ${t}s, alive ${SETTLE}s later, $FONTS fonts, $COLORS colors on screen"
