#!/usr/bin/env bash
# Typecheck the build worktree's commit in CI before it is published.
#
# The assembler merges and never compiles, so a tree that `build --locked`
# reproduces exactly can still fail to typecheck -- most often when a topic
# calls an upstream API whose signature moved after the topic was written.
# Typecheck Assembly normally runs on the published tree, which is too late:
# every consumer already has it. This dispatches the same workflow against the
# candidate commit instead.
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
