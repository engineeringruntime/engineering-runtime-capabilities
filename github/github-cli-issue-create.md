# Create an issue via the GitHub CLI

A raw Command Engine invocation (`binary: gh`) — the escape hatch for
what the provider does not expose. Runs
`gh issue create` against whichever repo `gh` is currently configured
for. Requires `gh` to be installed and authenticated.

Run with:

```
runtime capability validate github/github-cli-issue-create.md
runtime capability execute github/github-cli-issue-create.md \
  --input title="Bug" --input body="found via runtime"
```

```runtime
version: v1

inputs:
  title:
    description: Issue title
    required: true
  body:
    description: Issue body
    required: true

workflow:
  - binary: gh
    args: [issue, create, --title, "${title}", --body, "${body}"]
```
