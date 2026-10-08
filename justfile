build:
    fork-assembler build

status:
    fork-assembler status

continue:
    fork-assembler continue

# Verify the assembled npm dependency hash against the assembled
# package-lock.json by fetching in CI (--local fetches here instead). `publish`
# runs this alongside the push. Add --write to regenerate the patch.
check-npm-deps-hash *ARGS:
    scripts/check-npm-deps-hash.sh {{ARGS}}

# Typecheck the build worktree's commit in CI without publishing it.
typecheck-candidate:
    scripts/check-candidate-typecheck.sh

# Push the assembled tree to the [publish] branch, checking the npm deps hash in
# CI in parallel. Ordinary update/build operations do not run the check.
publish:
    scripts/publish-assembly.sh

# Publish without the npm deps hash check.
publish-fast:
    scripts/publish-assembly.sh --skip-checks

# Build the desktop package from the published assembly, exactly as CI does.
desktop:
    #!/usr/bin/env bash
    set -euo pipefail
    rev="$(scripts/await-published-assembly.sh manifest.lock.json https://github.com/colonelpanic8/paseo assembled 1 0)"
    nix build --print-build-logs \
        "git+https://github.com/colonelpanic8/paseo?ref=assembled&rev=${rev}#desktop"
