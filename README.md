# paseo assembly

This repository is a [fork-assembler](https://github.com/colonelpanic8/fork-assembler)
stack: an upstream base plus an ordered set of live topic branches, assembled
into a single branch with tracked conflict resolutions.

- `manifest.toml` -- intent: remotes, base, ordered entries.
- `manifest.lock.json` -- fact: the OIDs and tree hash of the last build.
- `resolutions/rerere/` -- tracked preimage/postimage pairs replaying
  conflicted hunks.
- `patches/` -- patch entries (escape hatch for cross-topic semantic fixes).

Common operations:

```sh
fork-assembler add mine:some-branch   # append a topic
fork-assembler build                  # assemble (incremental for appends)
fork-assembler status                 # lock vs. manifest vs. live refs
just publish                     # push the assembled tree to [publish]
```

The assembled branch is compiled output. Never develop on it, never merge it
back into a topic.

`just publish` is the step that ships a rebuild. Nothing below builds this
checkout — CI and the install commands all read the published `assembled`
branch, so a build that is committed here but never pushed there leaves every
workflow failing on a tree mismatch. fork-assembler has no publish verb; the push
is site policy, in `scripts/publish-assembly.sh`, and it takes its target from
the `[publish]` section of `manifest.toml`. Push the recipe to `main` before
running `just publish`; its slow npm dependency-hash check runs only at this
final stage, in parallel with the `assembled` push.

## Desktop builds and the binary cache

`.github/workflows/desktop.yml` builds `packages.x86_64-linux.desktop` from the
published `assembled` branch and pushes the result to the
[`paseo-colonelpanic8`](https://app.cachix.org/cache/paseo-colonelpanic8)
Cachix cache on every push to `main` that changes the recipe, and on manual
dispatch.

It does not build this repository's checkout -- there is no app source here.
It waits (via `scripts/await-published-assembly.sh`) until the published
`assembled` branch carries the tree that `manifest.lock.json` pins, then builds
that commit by `rev` through a `git+https://` flake reference. Building from
the URL rather than a local worktree is deliberate: the flake reads `self.rev`
for its build-provenance stamp, and only a clean git source has one.

Install the latest assembled desktop build straight from the cache, in one line
(no `cachix use`, nothing added to your config):

```sh
nix profile install github:colonelpanic8/paseo/assembled#desktop --extra-substituters https://paseo-colonelpanic8.cachix.org --extra-trusted-public-keys paseo-colonelpanic8.cachix.org-1:fxfDiskEv5JT+xX3CbXBUAWblc+234mDeodXDi7eY1k=
```

Use `nix run` in place of `nix profile install` to launch it without installing.
Nix only honours `--extra-trusted-public-keys` for a trusted user (root, or
listed in `nix.settings.trusted-users`); an untrusted user silently gets a full
source build instead. Register the cache once to avoid that:

```sh
cachix use paseo-colonelpanic8
nix build github:colonelpanic8/paseo/assembled#desktop
```

Or add it to `nix.settings` persistently:

```nix
nix.settings = {
  substituters = [ "https://paseo-colonelpanic8.cachix.org" ];
  trusted-public-keys = [
    "paseo-colonelpanic8.cachix.org-1:fxfDiskEv5JT+xX3CbXBUAWblc+234mDeodXDi7eY1k="
  ];
};
```

The cache holds `x86_64-linux` only, since that is all `desktop.yml` builds.

CI needs one repository secret, `CACHIX_AUTH_TOKEN` -- a write token created
with `cachix authtoken` or from the cache's settings page. Without it the build
still runs and simply does not push.

## Downloadable desktop installers

`.github/workflows/desktop-release.yml` publishes real installers for the same
locked assembled tree to this repository's
[Releases](https://github.com/colonelpanic8/paseo-assembly/releases). The newest
release is always the current assembly, so the download link is stable:

```
https://github.com/colonelpanic8/paseo-assembly/releases/latest
```

It runs upstream's `electron-builder` configuration rather than Nix -- a Nix
store path is not something you can download and double-click. If you are on
Nix, prefer the Cachix route above; these artifacts are for machines that are
not.

Exactly one artifact per platform:

- Linux x64: `Paseo-x86_64.AppImage` (`chmod +x` and run).
- macOS arm64 and x64: `.dmg` -- **unsigned and unnotarized**; Gatekeeper must
  be overridden by hand.
- Windows x64: NSIS installer -- **unsigned**; SmartScreen warns.

Upstream targets every packaging it can (AppImage/deb/rpm/tar.gz, dmg+zip,
nsis+zip, plus a combined multi-arch installer), which put 23 files and ~2.3GB
on each release -- mostly a second packaging of an identical app. The workflow
overrides `linux.target`, `mac.target` and `win.target` down to one each.

The small `latest.yml`/`latest-linux.yml` and `.blockmap` files are kept
deliberately: they are the auto-update feed, and a blockmap lets
electron-updater fetch only the changed chunks of an installer rather than
redownloading it whole. `builder-debug.yml` is dropped.

Releases are tagged `desktop-assembly-<run number>` and the version is
`<upstream base>-assembly.<run number>+<tree prefix>`, which orders below any
upstream release of the same base version and names the tree it came from. The
`prune` job keeps the newest five releases and deletes older ones with their
tags (`KEEP_RELEASES` in the workflow).

The bundled auto-update feed is repointed at this repository. Upstream's
`electron-builder.yml` publishes to `getpaseo/paseo`; left alone, an installed
assembly build would update itself to an upstream release and silently drop
every carried topic. macOS gets no update manifest at all, since unsigned
builds cannot auto-update.

Only the built-in `GITHUB_TOKEN` is required -- no signing secrets.

The checked-in agent skill is only a stable discovery stub. It loads the full
operating guide from `lib.forkAssemblerAgentGuide`, which is re-exported directly
from the `fork-assembler` revision in `flake.lock`. Updating that input therefore
updates the guide without copying or synchronizing it into this repository.
