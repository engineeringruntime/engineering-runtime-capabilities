# Get the authenticated GitHub user

A minimal, single-step capability that calls the fixed `GET /user`
operation. Useful as a credential smoke test — if this fails, no
other `github.*` capability will work either. Requires
`ENGRT_GITHUB_TOKEN` to be exported.

Run with:

```
engrt capability validate github/github-user-get.md
engrt capability execute github/github-user-get.md
```

```runtime
version: v1

workflow:
  - provider: github
    args: [user, get]
```
