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
    mkdir -p "$tree/var/mobile/rctl"
    printf 'test' > "$tree/var/mobile/rctl/index.html"
  fi
  dpkg-deb --build "$tree" "$WORK/assets/$name" >/dev/null
  sha="$(sha256sum "$WORK/assets/$name" | awk '{print $1}')"
  printf '%s  %s\n' "$sha" "$name" > "$WORK/assets/SHA256SUMS"
  report="$WORK/assets/rctl-qualification_1.0.0.json"
  if [[ "$arch" == iphoneos-arm64 ]]; then report="$WORK/assets/rctl-qualification_1.0.0_iphoneos-arm64.json"; fi
  jq -n --arg arch "$arch" --arg name "$name" --arg sha "$sha" '{
    schema: 4, product: "rctl", tag: "v1.0.0", version: "1.0.0",
    package: {architecture: $arch, name: $name, sha256: $sha},
    checks: {rootless_runtime: true, package_manager_install: true,
      package_manager_upgrade: true, package_manager_recovery: true}
  }' > "$report"
}
check() {
  local expected="$1" arch="$2" result=0
  rm -rf "$WORK/extracted"
  (validate_package "$WORK/assets" v1.0.0 "$arch" v1.0.0 "$WORK/extracted") > "$WORK/result" 2>&1 || result=$?
  if [[ "$expected" == pass && "$result" != 0 ]] || [[ "$expected" == fail && "$result" == 0 ]]; then
    cat "$WORK/result" >&2
    fail "unexpected result: $expected/$arch"
  fi
}
alter_report() { jq "$1" "$report" > "$report.next"; mv "$report.next" "$report"; }
fixture iphoneos-arm
check pass iphoneos-arm
alter_report '.schema = 2 | del(.package)'
check pass iphoneos-arm # Bootstrap report compatibility.
fixture iphoneos-arm64
check pass iphoneos-arm64
alter_report '.checks.package_manager_recovery = false'
check fail iphoneos-arm64 # No bootstrap exception for rootless.
fixture iphoneos-arm64
alter_report '.checks.rootless_runtime = "true"'
check fail iphoneos-arm64
fixture iphoneos-arm64
alter_report '.package.architecture = "iphoneos-arm"'
check fail iphoneos-arm64
fixture iphoneos-arm64
alter_report '.package.sha256 = ("0" * 64)'
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
printf 'Package architecture and qualification tests passed.\n'
