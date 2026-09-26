#!/usr/bin/env bash
# Bring the manifest up to date with
#   - the newest .deb in Anycubic's APT repo (URL, checksum, version in the metainfo),
#   - and, only together with a new .deb, the newest stable GNOME runtime on Flathub
#     (numbered branches only, no beta), so a runtime move is always tested with a release.
# Prints a one-line summary of what changed and exits 0, or exits 3 if nothing did.
# Needs flatpak with a --user flathub remote for the runtime check.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
MANIFEST="$ROOT/flatpak/com.anycubic.AnycubicSlicer.yml"
METAINFO="$ROOT/flatpak/com.anycubic.AnycubicSlicer.metainfo.xml"
REPO=https://cdn-universe-slicer.anycubic.com/prod
CHANGES=()

# --- .deb ---
FILENAME=$(curl -fsS "$REPO/dists/noble/main/binary-amd64/Packages" | awk '/^Filename:/ {print $2; exit}')
URL="$REPO/$FILENAME"
if grep -qF "url: $URL" "$MANIFEST"; then
  echo "up to date: $(basename "$URL")" >&2; exit 3
fi
# The deb Version field is mangled (2.0.0.5 ships as 2.0.06); the filename carries the real one
VERSION=$(sed -nE 's/.*[_-]v?([0-9]+(\.[0-9]+){2,3})[-_].*/\1/p' <<<"$(basename "$FILENAME")")
[ -n "$VERSION" ] || { echo "cannot parse version from $FILENAME" >&2; exit 1; }
STAMP=$(grep -oE '20[0-9]{6}' <<<"$FILENAME" | head -1 || true)
DATE=${STAMP:+${STAMP:0:4}-${STAMP:4:2}-${STAMP:6:2}}
DATE=${DATE:-$(date -u +%F)}
SHA=$(curl -fsSL "$URL" | sha256sum | cut -d' ' -f1)

sed -i -E "s|(^\s*url: ).*\.deb|\1$URL|; s|(^\s*sha256: )[0-9a-f]{64}|\1$SHA|" "$MANIFEST"
sed -i -E "s|<release version=\"[^\"]*\" date=\"[^\"]*\"/>|<release version=\"$VERSION\" date=\"$DATE\"/>|" "$METAINFO"
CHANGES+=("Anycubic Slicer Next $VERSION")

# --- GNOME runtime, riding along with the new release ---
CURRENT=$(grep -oP "^runtime-version:\s*'?\K[0-9]+" "$MANIFEST")
LATEST=$(flatpak remote-ls --user flathub --runtime --columns=application,branch |
  awk '$1 == "org.gnome.Platform" && $2 ~ /^[0-9]+$/ {print $2}' | sort -n | tail -1)
[ -n "$LATEST" ] || { echo "cannot list GNOME runtimes on flathub" >&2; exit 1; }
if [ "$LATEST" -gt "$CURRENT" ]; then
  sed -i -E "s|^(runtime-version:\s*)'?[0-9]+'?|\1'$LATEST'|" "$MANIFEST"
  CHANGES+=("GNOME $LATEST runtime")
fi

(IFS=,; echo "${CHANGES[*]}" | sed 's/,/, /g')
