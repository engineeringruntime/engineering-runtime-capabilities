# List the authenticated user's organizations

Single-step capability wrapping the fixed `GET /user/orgs` Runtime
Command. No inputs — the organization list always comes from the
authenticated token. Requires `ENGRT_GITHUB_TOKEN` to be exported.

Run with:

```
engrt capability validate github/github-organizations-list.md
engrt capability execute github/github-organizations-list.md
```

```runtime
version: v1

workflow:
  - provider: github
    args: [org, list]
```
