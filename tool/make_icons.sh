#!/usr/bin/env bash
# Regenerates every platform's app icon from assets/icon/localscreen.svg.
# Needs rsvg-convert (librsvg2-bin) and icotool (icoutils).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
svg="$root/assets/icon/localscreen.svg"
render() { rsvg-convert -w "$1" -h "$1" "$svg" -o "$2"; }

# Android launcher icons.
res="$root/android/app/src/main/res"
for spec in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  render "${spec#*:}" "$res/mipmap-${spec%%:*}/ic_launcher.png"
done

# macOS icon set.
set_dir="$root/macos/Runner/Assets.xcassets/AppIcon.appiconset"
for size in 16 32 64 128 256 512 1024; do
  render "$size" "$set_dir/app_icon_$size.png"
done

# Windows icon.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for size in 16 24 32 48 64 256; do
  render "$size" "$tmp/$size.png"
done
icotool -c -o "$root/windows/runner/resources/app_icon.ico" "$tmp"/{16,24,32,48,64,256}.png

echo "Icons regenerated from ${svg#"$root"/}"
