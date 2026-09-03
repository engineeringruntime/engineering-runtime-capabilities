# List repositories via the GitHub CLI

A raw Command Engine invocation (`binary: gh`) — validated against
`allowed_binaries`/`command_policy` rather than against the GitHub
Provider's operation surface. The provider exposes a `repo list`
operation that does the same job and lets the provider choose the
transport; this file exists to demonstrate the one raw `gh` semantic mode
Runtime currently admits. Runtime reuses either the existing `gh` session or a
configured GitHub-issued token, keeps account-wide execution in a private
working directory, and preserves native stdout. Other raw `gh` modes remain
default-denied unless separately registered.

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
    args: [repo, list, --limit, "${limit}", --json, "nameWithOwner,description,visibility,url,updatedAt"]
```

Default `text` output remains human-readable. Use Runtime's global
`--output json` for a stable envelope whose `data` field is the native JSON
array, or `--output raw` for the payload alone.
