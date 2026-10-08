#!/usr/bin/env bash
# Verify -- or regenerate -- the assembled npm dependency hash.
#
# patches/assembled-npm-deps-hash.patch pins a fixed-output hash of the WHOLE
# assembled package-lock.json, so it goes stale whenever upstream main or any
# dependency-affecting topic moves. Nothing in the assembly notices: the patch
# is a one-line text edit that applies cleanly whether or not its value is
# right, and `fork-assembler build --locked` reproduces a tree containing a
# wrong hash just as faithfully as a right one. The wrongness surfaces only
# when a consumer builds the desktop package -- i.e. after publishing.
#
# WHY --rebuild, AND WHY A PLAIN `nix build` IS WORTHLESS HERE:
# a fixed-output derivation's store path is computed FROM its declared hash,
# not from its content. If that path is already in the store -- and it is,
# every time, because the last correct build left it there -- nix declares the
# derivation valid and fetches nothing. A stale hash passes in milliseconds and
# looks like proof. Only --rebuild re-runs the fetch and compares the result,
# which is the only thing that actually answers the question. Do not "optimize"
# this back into a plain build.
#
# WHERE THE FETCH RUNS:
# the dependency tree is ~2.6 GB of npm tarballs. Locally that fetch is
# bandwidth-bound and takes hours; a GitHub runner does it in minutes. So by
# default this pushes the build worktree's commit to the scratch branch
# [publish] remote:npm-deps-hash-candidate and dispatches
# .github/workflows/npm-deps-hash.yml, which fetches with a fake hash so it
# always reports the real one. --local runs the old local --rebuild check.
#
# Usage: check-npm-deps-hash.sh [--write] [--local] [BUILD_WORKTREE]
#   --write  on mismatch, rewrite the patch with the correct hash instead of
#            just reporting it (you still need to rebuild afterwards)
#   --local  fetch on this machine instead of in CI

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

write=0
local_fetch=0
worktree=""
for arg in "$@"; do
  case "$arg" in
    --write) write=1 ;;
    --local) local_fetch=1 ;;
    *) worktree="$arg" ;;
  esac
done
worktree="${worktree:-.worktrees/build}"
patch_file="patches/assembled-npm-deps-hash.patch"
hash_file="nix/npm-deps.hash"

if [[ ! -d "$worktree" ]]; then
  echo "error: no build worktree at $worktree; run \`fork-assembler build\` first" >&2
  exit 1
fi
if [[ -n "$(git -C "$worktree" status --porcelain)" ]]; then
  echo "error: $worktree is dirty -- it is mid-build or mid-resolution" >&2
  exit 1
fi

declared="$(cat "$worktree/$hash_file")"
echo "checking assembled npm deps hash: $declared"

# Prints the hash the assembled tree actually produces, or fails.
fetch_hash_in_ci() {
  local remote remote_url commit candidate run_id attempt
  remote="$(awk '/^\[publish\]/{p=1;next} /^\[/{p=0} p && /^[[:space:]]*remote[[:space:]]*=/{sub(/^[^=]*=[[:space:]]*/,"");gsub(/"/,"");print;exit}' manifest.toml)"
  remote_url="$(awk -v r="$remote" '/^\[remotes\]/{p=1;next} /^\[/{p=0} p && $1==r {sub(/^[^=]*=[[:space:]]*/,"");gsub(/"/,"");print;exit}' manifest.toml)"
  if [[ -z "$remote_url" ]]; then
    echo "error: manifest.toml names no URL for the [publish] remote '$remote'" >&2
    return 1
  fi
  commit="$(git -C "$worktree" rev-parse HEAD)"
  candidate="npm-deps-hash-candidate"

  echo "  pushing $commit to $remote:$candidate for the CI fetch" >&2
  git -C "$worktree" push --force --quiet "$remote_url" "$commit:refs/heads/$candidate" >&2

  # Earlier runs can carry the same title, so only a run newer than every run
  # that existed before the dispatch is ours.
  local newest_before
  newest_before="$(gh run list --workflow npm-deps-hash.yml --limit 1 \
    --json databaseId -q '.[0].databaseId // 0')"
  gh workflow run npm-deps-hash.yml --ref main -f ref="$candidate" -f rev="$commit" >&2
  run_id=""
  for ((attempt = 1; attempt <= 30; attempt++)); do
    run_id="$(gh run list --workflow npm-deps-hash.yml --limit 20 \
      --json databaseId,displayTitle \
      -q "map(select(.displayTitle == \"npm deps hash $commit\" and .databaseId > $newest_before)) | .[0].databaseId // empty")"
    [[ -n "$run_id" ]] && break
    sleep 5
  done
  if [[ -z "$run_id" ]]; then
    echo "error: the npm-deps-hash workflow run for $commit never appeared" >&2
    return 1
  fi
  echo "  waiting on CI run $run_id" >&2
  if ! gh run watch "$run_id" --exit-status >/dev/null 2>&1; then
    echo "error: CI run $run_id failed:" >&2
    gh run view "$run_id" --log-failed 2>&1 | tail -30 >&2
    return 1
  fi
  # The run's annotation carries the hash; the log is a fallback because its
  # storage host is the flakier of the two.
  local job got=""
  for ((attempt = 1; attempt <= 5; attempt++)); do
    job="$(gh run view "$run_id" --json jobs -q '.jobs[0].databaseId' 2>/dev/null || true)"
    if [[ -n "$job" ]]; then
      got="$(gh api "repos/{owner}/{repo}/check-runs/$job/annotations" \
        -q '.[] | select(.title == "npm-deps-hash") | .message' 2>/dev/null | head -1 || true)"
    fi
    if [[ -z "$got" ]]; then
      got="$( (gh run view "$run_id" --log 2>/dev/null || true) \
        | grep -oE 'NPM_DEPS_HASH=sha256-[A-Za-z0-9+/=]+' | head -1 | cut -d= -f2- || true)"
    fi
    [[ -n "$got" ]] && break
    sleep 10
  done
  if [[ -z "$got" ]]; then
    echo "error: CI run $run_id succeeded but its hash could not be read" >&2
    return 1
  fi
  echo "$got"
}

