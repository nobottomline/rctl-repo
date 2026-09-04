#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-${ROOT}/_site}"
CONFIG="${ROOT}/repository.json"
LEDGER="${ROOT}/releases.txt"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/rctl-apt-repo.XXXXXX")"

cleanup() {
  rm -rf "${WORK}"
}
trap cleanup EXIT

fail() {
  printf 'repository build failed: %s\n' "$*" >&2
  exit 1
}

require() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

for command in apt-ftparchive base64 bzip2 curl dpkg dpkg-deb dpkg-scanpackages gh gpg gzip jq sha256sum xz zstd; do
  require "${command}"
done

[[ -f "${CONFIG}" && ! -L "${CONFIG}" ]] || fail "repository.json is missing or unsafe"
[[ -f "${LEDGER}" && ! -L "${LEDGER}" ]] || fail "releases.txt is missing or unsafe"
for asset in index.html package.html styles.css site.js CydiaIcon.png; do
  [[ -s "${ROOT}/site/${asset}" && ! -L "${ROOT}/site/${asset}" ]] || \
    fail "site asset is missing, empty, or unsafe: ${asset}"
done
jq -e '
  keys == ["architectures", "base_url", "bootstrap_tag", "codename", "components", "description", "label", "origin", "schema", "source_repository", "suite"] and
  .schema == 1 and
  (.source_repository | test("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")) and
  (.base_url | test("^https://[^/?#]+(/[^?#]*)?$")) and
  (.bootstrap_tag | test("^v(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")) and
  (.origin | type == "string" and length > 0) and
  (.label | type == "string" and length > 0) and
  (.suite | type == "string" and length > 0) and
  (.codename | type == "string" and length > 0) and
  (.architectures == ["iphoneos-arm"]) and
  (.components == ["main"]) and
  (.description | type == "string" and length > 0)
' "${CONFIG}" >/dev/null || fail "repository.json does not match schema 1"

source_repository="$(jq -r .source_repository "${CONFIG}")"
base_url="$(jq -r '.base_url | sub("/+$"; "")' "${CONFIG}")"
bootstrap_tag="$(jq -r .bootstrap_tag "${CONFIG}")"

mapfile -t tags < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "${LEDGER}")
[[ "${#tags[@]}" -gt 0 ]] || fail "release ledger is empty"
[[ "${tags[0]}" == "${bootstrap_tag}" ]] || fail "bootstrap tag must be the first ledger entry"

