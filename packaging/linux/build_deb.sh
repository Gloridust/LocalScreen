#!/usr/bin/env bash
# Packs the Flutter Linux release bundle into a .deb.
#
#   packaging/linux/build_deb.sh [output-dir]
#
# Run `flutter build linux --release` first. Needs dpkg-dev, fakeroot and
# rsvg-convert (librsvg2-bin).
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$(mkdir -p "${1:-$root/build}" && cd "${1:-$root/build}" && pwd)"
bundle="$root/build/linux/x64/release/bundle"
app_id="dev.localscreen.localscreen"
maintainer="${DEB_MAINTAINER:-LocalScreen <noreply@localscreen.dev>}"

[[ -x "$bundle/localscreen" ]] || {
  echo "No release bundle at $bundle; run 'flutter build linux --release' first." >&2
  exit 1
}

version="$(sed -n 's/^version: *\([^+]*\).*/\1/p' "$root/pubspec.yaml")"
arch="$(dpkg --print-architecture)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pkg="$work/pkg"

# The bundle keeps its layout (binary next to lib/ and data/) under /opt.
install -d "$pkg/opt/localscreen" "$pkg/usr/bin" "$pkg/usr/share/applications"
cp -a "$bundle/." "$pkg/opt/localscreen/"
ln -s /opt/localscreen/localscreen "$pkg/usr/bin/localscreen"
install -m 644 "$root/packaging/linux/$app_id.desktop" "$pkg/usr/share/applications/"

svg="$root/assets/icon/localscreen.svg"
for size in 16 24 32 48 64 128 256 512; do
  dir="$pkg/usr/share/icons/hicolor/${size}x${size}/apps"
  install -d "$dir"
  rsvg-convert -w "$size" -h "$size" "$svg" -o "$dir/$app_id.png"
done
install -D -m 644 "$svg" "$pkg/usr/share/icons/hicolor/scalable/apps/$app_id.svg"

install -D -m 644 /dev/stdin "$pkg/usr/share/doc/localscreen/copyright" <<COPYRIGHT
LocalScreen $version
Source: https://github.com/Gloridust/LocalScreen
COPYRIGHT

# Library dependencies are read from the binaries themselves.
mkdir -p "$work/debian"
printf 'Source: localscreen\n\nPackage: localscreen\nArchitecture: %s\n' "$arch" > "$work/debian/control"
depends="$(
  cd "$work" &&
    find pkg/opt/localscreen -type f \( -name '*.so' -o -name localscreen \) -print0 |
    xargs -0 dpkg-shlibdeps -O --ignore-missing-info -lpkg/opt/localscreen/lib 2>/dev/null |
    sed -n 's/^shlibs:Depends=//p'
)"

install -d "$pkg/DEBIAN"
cat > "$pkg/DEBIAN/control" <<CONTROL
Package: localscreen
Version: $version
Section: utils
Priority: optional
Architecture: $arch
Maintainer: $maintainer
Installed-Size: $(du -sk "$pkg" | cut -f1)
Depends: $depends
Recommends: xdg-desktop-portal, pipewire, gstreamer1.0-tools, gstreamer1.0-pipewire
Homepage: https://github.com/Gloridust/LocalScreen
Description: Turn any device on your LAN into a second screen
 LocalScreen finds devices on the local network and uses one of them as an
 extra display, with PIN pairing and low-latency video over WebRTC.
CONTROL

find "$pkg" -type d -exec chmod 755 {} +
find "$pkg/usr/share" -type f -exec chmod 644 {} +
deb="$out/localscreen_${version}_${arch}.deb"
fakeroot dpkg-deb --build --root-owner-group -Zxz "$pkg" "$deb" >/dev/null
echo "$deb"
