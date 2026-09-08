#!/usr/bin/env bash
# Sourced by the generator. The caller supplies fail() and an unused extraction path.
validate_package() {
  local dir="$1" tag="$2" architecture="$3" bootstrap="$4" tree="$5"
  local version="${tag#v}" package report client count expected actual
  package="rctl_${version}_${architecture}.deb"
  report="rctl-qualification_${version}.json"
  case "${architecture}" in
    iphoneos-arm) client="var/mobile/rctl/index.html" ;;
    iphoneos-arm64)
      client="var/jb/usr/local/share/rctl/web/index.html"
      report="rctl-qualification_${version}_iphoneos-arm64.json"
      ;;
    *) fail "unsupported package architecture: ${architecture}" ;;
  esac
  count="$(awk -v name="${package}" '$2 == name || $2 == "*" name { count++ } END { print count + 0 }' "${dir}/SHA256SUMS")"
  [[ "${count}" == 1 ]] || fail "${tag} checksum set must contain exactly one ${package} entry"
  expected="$(awk -v name="${package}" '$2 == name || $2 == "*" name { print $1 }' "${dir}/SHA256SUMS")"
  [[ "${expected}" =~ ^[0-9a-f]{64}$ ]] || fail "${tag} package checksum is malformed"
  actual="$(sha256sum "${dir}/${package}" | awk '{print $1}')"
  [[ "${actual}" == "${expected}" ]] || fail "${tag} package checksum mismatch"
  [[ "$(dpkg-deb -f "${dir}/${package}" Package)" == com.greatlove.rctl ]] || fail "${tag} package id is invalid"
  [[ "$(dpkg-deb -f "${dir}/${package}" Version)" == "${version}" ]] || fail "${tag} package version is invalid"
  [[ "$(dpkg-deb -f "${dir}/${package}" Architecture)" == "${architecture}" ]] || fail "${tag} package architecture is invalid"
  dpkg-deb -R "${dir}/${package}" "${tree}"
  # Public packages have no symlink payloads; do not follow a link outside the audit tree.
  [[ -z "$(find "${tree}" -type l -print -quit)" ]] || fail "${tag} package contains a symlink"
  [[ -s "${tree}/${client}" ]] || fail "${tag} package has no control client"
  [[ -z "$(find "${tree}" -name com.greatlove.rctl.relay.plist -print -quit)" ]] || fail "${tag} contains relay configuration"
  if find "${tree}" -type f -print0 | xargs -0 grep -IEl 'ENROLL_TOKEN=[^[:space:]]+|enroll_[A-Za-z0-9_-]{16,}' >/dev/null 2>&1; then
    fail "${tag} contains data resembling relay credentials"
  fi
  if [[ "${architecture}" == iphoneos-arm64 ]]; then
    [[ "$(dpkg-deb -f "${dir}/${package}" Depends)" == 'ellekit, firmware (>= 15.0)' ]] || fail "${tag} rootless dependencies are invalid"
    [[ ! -e "${tree}/Library" && ! -e "${tree}/usr" && ! -e "${tree}/var/mobile" ]] || fail "${tag} rootless package has unprefixed payload"
    grep -Fx "RCTL_PREFIX='/var/jb'" "${tree}/DEBIAN/postinst" >/dev/null || fail "${tag} has no rootless install prefix"
    jq -e --arg architecture "${architecture}" --arg name "${package}" --arg sha "${actual}" '
      .schema == 4 and .package.architecture == $architecture and
      .package.name == $name and .package.sha256 == $sha and
      .checks.rootless_runtime == true and .checks.package_manager_install == true
    ' "${dir}/${report}" >/dev/null || fail "${tag} rootless qualification does not match this artifact"
  fi
  jq -e --arg tag "${tag}" --arg version "${version}" '
    (.schema | type == "number" and . >= 2) and
    .product == "rctl" and .tag == $tag and .version == $version and
    (.checks | type == "object" and length > 0 and ([.[] | . == true] | all))
  ' "${dir}/${report}" >/dev/null || fail "${tag} qualification report is incomplete"
  if [[ "${tag}" != "${bootstrap}" || "${architecture}" == iphoneos-arm64 ]]; then
    jq -e '
      .schema >= 3 and .checks.package_manager_upgrade == true and
      .checks.package_manager_recovery == true
    ' "${dir}/${report}" >/dev/null || fail "${tag} is not qualified for package-manager updates"
  fi
}
