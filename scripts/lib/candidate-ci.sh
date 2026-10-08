# shellcheck shell=bash
# Shared by the pre-publish checks: run a workflow against the build worktree's
# commit before that commit is published.
#
# The candidate is pushed to the scratch branch assembly-candidate on the
# [publish] remote so runners can fetch it; [publish] itself is untouched until
# every check passes. Source this file; it expects manifest.toml in the cwd.

candidate_branch="assembly-candidate"

# Prints the URL of manifest.toml's [publish] remote.
publish_remote_url() {
  local remote
  remote="$(awk '/^\[publish\]/{p=1;next} /^\[/{p=0} p && /^[[:space:]]*remote[[:space:]]*=/{sub(/^[^=]*=[[:space:]]*/,"");gsub(/"/,"");print;exit}' manifest.toml)"
  awk -v r="$remote" '/^\[remotes\]/{p=1;next} /^\[/{p=0} p && $1==r {sub(/^[^=]*=[[:space:]]*/,"");gsub(/"/,"");print;exit}' manifest.toml
}

# push_candidate WORKTREE -- pushes WORKTREE's HEAD and prints its commit.
push_candidate() {
  local worktree="$1" url commit
  url="$(publish_remote_url)"
  if [[ -z "$url" ]]; then
    echo "error: manifest.toml names no URL for the [publish] remote" >&2
    return 1
  fi
  commit="$(git -C "$worktree" rev-parse HEAD)"
  echo "  pushing $commit to $candidate_branch for CI" >&2
  git -C "$worktree" push --force --quiet "$url" "$commit:refs/heads/$candidate_branch" >&2
  echo "$commit"
}

# run_candidate_workflow WORKFLOW TITLE COMMIT -- dispatches WORKFLOW for COMMIT,
# waits for it, and prints the run id. Fails if the run fails. The workflow's
# run-name must be TITLE.
run_candidate_workflow() {
  local workflow="$1" title="$2" commit="$3" newest_before run_id="" attempt
  # Earlier runs can carry the same title, so only a run newer than every run
  # that existed before the dispatch is ours.
  newest_before="$(gh run list --workflow "$workflow" --limit 1 \
    --json databaseId -q '.[0].databaseId // 0')"
  gh workflow run "$workflow" --ref main -f ref="$candidate_branch" -f rev="$commit" >&2
  for ((attempt = 1; attempt <= 30; attempt++)); do
    run_id="$(gh run list --workflow "$workflow" --limit 20 \
      --json databaseId,displayTitle \
      -q "map(select(.displayTitle == \"$title\" and .databaseId > $newest_before)) | .[0].databaseId // empty")"
    [[ -n "$run_id" ]] && break
    sleep 5
  done
  if [[ -z "$run_id" ]]; then
    echo "error: the $workflow run for $commit never appeared" >&2
    return 1
  fi
  echo "  waiting on $workflow run $run_id" >&2
  if ! gh run watch "$run_id" --exit-status >/dev/null 2>&1; then
    echo "error: $workflow run $run_id failed:" >&2
    gh run view "$run_id" --log-failed 2>&1 | tail -30 >&2
    return 1
  fi
  echo "$run_id"
}