# Local mode. --rebuild is what defeats the cached-path illusion above, but it
# only works on a path that IS cached: nix refuses to "check" a derivation it has
# never built ("some outputs ... are not valid"). That is exactly the state right
# after a --write regeneration, where the new hash's path has never been
# realised. In that case a plain build is not the weak check the header warns
# about -- with nothing to substitute, it must actually fetch and compare.
fetch_hash_locally() {
  local log
  log="$(mktemp)"
  if nix build --rebuild --no-link --print-build-logs \
       "path:$worktree#desktop.npmDeps" >"$log" 2>&1; then
    rm -f "$log"
    echo "$declared"
    return 0
  fi
  if grep -q 'are not valid, so checking is not possible' "$log"; then
    echo "  (the declared hash has no store path yet; a plain build must fetch it)" >&2
    if nix build --no-link --print-build-logs \
         "path:$worktree#desktop.npmDeps" >"$log" 2>&1; then
      rm -f "$log"
      echo "$declared"
      return 0
    fi
  fi
  # A hash mismatch is the expected failure. Anything else is a real build
  # error and must not be reported as a stale hash.
  if ! grep -oE 'got: +sha256-[A-Za-z0-9+/=]+' "$log" | head -1 | grep -oE 'sha256-[A-Za-z0-9+/=]+'; then
    echo "error: the dependency fetch failed for a reason other than a hash mismatch:" >&2
    tail -30 "$log" >&2
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
}

if [[ "$local_fetch" -eq 1 ]]; then
  echo "  (re-fetching the dependency tree locally; a cached store path proves nothing here)"
  got="$(fetch_hash_locally)" || { echo "error: the local hash check failed" >&2; exit 1; }
else
  got="$(fetch_hash_in_ci)" || { echo "error: the CI hash check failed" >&2; exit 1; }
fi
if [[ -z "$got" ]]; then
  echo "error: no npm deps hash was reported" >&2
  exit 1
fi
if [[ "$got" == "$declared" ]]; then
  echo "ok: $declared reproduces the assembled package-lock.json"
  exit 0
fi

echo "STALE: $hash_file pins $declared but the assembled tree hashes to $got" >&2

# The patch's "from" side is whatever the tree carries at the patch entry's
# position -- read it from the commit the patch produced, not from the manifest.
# `git log | awk '...{exit}'` looked equivalent and was not: awk closing the
# pipe early kills git log with SIGPIPE, and `pipefail` turns that into a 141
# that aborts the regeneration right before it writes. Let git do the search.
patch_commit="$(git -C "$worktree" log -1 --format='%H' \
  --fixed-strings --grep='fork-assembler: assembled-npm-deps-hash')"
if [[ -z "$patch_commit" ]]; then
  echo "error: no \`fork-assembler: assembled-npm-deps-hash\` commit in $worktree" >&2
  exit 1
fi
before="$(git -C "$worktree" show "$patch_commit^:$hash_file")"

if [[ "$write" -eq 0 ]]; then
  cat >&2 <<EOF

Regenerate the patch and rebuild before publishing:

    scripts/check-npm-deps-hash.sh --write
    fork-assembler build
    fork-assembler build --locked
EOF
  exit 1
fi

cat > "$patch_file" <<EOF
diff --git a/$hash_file b/$hash_file
--- a/$hash_file
+++ b/$hash_file
@@ -1 +1 @@
-$before
+$got
EOF
echo "wrote $patch_file: $before -> $got"
echo "now run \`fork-assembler build\` -- the patch entry's blob changed, so the"
echo "stack rebuilds from its position -- then \`fork-assembler build --locked\`."
