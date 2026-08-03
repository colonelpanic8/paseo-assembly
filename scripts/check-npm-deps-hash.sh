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
# Usage: check-npm-deps-hash.sh [--write] [BUILD_WORKTREE]
#   --write  on mismatch, rewrite the patch with the correct hash instead of
#            just reporting it (you still need to rebuild afterwards)

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

write=0
worktree=""
for arg in "$@"; do
  case "$arg" in
    --write) write=1 ;;
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
echo "  (re-fetching the dependency tree; a cached store path proves nothing here)"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

# --rebuild is what defeats the cached-path illusion above, but it only works on
# a path that IS cached: nix refuses to "check" a derivation it has never built
# ("some outputs ... are not valid"). That is exactly the state right after a
# --write regeneration, where the new hash's path has never been realised. In
# that case a plain build is not the weak check the header warns about -- with
# nothing to substitute, it must actually fetch and compare.
if nix build --rebuild --no-link --print-build-logs \
     "path:$worktree#desktop.npmDeps" >"$log" 2>&1; then
  echo "ok: $declared reproduces the assembled package-lock.json"
  exit 0
fi

if grep -q 'are not valid, so checking is not possible' "$log"; then
  echo "  (the declared hash has no store path yet; a plain build must fetch it)"
  if nix build --no-link --print-build-logs \
       "path:$worktree#desktop.npmDeps" >"$log" 2>&1; then
    echo "ok: $declared reproduces the assembled package-lock.json"
    exit 0
  fi
fi

# A hash mismatch is the expected failure. Anything else is a real build error
# and must not be reported as a stale hash.
got="$(grep -oE 'got: +sha256-[A-Za-z0-9+/=]+' "$log" | head -1 | grep -oE 'sha256-[A-Za-z0-9+/=]+' || true)"
if [[ -z "$got" ]]; then
  echo "error: the dependency fetch failed for a reason other than a hash mismatch:" >&2
  tail -30 "$log" >&2
  exit 1
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
