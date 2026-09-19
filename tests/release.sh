#!/usr/bin/env bash
set -euo pipefail
# Reuse the package fixtures and their content checks, then exercise GH boundaries.
# shellcheck source=tests/packages.sh
source "$(dirname "$0")/packages.sh"
fixture iphoneos-arm64
mkdir "$WORK/bin"
cat > "$WORK/bin/gh" <<'SH'
#!/usr/bin/env bash
set -eu
case "$1 $2" in
  'api repos/nobottomline/rctl/releases/tags/v1.0.0')
    printf 'v1.0.0\t%s\tfalse\ttrue\n' "${TEST_DRAFT:-false}" ;;
  'release verify') test "${TEST_BAD_RELEASE:-0}" = 0 ;;
  'release verify-asset') test "${TEST_BAD_ASSET:-0}" = 0 ;;
  'release download')
    while [[ "$1" != --dir ]]; do shift; done
    cp "$TEST_ASSETS/"* "$2/" ;;
  *) exit 1 ;;
esac
SH
chmod +x "$WORK/bin/gh"
export PATH="$WORK/bin:$PATH" TEST_ASSETS="$WORK/assets"
verify() {
  local expected="$1" result=0
  rm -rf "$WORK/verified"
  bash "$ROOT/scripts/verify-release.sh" v1.0.0 "$WORK/verified" iphoneos-arm64 > "$WORK/result" 2>&1 || result=$?
  if [[ "$expected" == pass && "$result" != 0 ]] || [[ "$expected" == fail && "$result" == 0 ]]; then
    cat "$WORK/result" >&2
    fail "unexpected release validation: $expected"
  fi
}
verify pass
TEST_DRAFT=true verify fail
TEST_BAD_RELEASE=1 verify fail
TEST_BAD_ASSET=1 verify fail
rm "$WORK/assets/rctl_1.0.0_iphoneos-arm64.deb"
verify fail
printf 'Release identity, asset attestation and missing-lane checks passed.\n'
