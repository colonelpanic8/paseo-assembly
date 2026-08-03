#!/usr/bin/env bash
# Push the assembled tree to the branch `manifest.toml`'s [publish] names.
#
# This is the step that makes a rebuild visible. CI never builds this
# repository -- it waits for the published branch to carry the tree that
# manifest.lock.json pins (scripts/await-published-assembly.sh) and then builds
# that commit. A recipe change that is committed but not published therefore
# fails every workflow with a tree mismatch, not a build error.
#
# fork-fold has no publish verb: `[publish]` is provenance metadata to it, and
# the push is site policy. This script is that policy.
#
# The lock's tree hash is the invariant; the commit id is not. So this verifies
# the build worktree carries the locked *tree* and then pushes whatever commit
# holds it. The push is a force -- the assembled branch is compiled output and
# a rebuild re-commits rather than fast-forwards -- but leased against the head
# we observed, so a concurrent publish loses the race instead of being lost.
#
# Usage: publish-assembly.sh [BUILD_WORKTREE]

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

worktree="${1:-.worktrees/build}"
lock_file="manifest.lock.json"
manifest="manifest.toml"

if [[ ! -d "$worktree" ]]; then
  echo "error: no build worktree at $worktree; run \`fork-fold build\` first" >&2
  exit 1
fi

# [publish] is the single source of truth for where the assembly lands.
publish_key() {
  awk -v key="$1" '
    /^\[publish\]/ { in_publish = 1; next }
    /^\[/          { in_publish = 0 }
    in_publish && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' "$manifest"
}

remote="$(publish_key remote)"
branch="$(publish_key branch)"
if [[ -z "$remote" || -z "$branch" ]]; then
  echo "error: $manifest has no [publish] remote/branch to push to" >&2
  exit 1
fi

expected_tree="$(jq -r '.build.tree' "$lock_file")"
if [[ -z "$expected_tree" || "$expected_tree" == "null" ]]; then
  echo "error: $lock_file records no build tree" >&2
  exit 1
fi

if [[ -n "$(git -C "$worktree" status --porcelain)" ]]; then
  echo "error: $worktree is dirty -- it is mid-build or mid-resolution" >&2
  exit 1
fi

commit="$(git -C "$worktree" rev-parse HEAD)"
actual_tree="$(git -C "$worktree" rev-parse 'HEAD^{tree}')"
if [[ "$actual_tree" != "$expected_tree" ]]; then
  echo "error: $worktree carries tree $actual_tree, but $lock_file pins $expected_tree" >&2
  echo "       run \`fork-fold build --locked\` to reproduce the locked tree first" >&2
  exit 1
fi

git -C "$worktree" fetch --force --no-tags "$remote" "$branch" >&2 || true
lease="$(git -C "$worktree" rev-parse --verify --quiet FETCH_HEAD || true)"

if [[ "$lease" == "$commit" ]]; then
  echo "already published: $remote/$branch is $commit (tree $expected_tree)"
  exit 0
fi

echo "publishing $commit (tree $expected_tree) to $remote/$branch"
if [[ -n "$lease" ]]; then
  git -C "$worktree" push \
    "--force-with-lease=refs/heads/$branch:$lease" \
    "$remote" "$commit:refs/heads/$branch"
else
  git -C "$worktree" push "$remote" "$commit:refs/heads/$branch"
fi
