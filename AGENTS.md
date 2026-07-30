# fork-fold maintenance repository

This repository is a [fork-fold](https://github.com/colonelpanic8/fork-fold)
stack: a build recipe assembling an upstream base plus an ordered set of live
topic branches into a single branch, with tracked conflict resolutions.

## Repository checkout

- Work directly in this assembler repository's primary checkout. Do not create
  or use a separate Git worktree for repository maintenance unless the user
  explicitly requests one.
- This does not prohibit the temporary build worktrees that `fork-fold` creates
  and manages as part of its normal operation.
- This repository is main-only: synchronize with `origin/main` before any
  maintenance, and commit and push recipe changes directly to `main`. Do not
  create or publish side branches for assembler maintenance.

## Model

- `manifest.toml` is INTENT: named remotes, the base, and the ordered entries
  (branches, PRs, patch files).
- `manifest.lock.json` is FACT: the OIDs the last build used, the assembled
  commit, and its tree hash. The tree hash is the reproducibility invariant;
  commit IDs are not.
- `resolutions/rerere/<hash>/{preimage,postimage}` are tracked git-rerere
  pairs replaying each conflicted merge's hunks. Every build seeds the build
  worktree's rr-cache exclusively from them (wiped first, so nothing ambient
  leaks in) and auto-resolves recognized conflicts.
  `resolutions/rerere/INDEX.toml` records which entry produced which pairs —
  informational only, never load-bearing.
- `patches/` holds two things. A **coherence fixup** (`fixup = "..."` on a
  branch or pr entry) is applied inside THAT entry's own step, right after
  its merge: it repairs what admitting the entry alongside the earlier ones
  broke — a cross-topic semantic clash, or an edit a resolution needs OUTSIDE
  the conflict hunks (rerere pairs cannot capture those). A standalone
  **patch entry** (`patch = "..."`) applies at its own position and is for
  content belonging to no entry — here that is `assembled-npm-deps-hash`,
  which is a function of the whole assembled dependency tree.

## Invariants — do not violate

- The assembled branch is compiled output. Never commit to it, never base
  work on it, never merge it back into a topic branch.
- Topic branches stay minimal diffs against upstream; they are still
  candidates for upstream merge. Fix topic-specific problems on the topic
  branch, not in a resolution or patch entry.
- Conflict knowledge lives only in the tracked pairs under
  `resolutions/rerere/`. Builds enable rerere per-command and reseed its
  cache from the tracked pairs every run; never enable rerere persistently
  or let a machine-local cache feed a build.
- Rerere pairs capture only conflicted-hunk resolutions. If a correct
  resolution also needs edits outside the conflict hunks, put those edits in
  that entry's coherence fixup — a rebuild will otherwise surface them as a
  tree mismatch. The lock's tree hash is the sole verification invariant.
- Every entry boundary should be a coherent tree. A cross-entry repair
  belongs on the entry that made it necessary (its `fixup`), not in a patch
  entry parked later in the stack.
- A fixup repairs an interaction BETWEEN entries. When `remove` or `prune`
  reports one as orphaned, decide explicitly whether to re-home it onto the
  surviving entry or delete it — a topic landing upstream usually does not
  dissolve the incoherence.
- Appending entries is cheap (incremental build of the tail). Reordering or
  removing entries, or editing a fixup, invalidates every later entry's
  build — expect re-resolution from that point.

## Operations

```sh
fork-fold status                 # lock vs. manifest vs. live refs; flags merged entries
fork-fold add REMOTE:BRANCH      # append a topic branch entry
fork-fold add --pr N             # append a PR entry
fork-fold add --patch FILE       # append a standalone patch entry
fork-fold add --prs-from USER    # append USER's open PRs not already carried (idempotent)
fork-fold fixup ENTRY FILE       # attach a coherence fixup to ENTRY's own step
fork-fold fixup ENTRY FILE --capture   # ...writing FILE from the build worktree
fork-fold fixup ENTRY --remove   # detach it (the patch file stays on disk)
fork-fold build                  # assemble from lock pins; incremental for appends
fork-fold build --locked         # reproduce exactly; no network, no new pins
fork-fold update [ENTRY...]      # batch bump: repin base + entries to live heads
fork-fold prune [--dry-run]      # drop entries whose changes landed in the base
```

`build` never moves existing pins; `update` is the only verb that does. The
repair cycle after a bump is: `update`, then `build`, fixing each unrecognized
conflict as the build stops. Recognized conflict hunks resolve automatically
from the tracked pairs. When a PR merges upstream, `update` the base past the
merge and `prune` the dead entry in the same cycle.

When a build stops on a conflict:

1. Resolve the conflicted files in the build worktree it reports (under
   `.worktrees/`).
2. Stage the resolutions with `git add`.
3. Run `fork-fold continue` — it harvests the conflict's preimage/postimage
   pair into `resolutions/rerere/` and updates the informational index.
4. Run `fork-fold build --locked` after the repair completes to prove the
   tracked pairs reproduce the lock's tree.
5. Commit the manifest, lock, and tracked pairs together.

## Skills

Reusable operation guides live under `.agents/skills/` in the open
[Agent Skills](https://agentskills.io) format (`SKILL.md` with YAML
frontmatter). `.claude/skills/` and `.codex/skills/` are symlinks into it so
Claude Code and Codex discover the same skills; agents without a skills
mechanism should read `.agents/skills/*/SKILL.md` directly.

The checked-in skill is deliberately only a stable discovery stub. It tells
the agent to load `lib.forkFoldAgentGuide`, which this repository's flake
re-exports directly from its pinned `fork-fold` input. The full instructions
therefore change with `flake.lock`; do not copy their output into this
repository.

## Committing

Commit `manifest.toml`, `manifest.lock.json`, `resolutions/`, and `patches/`
changes together with explicit paths. Publish/install steps (pushing the
assembled branch, tagging, downstream pinning) are site-specific — see this
repository's justfile or README.
