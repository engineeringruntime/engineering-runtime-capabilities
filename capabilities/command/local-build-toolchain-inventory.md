# Local build toolchain inventory

Report the Git and Docker client versions available to a local build workflow.
Both checks are context-free and do not authenticate, contact a remote, or
require a running Docker daemon.

GitHub intentionally is not checked through `binary: gh`: raw gh is
context-unsupported because it can infer a repository and host. Use curated
`provider: github` operations instead.

```runtime
version: v1

workflow:
  - binary: git
    args: [--version]
  - binary: docker
    args: [--version]
```
