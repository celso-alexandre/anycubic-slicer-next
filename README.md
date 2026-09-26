# Anycubic Slicer Next

[![GitHub release](https://img.shields.io/github/release/celso-alexandre/anycubic-slicer-next.svg)](https://github.com/celso-alexandre/anycubic-slicer-next/releases)
[![Build](https://github.com/celso-alexandre/anycubic-slicer-next/actions/workflows/build.yml/badge.svg)](https://github.com/celso-alexandre/anycubic-slicer-next/actions/workflows/build.yml)

Flatpak and AppImage of Anycubic Slicer Next, repacked from Anycubic's official Ubuntu 24.04
`.deb`. Unofficial, not affiliated with Anycubic.

This is a maintained fork of [develonrails/anycubic-slicer-next](https://github.com/develonrails/anycubic-slicer-next):
new Anycubic releases are picked up automatically (see [How updates work](#how-updates-work)).

## Flatpak (recommended, auto-updates)

Add the repo once; after that `flatpak update`, GNOME Software and KDE Discover keep it current.

```bash
flatpak install --user https://celso-alexandre.github.io/anycubic-slicer-next/com.anycubic.AnycubicSlicer.flatpakref
```

Use `--system` instead of `--user` to share one install between all users of the machine.
The runtime (GNOME 50) comes from Flathub.

Coming from a `.flatpak` bundle installed earlier? Uninstall it first — a bundle never
updates. Your settings under `~/.var/app/com.anycubic.AnycubicSlicer` are kept.

```bash
flatpak uninstall com.anycubic.AnycubicSlicer
```

A standalone `.flatpak` bundle is also attached to every [release](https://github.com/celso-alexandre/anycubic-slicer-next/releases).

## AppImage

Download from [releases](https://github.com/celso-alexandre/anycubic-slicer-next/releases),
mark it executable and run it. Needs a recent distro (glibc 2.38+) with WebKit2GTK 4.1,
GTK 3 and GStreamer installed — see [appimage/HOWTO.md](appimage/HOWTO.md).

## How updates work

- `.github/workflows/check-update.yml` runs weekly. When Anycubic's APT repo has a new
  `.deb`, `ci/check-update.sh` bumps the URL, checksum and version, and a single
  `auto/update-deb` pull request is opened (or updated, if one is already open).
- `.github/workflows/build.yml` builds both packages on every PR and push and
  smoke-tests them: the slicer is launched under Xvfb with a fresh profile and must load
  its fonts and stay up for 45 seconds.
- Merging to `main` with a version that has no release yet publishes the GitHub release
  and the signed flatpak repo on GitHub Pages.

## Building locally

```bash
ci/build-appimage.sh build                   # -> build/AnycubicSlicer-<version>-x86_64.AppImage
flatpak-builder --user --install --force-clean build-flatpak flatpak/com.anycubic.AnycubicSlicer.yml
ci/smoke-test.sh build/AnycubicSlicer-*-x86_64.AppImage --appimage-extract-and-run
```

The version lives in `flatpak/com.anycubic.AnycubicSlicer.metainfo.xml`; the `.deb` URL and
checksum in the Flatpak manifest. Both builds read them from there.

Credit to [develonrails](https://github.com/develonrails) for the original packaging.
