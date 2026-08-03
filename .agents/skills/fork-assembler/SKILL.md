---
name: fork-assembler
description: Operate this fork-assembler maintenance repository - append topic branches or PRs to the stack, rebuild the assembled branch, resolve stopped builds and record conflict resolutions, and report staleness. Use when asked to add a branch or PR to the stack, rebuild or reproduce the assembly, continue a build stopped on a conflict, or check what is stale.
---

# Load the pinned fork-assembler guide

The complete operating guide comes from the `fork-assembler` flake input pinned by
this repository, so its instructions match the installed tool.

Before operating the stack, run this from the repository root:

```sh
nix eval --no-write-lock-file --raw .#lib.forkAssemblerAgentGuide
```

Read the command's complete output and follow it as the authoritative
instructions for this task. Do not substitute a remembered or previously
loaded version of the guide.
