#!/usr/bin/env bash

# Publish only complete, verified builds. Existing assets are never overwritten.
set -euo pipefail

: "${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY to owner/repo}"
: "${MAIN_SHA:?Set MAIN_SHA to the pinned source commit}"
: "${PATCH_SHA:?Set PATCH_SHA to the pinned deploy commit}"

dist=${1:?Usage: scripts/publish-linux.sh <build-directory>}
tag="fork-${MAIN_SHA:0:12}-patch-${PATCH_SHA:0:12}"
files=(magpie-cli-linux-amd64 magpie-cli-linux-arm64 VERSION BUILDINFO SHA256SUMS)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

# The checksum manifest uses paths relative to the build directory.
(cd -- "$dist" && sha256sum --check SHA256SUMS)
grep -Fx "source_sha=$MAIN_SHA" "$dist/BUILDINFO" > /dev/null
grep -Fx "patch_sha=$PATCH_SHA" "$dist/BUILDINFO" > /dev/null
grep -Fx "fork-${MAIN_SHA:0:12}+patch.${PATCH_SHA:0:12}" "$dist/VERSION" > /dev/null

expected='[]'
for name in "${files[@]}"; do
  digest=$(sha256sum "$dist/$name")
  digest="sha256:${digest%% *}"
  size=$(wc -c < "$dist/$name")
  expected=$(jq --arg name "$name" --arg digest "$digest" --argjson size "$size" \
    '. + [{name: $name, digest: $digest, size: $size, state: "uploaded"}]' <<< "$expected")
done

# Draft releases cannot be fetched through /releases/tags until published.
find_release() {
  gh api --paginate "repos/$GITHUB_REPOSITORY/releases?per_page=100" --jq '.[]' |
    jq -s --arg tag "$tag" 'map(select(.tag_name == $tag)) |
      if length > 1 then error("multiple releases have the same tag") else .[0] // empty end'
}

# A pre-existing tag must point at the exact deploy commit, not a moving branch.
refs=$(gh api "repos/$GITHUB_REPOSITORY/git/matching-refs/tags/$tag")
if jq -e --arg ref "refs/tags/$tag" 'any(.[]; .ref == $ref)' <<< "$refs" > /dev/null; then
  target=$(gh api "repos/$GITHUB_REPOSITORY/commits/$tag" --jq .sha)
  if [[ "$target" != "$PATCH_SHA" ]]; then
    echo "Refusing to publish: $tag points to another commit" >&2
    exit 1
  fi
fi

find_release > "$tmp/release.json"
if [[ ! -s "$tmp/release.json" ]]; then
  notes=$(printf 'towry/magpie Linux CLI (patched fork)\n\n- source (origin/main): %s\n- patches (deploy): %s\n\nThis is not an official yetone/magpie release.' "$MAIN_SHA" "$PATCH_SHA")
  # Use the creation response: the releases list may not show a new draft yet.
  gh api --method POST "repos/$GITHUB_REPOSITORY/releases" \
    -f tag_name="$tag" -f target_commitish="$PATCH_SHA" -f name="$tag" \
    -f body="$notes" -F draft=true -F prerelease=false -f make_latest=false > "$tmp/release.json"
fi

# Validate all existing assets before uploading anything. An interrupted draft
# may be completed, but neither a draft nor a published asset is replaced.
jq -e --arg patch "$PATCH_SHA" --argjson expected "$expected" '
  .target_commitish == $patch and .prerelease == false and
  all(.assets[]; . as $asset | any($expected[];
    .name == $asset.name and .digest == $asset.digest and
    .size == $asset.size and .state == $asset.state))
' "$tmp/release.json" > /dev/null || {
  echo "Refusing to modify an existing release with different provenance or assets: $tag" >&2
  exit 1
}

id=$(jq -r .id "$tmp/release.json")
draft=$(jq -r .draft "$tmp/release.json")
upload_url=$(jq -r .upload_url "$tmp/release.json")
upload_url=${upload_url%%\{*}
for name in "${files[@]}"; do
  if jq -e --arg name "$name" 'any(.assets[]; .name == $name)' "$tmp/release.json" > /dev/null; then
    continue
  fi
  if [[ "$draft" != true ]]; then
    echo "Refusing to change a published release with a missing asset: $name" >&2
    exit 1
  fi
  gh api --method POST "$upload_url?name=$name" \
    -H 'Content-Type: application/octet-stream' --input "$dist/$name" > /dev/null
done

gh api "repos/$GITHUB_REPOSITORY/releases/$id" > "$tmp/release.json"
jq -e --argjson expected "$expected" '
  ([.assets[] | {name, digest, size, state}] | sort_by(.name)) == ($expected | sort_by(.name))
' "$tmp/release.json" > /dev/null

if [[ "$draft" == true ]]; then
  gh api --method PATCH "repos/$GITHUB_REPOSITORY/releases/$id" \
    -F draft=false -f make_latest=false > /dev/null
else
  echo "Release already published; all assets match, leaving it unchanged."
fi

target=$(gh api "repos/$GITHUB_REPOSITORY/commits/$tag" --jq .sha)
[[ "$target" == "$PATCH_SHA" ]]
url="https://github.com/$GITHUB_REPOSITORY/releases/tag/$tag"
echo "$url"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    printf '## Linux CLI release\n\n- Release: [%s](%s)\n- Source: %s\n- Deploy: %s\n\n' \
      "$tag" "$url" "$MAIN_SHA" "$PATCH_SHA"
    sed 's/^/    /' "$dist/SHA256SUMS"
  } >> "$GITHUB_STEP_SUMMARY"
fi
