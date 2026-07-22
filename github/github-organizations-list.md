# List the authenticated user's organizations

Single-step capability wrapping the fixed `GET /user/orgs` Runtime
Command. No inputs — the organization list always comes from the
authenticated token. Requires `RUNTIME_GITHUB_TOKEN` to be exported.

Run with:

```
runtime capability validate github/github-organizations-list.md
runtime capability execute github/github-organizations-list.md
```

```runtime
version: v1

workflow:
  - command: github.organizations.list
```
