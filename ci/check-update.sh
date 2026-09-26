#!/usr/bin/env bash
# Point the manifest and metainfo at the newest .deb in Anycubic's APT repo.
# Prints the new version and exits 0 if something changed, exits 3 if already current.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
MANIFEST="$ROOT/flatpak/com.anycubic.AnycubicSlicer.yml"
METAINFO="$ROOT/flatpak/com.anycubic.AnycubicSlicer.metainfo.xml"
REPO=https://cdn-universe-slicer.anycubic.com/prod

FILENAME=$(curl -fsS "$REPO/dists/noble/main/binary-amd64/Packages" | awk '/^Filename:/ {print $2; exit}')
URL="$REPO/$FILENAME"
if grep -qF "url: $URL" "$MANIFEST"; then
  echo "already at $URL" >&2; exit 3
fi

# The deb Version field is mangled (2.0.0.5 ships as 2.0.06); the filename carries the real one
VERSION=$(sed -nE 's/.*[_-]v?([0-9]+(\.[0-9]+){2,3})[-_].*/\1/p' <<<"$(basename "$FILENAME")")
STAMP=$(grep -oE '20[0-9]{6}' <<<"$FILENAME" | head -1 || true)
DATE=${STAMP:+${STAMP:0:4}-${STAMP:4:2}-${STAMP:6:2}}
DATE=${DATE:-$(date -u +%F)}
[ -n "$VERSION" ] || { echo "cannot parse version from $FILENAME" >&2; exit 1; }

SHA=$(curl -fsSL "$URL" | sha256sum | cut -d' ' -f1)

sed -i -E "s|(^\s*url: ).*\.deb|\1$URL|; s|(^\s*sha256: )[0-9a-f]{64}|\1$SHA|" "$MANIFEST"
sed -i -E "s|<release version=\"[^\"]*\" date=\"[^\"]*\"/>|<release version=\"$VERSION\" date=\"$DATE\"/>|" "$METAINFO"
echo "$VERSION"
