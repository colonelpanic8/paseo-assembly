build:
    fork-assembler build

status:
    fork-assembler status

continue:
    fork-assembler continue

# Verify the assembled npm dependency hash against the assembled
# package-lock.json. `publish` runs this too; run it directly after any build
# that moved a dependency-affecting entry. Add --write to regenerate the patch.
check-npm-deps-hash *ARGS:
    scripts/check-npm-deps-hash.sh {{ARGS}}

# Push the assembled tree to the [publish] branch. Required after any build
# that changed the tree -- CI builds the published branch, not this checkout,
# and fails with a tree mismatch until this runs.
publish:
    scripts/publish-assembly.sh

# Build the desktop package from the published assembly, exactly as CI does.
desktop:
    #!/usr/bin/env bash
    set -euo pipefail
    rev="$(scripts/await-published-assembly.sh manifest.lock.json https://github.com/colonelpanic8/paseo assembled 1 0)"
    nix build --print-build-logs \
        "git+https://github.com/colonelpanic8/paseo?ref=assembled&rev=${rev}#desktop"
