# paseo assembly

This repository is a [fork-fold](https://github.com/colonelpanic8/fork-fold)
stack: an upstream base plus an ordered set of live topic branches, assembled
into a single branch with tracked conflict resolutions.

- `manifest.toml` -- intent: remotes, base, ordered entries.
- `manifest.lock.json` -- fact: the OIDs and tree hash of the last build.
- `resolutions/rerere/` -- tracked preimage/postimage pairs replaying
  conflicted hunks.
- `patches/` -- patch entries (escape hatch for cross-topic semantic fixes).

Common operations:

```sh
fork-fold add mine:some-branch   # append a topic
fork-fold build                  # assemble (incremental for appends)
fork-fold status                 # lock vs. manifest vs. live refs
```

The assembled branch is compiled output. Never develop on it, never merge it
back into a topic.

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

To consume the cache locally:

```sh
cachix use paseo-colonelpanic8
nix build github:colonelpanic8/paseo/assembled#desktop
```

Or add it to `nix.settings` persistently:

```nix
nix.settings = {
  substituters = [ "https://paseo-colonelpanic8.cachix.org" ];
  trusted-public-keys = [ "paseo-colonelpanic8.cachix.org-1:<key from the cache page>" ];
};
```

CI needs one repository secret, `CACHIX_AUTH_TOKEN` -- a write token created
with `cachix authtoken` or from the cache's settings page. Without it the build
still runs and simply does not push.

The checked-in agent skill is only a stable discovery stub. It loads the full
operating guide from `lib.forkFoldAgentGuide`, which is re-exported directly
from the `fork-fold` revision in `flake.lock`. Updating that input therefore
updates the guide without copying or synchronizing it into this repository.
