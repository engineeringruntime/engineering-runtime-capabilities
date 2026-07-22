# List teams in the active context's organization

Single-step capability wrapping the fixed `GET /orgs/{org}/teams`
Runtime Command. The `{org}` segment resolves from the active Runtime
Context's `github.organization`. Requires `RUNTIME_GITHUB_TOKEN` to be
exported.

Run with:

```
runtime capability validate github/github-teams-list.md
runtime capability execute github/github-teams-list.md
```

```runtime
version: v1

workflow:
  - command: github.teams.list
```
