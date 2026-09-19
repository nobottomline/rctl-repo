#!/usr/bin/env bash
# Exercise a real APT client without installing packages or using host APT state.
set -euo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${1:?repository URL required}"
VERSION="${2:?expected version required}"
BASE="${BASE%/}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fetch() {
  curl --proto '=https,file' --tlsv1.2 --fail --location --silent --show-error \
    --retry 3 --connect-timeout 15 --max-time 120 "$BASE/$1" --output "$WORK/$1"
}
for file in rctl-repo-key.gpg InRelease Release Release.gpg Packages; do fetch "$file"; done
mkdir -m 0700 "$WORK/gnupg"
fingerprint="$(gpg --batch --homedir "$WORK/gnupg" --show-keys --with-colons "$WORK/rctl-repo-key.gpg" | awk -F: '$1 == "fpr" {print $10; exit}')"
test "$fingerprint" = "$(cat "$ROOT/repository-key-fingerprint.txt")"
gpgv --homedir "$WORK/gnupg" --keyring "$WORK/rctl-repo-key.gpg" --output "$WORK/signed-release" "$WORK/InRelease"
cmp "$WORK/Release" "$WORK/signed-release"
gpgv --homedir "$WORK/gnupg" --keyring "$WORK/rctl-repo-key.gpg" "$WORK/Release.gpg" "$WORK/Release"
if grep -Eq '[[:space:]]Release$' "$WORK/Release"; then
  echo 'Release must not contain a checksum of its own partial output' >&2
  exit 1
fi
for file in Packages Packages.gz Packages.bz2 Packages.xz Packages.zst; do
  fetch "$file"
  expected="$(awk -v file="$file" '/^SHA256:/ {active=1; next} /^[^ ]/ {active=0} active && $3 == file {print $1}' "$WORK/Release")"
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]]
  test "$(sha256sum "$WORK/$file" | awk '{print $1}')" = "$expected"
done
for arch in iphoneos-arm iphoneos-arm64; do
  dir="$WORK/$arch"
  mkdir -p "$dir/etc/empty" "$dir/state/lists/partial" "$dir/cache/archives/partial" "$dir/download"
  printf 'deb [arch=%s signed-by=%s] %s ./\n' "$arch" "$WORK/rctl-repo-key.gpg" "$BASE" > "$dir/etc/sources.list"
  cat > "$dir/apt.conf" <<EOF
Dir "$dir";
Dir::Etc "$dir/etc";
Dir::Etc::main "/dev/null";
Dir::Etc::parts "empty";
Dir::Etc::sourcelist "sources.list";
Dir::Etc::sourceparts "empty";
Dir::Etc::preferences "/dev/null";
Dir::Etc::preferencesparts "empty";
Dir::State "$dir/state";
Dir::State::status "$dir/state/status";
Dir::Cache "$dir/cache";
Dir::Log "$dir/log";
APT::Architecture "$arch";
APT::Architectures { "$arch"; };
APT::Sandbox::User "$(id -un)";
Acquire::Languages "none";
Acquire::Retries "3";
Acquire::http::Timeout "30";
Acquire::https::Timeout "30";
EOF
  export APT_CONFIG="$dir/apt.conf"
  touch "$dir/state/status"
  apt-get -o APT::Update::Error-Mode=any update
  apt-cache policy com.greatlove.rctl > "$dir/policy"
  cat "$dir/policy"
  grep -Fx "  Candidate: $VERSION" "$dir/policy"
  (cd "$dir/download" && apt-get download "com.greatlove.rctl=$VERSION")
  mapfile -t debs < <(find "$dir/download" -name '*.deb' -type f)
  test "${#debs[@]}" -eq 1
  test "$(dpkg-deb -f "${debs[0]}" Version)" = "$VERSION"
  test "$(dpkg-deb -f "${debs[0]}" Architecture)" = "$arch"
  # Dependency stubs describe a supported jailbreak; no fixture is ever installed.
  dependency=mobilesubstrate
  if [[ "$arch" == iphoneos-arm64 ]]; then dependency=ellekit; fi
  for package in firmware "$dependency"; do
    printf 'Package: %s\nStatus: install ok installed\nArchitecture: %s\nVersion: 99.0\nDescription: isolated solver fixture\n\n' "$package" "$arch" >> "$dir/state/status"
  done
  apt-get --simulate install "com.greatlove.rctl=$VERSION" > "$dir/install"
  grep -F 'Inst com.greatlove.rctl ' "$dir/install"
  printf 'Package: com.greatlove.rctl\nStatus: install ok installed\nArchitecture: %s\nVersion: 0.3.2\nDescription: isolated upgrade fixture\n\n' "$arch" >> "$dir/state/status"
  apt-get --simulate install "com.greatlove.rctl=$VERSION" > "$dir/upgrade"
  grep -F 'Inst com.greatlove.rctl [0.3.2]' "$dir/upgrade"
  printf 'APT verified signature, candidate, download, install and upgrade plan: %s %s\n' "$VERSION" "$arch"
done
