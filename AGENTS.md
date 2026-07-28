# fork-fold maintenance repository

This repository is a [fork-fold](https://github.com/colonelpanic8/fork-fold)
stack: a build recipe assembling an upstream base plus an ordered set of live
topic branches into a single branch, with tracked conflict resolutions.

## Model

- `manifest.toml` is INTENT: named remotes, the base, and the ordered entries
  (branches, PRs, patch files).
- `manifest.lock.json` is FACT: the OIDs the last build used, the assembled
  commit, and its tree hash. The tree hash is the reproducibility invariant;
  commit IDs are not.
- `resolutions/<entry>.toml` + `resolutions/<entry>.patch` replay each
  conflicted merge: a full first-parent-tree to resolved-tree diff, applied
  only when the recorded inputs match, proposed via 3-way merge when stale.
- `patches/` holds patch entries: the escape hatch for cross-topic semantic
  fixes with no home on any single branch.

## Invariants — do not violate

- The assembled branch is compiled output. Never commit to it, never base
  work on it, never merge it back into a topic branch.
- Topic branches stay minimal diffs against upstream; they are still
  candidates for upstream merge. Fix topic-specific problems on the topic
  branch, not in a resolution or patch entry.
- Conflict knowledge lives only in tracked resolution files. Git rerere is
  disabled during builds; never re-enable it or rely on a local cache.
- Appending entries is cheap (incremental build of the tail). Reordering or
  removing entries invalidates every later entry's build — expect
  re-resolution from that point.

## Operations

```sh
fork-fold status                 # lock vs. manifest vs. live refs
fork-fold add REMOTE:BRANCH      # append a topic branch entry
fork-fold add --pr N             # append a PR entry
fork-fold add --patch FILE       # append a patch entry
fork-fold build                  # fetch and assemble; incremental for appends
fork-fold build --locked         # reproduce from pinned OIDs, no fetching
```

When a build stops on a conflict:

1. Resolve the conflicted files in the build worktree it reports (under
   `.worktrees/`).
2. Stage the resolutions with `git add`.
3. Run `fork-fold continue` — it records or rewrites the entry's resolution
   sidecar files under `resolutions/`.
4. Commit the manifest, lock, and resolution files together.

When a build stops with a PROPOSED resolution (a stale record replayed
3-way), review the staged result, fix it if needed, then `fork-fold continue`.

## Skills

Reusable operation guides live under `.agents/skills/` in the open
[Agent Skills](https://agentskills.io) format (`SKILL.md` with YAML
frontmatter). `.claude/skills/` and `.codex/skills/` are symlinks into it so
Claude Code and Codex discover the same skills; agents without a skills
mechanism should read `.agents/skills/*/SKILL.md` directly.

## Committing

Commit `manifest.toml`, `manifest.lock.json`, `resolutions/`, and `patches/`
changes together with explicit paths. Publish/install steps (pushing the
assembled branch, tagging, downstream pinning) are site-specific — see this
repository's justfile or README.
