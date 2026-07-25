# List repositories via the GitHub CLI

A raw Command Engine invocation (`binary: gh`) — validated against
`allowed_binaries`/`command_policy` rather than against the GitHub
Provider's operation surface. The provider exposes a `repo list`
operation that does the same job and lets the provider choose the
transport; this file exists to demonstrate the escape hatch. Requires `gh` to be installed and authenticated.

Run with:

```
runtime capability validate github/github-cli-repo-list.md
runtime capability execute github/github-cli-repo-list.md --input limit=10
```

```runtime
version: v1

inputs:
  limit:
    description: Maximum number of repositories to list
    required: true

workflow:
  - binary: gh
    args: [repo, list, --limit, "${limit}"]
```
