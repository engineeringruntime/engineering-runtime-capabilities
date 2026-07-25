# List open pull requests via the GitHub CLI

A raw Command Engine invocation (`binary: gh`) — the escape hatch for
what the provider does not expose. Runs
`gh pr list` against whichever repo `gh` is currently configured for
(its own working-directory/remote resolution — the runtime does not
inject a repo). Requires `gh` to be installed and authenticated.

Run with:

```
runtime capability validate github/github-cli-pr-list.md
runtime capability execute github/github-cli-pr-list.md
```

```runtime
version: v1

workflow:
  - binary: gh
    args: [pr, list]
```
