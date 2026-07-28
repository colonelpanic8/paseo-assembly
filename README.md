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

The checked-in agent skill is only a stable discovery stub. It loads the full
operating guide from `lib.forkFoldAgentGuide`, which is re-exported directly
from the `fork-fold` revision in `flake.lock`. Updating that input therefore
updates the guide without copying or synchronizing it into this repository.
