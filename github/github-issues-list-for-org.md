# List issues assigned to the user across the active context's organization

Single-step capability wrapping the fixed `GET /orgs/{org}/issues`
Runtime Command. The `{org}` segment resolves from the active Runtime
Context's `github.organization`. Requires `RUNTIME_GITHUB_TOKEN` to be
exported.

Run with:

```
runtime capability validate github/github-issues-list-for-org.md
runtime capability execute github/github-issues-list-for-org.md
```

```runtime
version: v1

workflow:
  - command: github.issues.list_for_org
```
