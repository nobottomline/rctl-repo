#!/usr/bin/env bash
# Shared by publication preflight and the signed repository build.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { printf 'APT release validation failed: %s\n' "$*" >&2; exit 1; }
TAG="${1:-}"
OUTPUT="${2:-}"
shift "$(( $# < 2 ? $# : 2 ))"
[[ "$TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail 'invalid stable tag'
[[ -n "$OUTPUT" && ! -e "$OUTPUT" ]] || fail 'output must be a new directory'
[[ "$#" -gt 0 ]] || set -- iphoneos-arm iphoneos-arm64
for architecture in "$@"; do
  case "$architecture" in iphoneos-arm|iphoneos-arm64) ;; *) fail 'unsupported architecture' ;; esac
done
repository="$(jq -er '.source_repository' "$ROOT/repository.json")"
[[ "$repository" == nobottomline/rctl ]] || fail 'unexpected source repository'
state="$(gh api "repos/$repository/releases/tags/$TAG" --jq '[.tag_name, .draft, .prerelease, .immutable] | @tsv')"
[[ "$state" == "$TAG"$'\tfalse\tfalse\ttrue' ]] || fail 'release must be public, stable and immutable'
gh release verify "$TAG" --repo "$repository" >/dev/null
source "$ROOT/scripts/validate-package.sh"
mkdir -p "$OUTPUT"
for architecture in "$@"; do
  package="rctl_${TAG#v}_${architecture}.deb"
  dir="$OUTPUT/$architecture"
  mkdir "$dir"
  gh release download "$TAG" --repo "$repository" --pattern "$package" --pattern SHA256SUMS --dir "$dir"
  for asset in "$package" SHA256SUMS; do
    [[ -s "$dir/$asset" && ! -L "$dir/$asset" ]] || fail "missing artifact: $asset"
    gh release verify-asset "$TAG" "$dir/$asset" --repo "$repository" >/dev/null
  done
  validate_package "$dir" "$TAG" "$architecture" "$dir/extracted"
  rm -rf "$dir/extracted"
done
printf 'Verified APT release: %s (%s)\n' "$TAG" "$*"
