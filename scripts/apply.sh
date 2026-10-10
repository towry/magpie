#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/apply.sh --repo-root <repo-root> --patches-dir <patches-dir>

Required:
  --repo-root    Target git repository root to apply patches onto
  --patches-dir  Directory containing patch files and a series file
EOF
}

repo_root=""
patches_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="${2:-}"
      shift 2
      ;;
    --patches-dir)
      patches_dir="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$repo_root" || -z "$patches_dir" ]]; then
  echo "Both --repo-root and --patches-dir are required." >&2
  usage >&2
  exit 1
fi

if ! git -C "$repo_root" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Repository root is not a git repository: $repo_root" >&2
  exit 1
fi

if [[ ! -d "$patches_dir" ]]; then
  echo "Patches directory does not exist: $patches_dir" >&2
  exit 1
fi

series_file="$patches_dir/series"
if [[ ! -f "$series_file" ]]; then
  echo "Missing series file: $series_file" >&2
  exit 1
fi

cd "$repo_root"

while IFS= read -r patch || [[ -n "$patch" ]]; do
  if [[ -z "$patch" || "$patch" =~ ^# ]]; then
    continue
  fi

  patch_path="$patches_dir/$patch"
  if [[ ! -f "$patch_path" ]]; then
    echo "Missing patch file: $patch_path" >&2
    exit 1
  fi

  echo "Applying $patch"

  if ! git apply --check "$patch_path"; then
    echo "Patch pre-check failed: $patch" >&2
    exit 1
  fi

  if ! git apply "$patch_path"; then
    echo "Patch apply failed: $patch" >&2
    exit 1
  fi
done < "$series_file"
