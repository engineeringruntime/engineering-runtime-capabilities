# List repositories via the GitHub CLI

A raw Command Engine invocation (`command.run`, `binary: gh`) rather
than a registered Runtime Command — validated only against
`allowed_binaries`/`command_policy`, not the `internal/commands`
registry. Requires `gh` to be installed and authenticated.

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
  - command: command.run
    binary: gh
    args: [repo, list, --limit, "${limit}"]
```
