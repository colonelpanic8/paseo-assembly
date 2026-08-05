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

# Push the assembled tree to the [publish] branch and verify the npm deps hash
# in parallel. This is the final publish-stage check; ordinary update/build
# operations do not run it.
publish:
    scripts/publish-assembly.sh

# Publish without the final npm deps hash check.
publish-fast:
    scripts/publish-assembly.sh --skip-hash-check

# Build the desktop package from the published assembly, exactly as CI does.
desktop:
    #!/usr/bin/env bash
    set -euo pipefail
    rev="$(scripts/await-published-assembly.sh manifest.lock.json https://github.com/colonelpanic8/paseo assembled 1 0)"
    nix build --print-build-logs \
        "git+https://github.com/colonelpanic8/paseo?ref=assembled&rev=${rev}#desktop"
