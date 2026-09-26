#!/usr/bin/env bash
# Launch the slicer headless under Xvfb and require that it loads its fonts and is
# still alive after $SMOKE_SECONDS (default 45). Usage: ci/smoke-test.sh <command...>
set -uo pipefail
SECS=${SMOKE_SECONDS:-45}
LOG=$(mktemp)
export HOME=${SMOKE_HOME:-$(mktemp -d)}   # fresh profile, like a first launch
mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.cache"

xvfb-run -a -s "-screen 0 1920x1080x24" timeout -k 10 "$SECS" "$@" >"$LOG" 2>&1
RC=$?
tail -40 "$LOG"
echo "--- exit code $RC (124/137 = still running at timeout)"

FONTS_OK=$(grep -c 'add font of .* returns 1' "$LOG")
if [ "$RC" -ne 124 ] && [ "$RC" -ne 137 ]; then
  echo "FAIL: slicer exited before ${SECS}s"; exit 1
elif [ "$FONTS_OK" -eq 0 ]; then
  echo "FAIL: no font loaded (resources not found?)"; exit 1
fi
echo "PASS: alive after ${SECS}s, $FONTS_OK fonts loaded"
