#!/usr/bin/env bash
# Typecheck the build worktree's commit in CI before it is published.
#
# The assembler merges and never compiles, so a tree that `build --locked`
# reproduces exactly can still fail to typecheck -- most often when a topic
# calls an upstream API whose signature moved after the topic was written.
# Typecheck Assembly runs on the published tree after every publish; this
# optional pre-check dispatches the same workflow against the build worktree's
# commit for a change risky enough to be worth waiting on.
#
# Usage: check-candidate-typecheck.sh [BUILD_WORKTREE]

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

worktree="${1:-.worktrees/build}"
if [[ ! -d "$worktree" ]]; then
  echo "error: no build worktree at $worktree; run \`fork-assembler build\` first" >&2
  exit 1
fi
if [[ -n "$(git -C "$worktree" status --porcelain)" ]]; then
  echo "error: $worktree is dirty -- it is mid-build or mid-resolution" >&2
  exit 1
fi

# shellcheck source=scripts/lib/candidate-ci.sh
source "$repo_root/scripts/lib/candidate-ci.sh"

echo "typechecking the candidate assembly in CI"
commit="$(push_candidate "$worktree")"
run_candidate_workflow typecheck.yml "typecheck $commit" "$commit" >/dev/null
echo "ok: $commit typechecks"
