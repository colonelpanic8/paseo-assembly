# fork-assembler maintenance repository

This repository is a [fork-assembler](https://github.com/colonelpanic8/fork-assembler)
stack: a build recipe assembling an upstream base plus an ordered set of live
topic branches into a single branch, with tracked conflict resolutions.

## Repository checkout

- Work directly in this assembler repository's primary checkout. Do not create
  or use a separate Git worktree for repository maintenance unless the user
  explicitly requests one.
- This does not prohibit the temporary build worktrees that `fork-assembler` creates
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
fork-assembler status                 # lock vs. manifest vs. live refs; flags merged entries
fork-assembler add REMOTE:BRANCH      # append a topic branch entry
fork-assembler add --pr N             # append a PR entry
fork-assembler add --patch FILE       # append a standalone patch entry
fork-assembler add --prs-from USER    # append USER's open PRs not already carried (idempotent)
fork-assembler fixup ENTRY FILE       # attach a coherence fixup to ENTRY's own step
fork-assembler fixup ENTRY FILE --capture   # ...writing FILE from the build worktree
fork-assembler fixup ENTRY --remove   # detach it (the patch file stays on disk)
fork-assembler build                  # assemble from lock pins; incremental for appends
fork-assembler build --locked         # reproduce exactly; no network, no new pins
fork-assembler update [ENTRY...]      # batch bump: repin base + entries to live heads
fork-assembler prune [--dry-run]      # drop entries whose changes landed in the base
just publish                     # push the locked tree to [publish] (not a fork-assembler verb)
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
3. Run `fork-assembler continue` — it harvests the conflict's preimage/postimage
   pair into `resolutions/rerere/` and updates the informational index.
4. Run `fork-assembler build --locked` after the repair completes to prove the
   tracked pairs reproduce the lock's tree.
5. Commit the manifest, lock, and tracked pairs together.

## Publishing — a build is not done until it is pushed

Committing the recipe changes nothing on its own. Nothing here builds this
checkout: CI and every consumer read the branch `manifest.toml`'s `[publish]`
section names (`mine:assembled`), waiting for it to carry the tree that
`manifest.lock.json` pins and then building that commit by `rev`. A rebuild
that lands in `main` but not on that branch fails every workflow with
`Published assembly tree mismatch`, which reads like a build failure and is
not one.

So whenever a build reports `tree CHANGED`, finish the cycle:

```sh
fork-assembler build --locked         # prove the tracked inputs reproduce the tree
just publish                     # push that tree to [publish] (scripts/publish-assembly.sh)
```

`just publish` refuses to push a dirty or stale build worktree, so it is safe
to run when unsure; if the tree is already published it says so and exits. It
also runs `scripts/check-npm-deps-hash.sh`, because reproducing the locked tree
proves the build is the one the lock pins, not that it is correct: the assembled
npm deps hash goes stale silently and only breaks for consumers. Never verify
that hash with a plain `nix build` — an FOD's store path is derived from its
declared hash, so a stale one passes instantly on the path the last good build
left behind. The script forces the re-fetch; `--write` regenerates the patch.
Push the commit that carries the locked *tree* — the commit id is not the
invariant, and a `--locked` rerun legitimately re-commits the same tree under
a new id. The push force-updates, because the assembled branch is compiled
output that is re-committed rather than fast-forwarded.

fork-assembler itself has no publish verb. It parses `[publish]` for the build's
provenance stamp only; the push is site policy and lives in this repository.

## Skills

Reusable operation guides live under `.agents/skills/` in the open
[Agent Skills](https://agentskills.io) format (`SKILL.md` with YAML
frontmatter). `.claude/skills/` and `.codex/skills/` are symlinks into it so
Claude Code and Codex discover the same skills; agents without a skills
mechanism should read `.agents/skills/*/SKILL.md` directly.

The checked-in skill is deliberately only a stable discovery stub. It tells
the agent to load `lib.forkAssemblerAgentGuide`, which this repository's flake
re-exports directly from its pinned `fork-assembler` input. The full instructions
therefore change with `flake.lock`; do not copy their output into this
repository.

## Committing

Commit `manifest.toml`, `manifest.lock.json`, `resolutions/`, and `patches/`
changes together with explicit paths. Then publish the assembled tree — see
above; the commit alone does not ship it. Remaining install steps (tagging,
downstream pinning) are site-specific — see this repository's justfile or
README.
