#!/usr/bin/env bash
# Build the AppImage from the same .deb the Flatpak manifest pins.
# Usage: ci/build-appimage.sh [workdir]   -> <workdir>/AnycubicSlicer-<version>-x86_64.AppImage
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
MANIFEST="$ROOT/flatpak/com.anycubic.AnycubicSlicer.yml"
WORK=$(realpath -m "${1:-$ROOT/build-appimage}")

field() { grep -E "^\s*$1:" "$MANIFEST" | head -1 | sed -E "s/^\s*$1:\s*\"?([^\"\r]*)\"?\r?$/\1/"; }
DEB_URL=$(field url)
DEB_SHA=$(field sha256)
VERSION=$(grep -oPm1 '<release version="\K[^"]+' "$ROOT/flatpak/com.anycubic.AnycubicSlicer.metainfo.xml")

rm -rf "$WORK/AppDir" "$WORK/extracted"
mkdir -p "$WORK/extracted" "$WORK/AppDir"
cd "$WORK"

[ -f anycubicslicernext.deb ] && echo "$DEB_SHA  anycubicslicernext.deb" | sha256sum -c --quiet \
  || curl -fL -o anycubicslicernext.deb "$DEB_URL"
echo "$DEB_SHA  anycubicslicernext.deb" | sha256sum -c

(cd extracted && ar x ../anycubicslicernext.deb && tar xf data.tar.*)

cp -r extracted/usr/* AppDir/
chmod +x AppDir/lib/*.so
cp -r AppDir/share/AnycubicSlicerNext/resources AppDir/
cp AppDir/share/applications/AnycubicSlicer.desktop AppDir/
sed -i 's|^Icon=.*|Icon=AnycubicSlicer|' AppDir/AnycubicSlicer.desktop
cp AppDir/resources/images/AnycubicSlicer_192px.png AppDir/AnycubicSlicer.png
install -m755 "$ROOT/appimage/AppRun" AppDir/AppRun

# Unpack appimagetool ourselves: running it directly needs FUSE, and binfmt hooks
# such as AppImageLauncher hijack even --appimage-extract-and-run.
if [ ! -x appimagetool/AppRun ]; then
  curl -fL -o appimagetool.AppImage https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  OFFSET=$(python3 -c 'import struct,sys; h=open(sys.argv[1],"rb").read(64); print(struct.unpack_from("<Q",h,0x28)[0]+struct.unpack_from("<H",h,0x3A)[0]*struct.unpack_from("<H",h,0x3C)[0])' appimagetool.AppImage)
  rm -rf appimagetool && unsquashfs -q -o "$OFFSET" -d appimagetool appimagetool.AppImage
fi
OUT="AnycubicSlicer-$VERSION-x86_64.AppImage"
ARCH=x86_64 appimagetool/AppRun --no-appstream AppDir "$OUT"
echo "$WORK/$OUT"