declare -A seen=()
previous_version=""
for tag in "${tags[@]}"; do
  [[ "${tag}" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail "invalid release tag: ${tag}"
  [[ -z "${seen[${tag}]:-}" ]] || fail "duplicate release tag: ${tag}"
  seen["${tag}"]=1
  version="${tag#v}"
  if [[ -n "${previous_version}" ]] && ! dpkg --compare-versions "${previous_version}" lt "${version}"; then
    fail "release ledger is not strictly increasing: ${previous_version}, ${version}"
  fi
  previous_version="${version}"
done

rm -rf "${OUTPUT}"
mkdir -p "${OUTPUT}/pool" "${OUTPUT}/depictions/com.greatlove.rctl" "${WORK}/downloads"

for tag in "${tags[@]}"; do
  version="${tag#v}"
  package="rctl_${version}_iphoneos-arm.deb"
  report="rctl-qualification_${version}.json"
  release_dir="${WORK}/downloads/${tag}"
  mkdir -p "${release_dir}"

  release_state="$(gh api "repos/${source_repository}/releases/tags/${tag}" \
    --jq '[.tag_name, .draft, .prerelease, .immutable] | @tsv')"
  [[ "${release_state}" == "${tag}"$'\tfalse\tfalse\ttrue' ]] || fail "${tag} is not an immutable stable release"
  gh release verify "${tag}" --repo "${source_repository}" >/dev/null
  gh release download "${tag}" --repo "${source_repository}" \
    --pattern "${package}" --pattern "${report}" --pattern SHA256SUMS \
    --dir "${release_dir}"

  for asset in "${package}" "${report}" SHA256SUMS; do
    [[ -f "${release_dir}/${asset}" && ! -L "${release_dir}/${asset}" ]] || fail "${tag} is missing ${asset}"
    gh release verify-asset "${tag}" "${release_dir}/${asset}" --repo "${source_repository}" >/dev/null
  done

  checksum_count="$(awk -v name="${package}" '$2 == name || $2 == "*" name { count++ } END { print count + 0 }' "${release_dir}/SHA256SUMS")"
  [[ "${checksum_count}" == 1 ]] || fail "${tag} checksum set does not contain exactly one ${package} entry"
  expected_sha="$(awk -v name="${package}" '$2 == name || $2 == "*" name { print $1 }' "${release_dir}/SHA256SUMS")"
  [[ "${expected_sha}" =~ ^[0-9a-f]{64}$ ]] || fail "${tag} package checksum is malformed"
  actual_sha="$(sha256sum "${release_dir}/${package}" | awk '{print $1}')"
  [[ "${actual_sha}" == "${expected_sha}" ]] || fail "${tag} package checksum mismatch"

  [[ "$(dpkg-deb -f "${release_dir}/${package}" Package)" == com.greatlove.rctl ]] || fail "${tag} package id is invalid"
  [[ "$(dpkg-deb -f "${release_dir}/${package}" Version)" == "${version}" ]] || fail "${tag} package version is invalid"
  [[ "$(dpkg-deb -f "${release_dir}/${package}" Architecture)" == iphoneos-arm ]] || fail "${tag} package architecture is invalid"

  package_tree="${WORK}/package-${version}"
  dpkg-deb -R "${release_dir}/${package}" "${package_tree}"
  [[ -s "${package_tree}/var/mobile/rctl/index.html" ]] || fail "${tag} package has no control client"
  [[ ! -e "${package_tree}/var/mobile/Library/Preferences/com.greatlove.rctl.relay.plist" ]] || fail "${tag} contains relay configuration"
  if find "${package_tree}" -type f -print0 | xargs -0 grep -IEl 'ENROLL_TOKEN=[^[:space:]]+|enroll_[A-Za-z0-9_-]{16,}' >/dev/null 2>&1; then
    fail "${tag} contains data resembling relay credentials"
  fi

  jq -e --arg tag "${tag}" --arg version "${version}" '
    (.schema | type == "number" and . >= 2) and
    .product == "rctl" and .tag == $tag and .version == $version and
    (.checks | type == "object" and length > 0 and ([.[]] | all))
  ' "${release_dir}/${report}" >/dev/null || fail "${tag} qualification report is incomplete"
  if [[ "${tag}" != "${bootstrap_tag}" ]]; then
    jq -e '
      .schema >= 3 and
      .checks.package_manager_upgrade == true and
      .checks.package_manager_recovery == true
    ' "${release_dir}/${report}" >/dev/null || fail "${tag} is not qualified for package-manager updates"
  fi

  install -m 0644 "${release_dir}/${package}" "${OUTPUT}/pool/${package}"
done

(
  cd "${OUTPUT}"
  dpkg-scanpackages -m pool /dev/null > Packages.raw
  awk -v base="${base_url}" '
    /^Filename: pool\// { sub(/^Filename: /, "Filename: ./") }
    /^Package: com\.greatlove\.rctl$/ { package = 1 }
    package && /^$/ {
      print "Depiction: " base "/depictions/com.greatlove.rctl/"
      print "SileoDepiction: " base "/depictions/com.greatlove.rctl/depiction.json"
      print "Icon: " base "/CydiaIcon.png"
      package = 0
    }
    { print }
  ' Packages.raw > Packages
  rm Packages.raw
  gzip -n -c -9 Packages > Packages.gz
  bzip2 -c -9 Packages > Packages.bz2
  xz --threads=1 -c -9 Packages > Packages.xz
  zstd --quiet --no-progress --threads=1 -c -19 Packages > Packages.zst
)

latest_version="${tags[${#tags[@]}-1]#v}"
install -m 0644 "${ROOT}/site/index.html" "${OUTPUT}/index.html"
install -m 0644 "${ROOT}/site/package.html" "${OUTPUT}/depictions/com.greatlove.rctl/index.html"
install -m 0644 "${ROOT}/site/styles.css" "${OUTPUT}/styles.css"
install -m 0644 "${ROOT}/site/site.js" "${OUTPUT}/site.js"
install -m 0644 "${ROOT}/site/CydiaIcon.png" "${OUTPUT}/CydiaIcon.png"
sed -i.bak "s/@RCTL_VERSION@/${latest_version}/g" \
  "${OUTPUT}/index.html" "${OUTPUT}/depictions/com.greatlove.rctl/index.html"
rm -f "${OUTPUT}/index.html.bak" "${OUTPUT}/depictions/com.greatlove.rctl/index.html.bak"
if grep -R -F '@RCTL_VERSION@' "${OUTPUT}/index.html" "${OUTPUT}/depictions/com.greatlove.rctl/index.html" >/dev/null; then
  fail "generated site contains an unresolved version placeholder"
fi
for scheme in 'cydia://url/' 'sileo://source/' 'zbra://sources/add/'; do
  grep -F "${scheme}" "${OUTPUT}/index.html" >/dev/null || fail "generated site is missing ${scheme} install link"
done

jq -n --arg version "${latest_version}" --arg source "https://github.com/${source_repository}" '{
  minVersion: "0.4",
  class: "DepictionTabView",
  tintColor: "#147D64",
  tabs: [{
    class: "DepictionStackView",
    tabname: "Details",
    views: [
      {class: "DepictionHeaderView", title: "rctl"},
      {class: "DepictionMarkdownView", markdown: "Self-hosted remote control for jailbroken iOS devices. This repository package provides LAN-only access and contains no relay configuration."},
      {class: "DepictionTableTextView", title: "Version", text: $version},
      {class: "DepictionTableTextView", title: "Architecture", text: "iphoneos-arm"},
      {class: "DepictionTableButtonView", title: "Source code", action: $source}
    ]
  }]
}' > "${OUTPUT}/depictions/com.greatlove.rctl/depiction.json"

origin="$(jq -r .origin "${CONFIG}")"
label="$(jq -r .label "${CONFIG}")"
suite="$(jq -r .suite "${CONFIG}")"
codename="$(jq -r .codename "${CONFIG}")"
architectures="$(jq -r '.architectures | join(" ")' "${CONFIG}")"
components="$(jq -r '.components | join(" ")' "${CONFIG}")"
description="$(jq -r .description "${CONFIG}")"
(
  cd "${OUTPUT}"
  apt-ftparchive \
    -o "APT::FTPArchive::Release::Origin=${origin}" \
    -o "APT::FTPArchive::Release::Label=${label}" \
    -o "APT::FTPArchive::Release::Suite=${suite}" \
    -o "APT::FTPArchive::Release::Version=${latest_version}" \
    -o "APT::FTPArchive::Release::Codename=${codename}" \
    -o "APT::FTPArchive::Release::Architectures=${architectures}" \
    -o "APT::FTPArchive::Release::Components=${components}" \
    -o "APT::FTPArchive::Release::Description=${description}" \
    release . > Release
)

[[ -n "${APT_REPOSITORY_SIGNING_KEY_B64:-}" ]] || fail "APT_REPOSITORY_SIGNING_KEY_B64 is required"
export GNUPGHOME="${WORK}/gnupg"
mkdir -m 0700 "${GNUPGHOME}"
printf '%s' "${APT_REPOSITORY_SIGNING_KEY_B64}" | base64 --decode > "${WORK}/repository-key.asc"
chmod 0600 "${WORK}/repository-key.asc"
gpg --batch --import "${WORK}/repository-key.asc" >/dev/null 2>&1
fingerprint="$(gpg --batch --with-colons --list-secret-keys | awk -F: '$1 == "fpr" { print $10; exit }')"
[[ "${fingerprint}" =~ ^[0-9A-F]{40}$ ]] || fail "repository signing key is unavailable"
gpg --batch --yes --local-user "${fingerprint}" --armor --detach-sign \
  --output "${OUTPUT}/Release.gpg" "${OUTPUT}/Release"
gpg --batch --yes --local-user "${fingerprint}" --clearsign \
  --output "${OUTPUT}/InRelease" "${OUTPUT}/Release"
gpg --batch --yes --armor --export "${fingerprint}" > "${OUTPUT}/rctl-repo-key.asc"
gpg --batch --yes --export "${fingerprint}" > "${OUTPUT}/rctl-repo-key.gpg"

find "${OUTPUT}" -type l -print -quit | grep -q . && fail "generated repository contains symlinks"
printf '%s\n' "${fingerprint}" > "${OUTPUT}/repository-key-fingerprint.txt"
printf 'APT repository built: %s (%s, key %s)\n' "${OUTPUT}" "${latest_version}" "${fingerprint}"
