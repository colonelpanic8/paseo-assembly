#!/usr/bin/env bash
# Wait until the published assembled branch carries the tree that
# manifest.lock.json pins, then print the commit that carries it.
#
# The lock's tree hash is the reproducibility invariant; the commit id is not
# (a rebuild re-commits the same tree). So this polls by tree and reports the
# commit only as the handle a consumer needs to name that tree -- e.g. as the
# `rev` of a flake reference, which is also what the build's provenance stamp
# resolves `self.rev` to.
#
# Usage: await-published-assembly.sh LOCK_FILE REPO_URL BRANCH [ATTEMPTS] [DELAY]
# Writes `commit=<sha>` and `tree=<sha>` to $GITHUB_OUTPUT when that is set.

set -euo pipefail

lock_file="${1:?lock file required}"
repo_url="${2:?repository url required}"
branch="${3:?branch required}"
attempts="${4:-20}"
delay="${5:-15}"

expected_tree="$(jq -r '.build.tree' "$lock_file")"
if [[ -z "$expected_tree" || "$expected_tree" == "null" ]]; then
  echo "::error::$lock_file records no build tree" >&2
  exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

git clone --filter=blob:none --no-checkout "$repo_url" "$work_dir/source" >&2

actual_tree=""
actual_commit=""
for ((attempt = 1; attempt <= attempts; attempt++)); do
  git -C "$work_dir/source" fetch --force --no-tags origin "$branch" >&2
  actual_commit="$(git -C "$work_dir/source" rev-parse FETCH_HEAD)"
  actual_tree="$(git -C "$work_dir/source" rev-parse 'FETCH_HEAD^{tree}')"
  [[ "$actual_tree" == "$expected_tree" ]] && break

  echo "Published assembly is not current yet (attempt ${attempt}/${attempts}); waiting ${delay}s." >&2
  sleep "$delay"
done

if [[ "$actual_tree" != "$expected_tree" ]]; then
  echo "::error::Published assembly tree mismatch: expected $expected_tree, got $actual_tree" >&2
  exit 1
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "commit=$actual_commit"
    echo "tree=$actual_tree"
  } >> "$GITHUB_OUTPUT"
fi

echo "$actual_commit"
