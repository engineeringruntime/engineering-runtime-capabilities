# Local Git change readiness

Inspect a checkout before review or publication: working-tree state, whitespace
errors, recent history, and the commits ahead of a caller-selected base ref.
Nothing is staged, committed, reset, or pushed.

```runtime
version: v1

inputs:
  workdir:
    description: Absolute path to the Git working tree
    required: true
  base_ref:
    description: Reviewed base ref, for example origin/main
    required: true

workflow:
  - binary: git
    args: [-C, "${workdir}", status, --short]
  - binary: git
    args: [-C, "${workdir}", diff, --check]
  - binary: git
    args: [-C, "${workdir}", log, -5, --oneline]
  - binary: git
    args: [-C, "${workdir}", log, --oneline, "${base_ref}..HEAD"]
```
