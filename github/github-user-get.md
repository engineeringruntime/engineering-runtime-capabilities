# Get the authenticated GitHub user

A minimal, single-step capability that calls the fixed `GET /user`
Runtime Command. Useful as a credential smoke test — if this fails, no
other `github.*` capability will work either. Requires
`RUNTIME_GITHUB_TOKEN` to be exported.

Run with:

```
runtime capability validate github/github-user-get.md
runtime capability execute github/github-user-get.md
```

```runtime
version: v1

workflow:
  - command: github.user.get
```
