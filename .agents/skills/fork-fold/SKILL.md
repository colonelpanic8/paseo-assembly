---
name: fork-fold
description: Operate this fork-fold maintenance repository - append topic branches or PRs to the stack, rebuild the assembled branch, resolve stopped builds and record conflict resolutions, and report staleness. Use when asked to add a branch or PR to the stack, rebuild or reproduce the assembly, continue a build stopped on a conflict, or check what is stale.
---

# Operating a fork-fold stack

Read `AGENTS.md` in the repository root first — it states the model and the
invariants. The short version: `manifest.toml` is intent, `manifest.lock.json`
is fact, the assembled branch is disposable compiled output, and conflict
resolutions live only in tracked files under `resolutions/`.

## Reporting status

Run `fork-fold status`. Report: which entries' live refs have moved past the
lock's pins, whether the manifest is a prefix-extension of the lock (append =
cheap incremental build; reorder/removal = suffix rebuild with likely
re-resolution), and whether the last build completed.

## Appending to the stack

1. `fork-fold add REMOTE:BRANCH` (or `--pr N`, or `--patch FILE`). For a new
   fork, first add it under `[remotes]` in `manifest.toml`.
2. `fork-fold build` — appends build incrementally from the last assembled
   commit.
3. If it completes: commit `manifest.toml` and `manifest.lock.json` together
   (explicit paths; unrelated local changes may exist).

## When a build stops on a conflict

1. Go to the build worktree it reports (under `.worktrees/`).
2. Resolve the conflicted files. Judge each resolution against what the
   topic and the earlier stack each intend — do not mechanically prefer one
   side. If the correct fix is topic-internal, fix the topic branch instead
   and rebuild.
3. `git add` the resolved files, then run `fork-fold continue`.
4. Commit the updated `resolutions/<entry>.toml`, `resolutions/<entry>.patch`,
   manifest, and lock together.

A stop marked PROPOSED means a stale resolution was replayed 3-way: review
the staged result carefully before `fork-fold continue` — inputs moved since
it was recorded.

## Verification

After any build, `fork-fold build --locked` from a clean state must reproduce
the lock's tree hash. Never enable git rerere; never develop on or merge from
the assembled branch.
