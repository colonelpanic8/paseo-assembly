#!/usr/bin/env bash
# Push the assembled tree to the branch `manifest.toml`'s [publish] names.
#
# This is the step that makes a rebuild visible. CI never builds this
# repository -- it waits for the published branch to carry the tree that
# manifest.lock.json pins (scripts/await-published-assembly.sh) and then builds
# that commit. A recipe change that is committed but not published therefore
# fails every workflow with a tree mismatch, not a build error.
#
# fork-assembler has no publish verb: `[publish]` is provenance metadata to it, and
# the push is site policy. This script is that policy.
#
# The lock's tree hash is the invariant; the commit id is not. So this verifies
# the build worktree carries the locked *tree* and then pushes whatever commit
# holds it. The push is a force -- the assembled branch is compiled output and
# a rebuild re-commits rather than fast-forwards -- but leased against the head
# we observed, so a concurrent publish loses the race instead of being lost.
#
# The npm deps hash check runs only at publish time. It is slow (it forces a
# re-fetch of the whole assembled dependency tree), so start it in parallel with
# the push instead of making either operation wait for the other. The push is
# intentionally optimistic: it unblocks CI and consumers while the check runs;
# a stale hash is repaired with a follow-up recipe commit and republish.
#
# Usage: publish-assembly.sh [--skip-hash-check] [BUILD_WORKTREE]

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

skip_hash_check=""
if [[ "${1:-}" == "--skip-hash-check" ]]; then
  skip_hash_check=1
  shift
fi

worktree="${1:-.worktrees/build}"
lock_file="manifest.lock.json"
manifest="manifest.toml"

if [[ ! -d "$worktree" ]]; then
  echo "error: no build worktree at $worktree; run \`fork-assembler build\` first" >&2
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
  echo "       run \`fork-assembler build --locked\` to reproduce the locked tree first" >&2
  exit 1
fi

if [[ -n "$skip_hash_check" ]]; then
  hash_pid=""
else
  echo "starting npm deps hash check in parallel with publish" >&2
  "$repo_root/scripts/check-npm-deps-hash.sh" "$worktree" >&2 &
  hash_pid=$!
fi

git -C "$worktree" fetch --force --no-tags "$remote" "$branch" >&2 || true
lease="$(git -C "$worktree" rev-parse --verify --quiet FETCH_HEAD || true)"

push_status=0
if [[ "$lease" == "$commit" ]]; then
  echo "already published: $remote/$branch is $commit (tree $expected_tree)"
else
  echo "publishing $commit (tree $expected_tree) to $remote/$branch"
  if [[ -n "$lease" ]]; then
    if git -C "$worktree" push \
      "--force-with-lease=refs/heads/$branch:$lease" \
      "$remote" "$commit:refs/heads/$branch"; then
      :
    else
      push_status=$?
    fi
  elif git -C "$worktree" push "$remote" "$commit:refs/heads/$branch"; then
    :
  else
    push_status=$?
  fi
fi

hash_status=0
if [[ -n "$hash_pid" ]]; then
  if wait "$hash_pid"; then
    :
  else
    hash_status=$?
  fi
fi

if (( push_status != 0 )); then
  echo "error: assembled push failed" >&2
  exit "$push_status"
fi
if [[ -n "$skip_hash_check" ]]; then
  echo "npm deps hash check SKIPPED (--skip-hash-check) -- run \`just check-npm-deps-hash\`" >&2
  exit 0
fi
if (( hash_status != 0 )); then
  echo >&2
  echo "error: the published tree failed the assembled npm deps hash check." >&2
  echo "       regenerate it and publish the correction:" >&2
  echo "         just check-npm-deps-hash --write" >&2
  echo "         fork-assembler build && fork-assembler build --locked" >&2
  echo "         git commit -- patches manifest.lock.json resolutions && git push origin main" >&2
  echo "         just publish" >&2
  exit 1
fi
