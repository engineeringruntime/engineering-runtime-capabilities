# Command Engine capabilities

These capabilities run allowlisted engineering CLIs through `binary:` steps.
They are not providers: Runtime pins and governs the executable, while the
upstream CLI owns its command surface and native authentication.

## Index

| Capability | Binaries | Inputs |
|---|---|---|
| `git-change-readiness.md` | `git` | `workdir`, `base_ref` |
| `local-build-toolchain-inventory.md` | `git`, `docker` | — |
| `docker-build-readiness.md` | `docker` | — |

Run `runtime --output json capability authoring-context` first and confirm each
required binary is installed. Validation proves the binary is allowlisted; it
does not prove the executable exists or that an external platform is reachable.

All three definitions are read-only. They deliberately use only context-free
Command Engine paths. GitHub work uses the curated provider; Kubernetes and
cloud CLIs need an explicitly bound native target and belong in target-specific
capabilities rather than a generic local inventory.
