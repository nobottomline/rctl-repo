#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
source "$ROOT/scripts/validate-package.sh"
fail() { printf '%s\n' "$*" >&2; exit 1; }
fixture() {
  local arch="$1" name="rctl_1.0.0_${1}.deb" tree="$WORK/input" sha
  rm -rf "$tree" "$WORK/assets"
  mkdir -p "$tree/DEBIAN" "$WORK/assets"
  printf 'Package: com.greatlove.rctl\nVersion: 1.0.0\nArchitecture: %s\nMaintainer: Test <test@example.invalid>\nDescription: test fixture\n' "$arch" > "$tree/DEBIAN/control"
  if [[ "$arch" == iphoneos-arm64 ]]; then
    mkdir -p "$tree/var/jb/usr/local/share/rctl/web"
    printf 'test' > "$tree/var/jb/usr/local/share/rctl/web/index.html"
    printf 'Depends: ellekit, firmware (>= 15.0)\n' >> "$tree/DEBIAN/control"
    printf "#!/bin/sh\nRCTL_PREFIX='/var/jb'\n" > "$tree/DEBIAN/postinst"
    chmod 755 "$tree/DEBIAN/postinst"
  else
    printf 'Depends: mobilesubstrate, firmware (>= 14.0)\n' >> "$tree/DEBIAN/control"
    mkdir -p "$tree/var/mobile/rctl"
    printf 'test' > "$tree/var/mobile/rctl/index.html"
  fi
  dpkg-deb --build "$tree" "$WORK/assets/$name" >/dev/null
  sha="$(sha256sum "$WORK/assets/$name" | awk '{print $1}')"
  printf '%s  %s\n' "$sha" "$name" > "$WORK/assets/SHA256SUMS"
}
check() {
  local expected="$1" arch="$2" result=0
  rm -rf "$WORK/extracted"
  (validate_package "$WORK/assets" v1.0.0 "$arch" "$WORK/extracted") > "$WORK/result" 2>&1 || result=$?
  if [[ "$expected" == pass && "$result" != 0 ]] || [[ "$expected" == fail && "$result" == 0 ]]; then
    cat "$WORK/result" >&2
    fail "unexpected result: $expected/$arch"
  fi
}
repack() {
  local arch="$1" name="rctl_1.0.0_${1}.deb"
  dpkg-deb --build "$WORK/input" "$WORK/assets/$name" >/dev/null
  (cd "$WORK/assets" && sha256sum "$name" > SHA256SUMS)
}
fixture iphoneos-arm
check pass iphoneos-arm
fixture iphoneos-arm64
check pass iphoneos-arm64
fixture iphoneos-arm64
printf '' > "$WORK/input/var/jb/usr/local/share/rctl/web/index.html"
repack iphoneos-arm64
check fail iphoneos-arm64
fixture iphoneos-arm64
mkdir -p "$WORK/input/var/mobile/Library/Preferences"
printf 'private' > "$WORK/input/var/mobile/Library/Preferences/com.greatlove.rctl.relay.plist"
repack iphoneos-arm64
check fail iphoneos-arm64
fixture iphoneos-arm64
printf 'ENROLL_TOKEN=fixture-not-a-real-secret\n' > "$WORK/input/var/jb/secret"
repack iphoneos-arm64
check fail iphoneos-arm64
fixture iphoneos-arm64
ln -s /etc/passwd "$WORK/input/var/jb/link"
repack iphoneos-arm64
check fail iphoneos-arm64
fixture iphoneos-arm64
printf '#!/bin/sh\n' > "$WORK/input/DEBIAN/postinst"
repack iphoneos-arm64
check fail iphoneos-arm64
fixture iphoneos-arm64
cat "$WORK/assets/SHA256SUMS" >> "$WORK/assets/duplicate"
cat "$WORK/assets/duplicate" >> "$WORK/assets/SHA256SUMS"
check fail iphoneos-arm64
fixture iphoneos-arm64
printf 'corrupt' >> "$WORK/assets/rctl_1.0.0_iphoneos-arm64.deb"
check fail iphoneos-arm64
fixture iphoneos-arm
mv "$WORK/assets/rctl_1.0.0_iphoneos-arm.deb" "$WORK/assets/rctl_1.0.0_iphoneos-arm64.deb"
sha="$(sha256sum "$WORK/assets/rctl_1.0.0_iphoneos-arm64.deb" | awk '{print $1}')"
printf '%s  rctl_1.0.0_iphoneos-arm64.deb\n' "$sha" > "$WORK/assets/SHA256SUMS"
check fail iphoneos-arm64 # Renaming a rootful deb cannot make it rootless.
printf 'Public package integrity and architecture tests passed.\n'
