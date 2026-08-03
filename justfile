build:
    fork-assembler build

status:
    fork-assembler status

continue:
    fork-assembler continue

# Verify the assembled npm dependency hash against the assembled
# package-lock.json. `publish` runs this after pushing; run it directly after
# any build that moved a dependency-affecting entry. Add --write to regenerate
# the patch.
check-npm-deps-hash *ARGS:
    scripts/check-npm-deps-hash.sh {{ARGS}}

# Push the assembled tree to the [publish] branch, then verify the npm deps
# hash. Required after any build that changed the tree -- CI builds the
# published branch, not this checkout, and fails with a tree mismatch until
# this runs. The push comes first because it is what unblocks CI; the slow
# hash check follows and, if stale, is repaired as a follow-up publish.
publish:
    scripts/publish-assembly.sh

# Publish without the slow npm deps hash check. Use when the check is being
# deferred deliberately -- `just check-npm-deps-hash` still owes a run.
publish-fast:
    scripts/publish-assembly.sh --skip-hash-check

# Build the desktop package from the published assembly, exactly as CI does.
desktop:
    #!/usr/bin/env bash
    set -euo pipefail
    rev="$(scripts/await-published-assembly.sh manifest.lock.json https://github.com/colonelpanic8/paseo assembled 1 0)"
    nix build --print-build-logs \
        "git+https://github.com/colonelpanic8/paseo?ref=assembled&rev=${rev}#desktop"
