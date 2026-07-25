# List repositories for the active context's organization

Single-step capability wrapping the fixed `GET /orgs/{org}/repos`
operation. The `{org}` segment resolves automatically from the
active Runtime Context's `github.organization` — no input needed. Use
`runtime context show` / `runtime context set` to change which org this
targets. Requires `RUNTIME_GITHUB_TOKEN` to be exported.

Run with:

```
runtime capability validate github/github-repositories-list-for-org.md
runtime capability execute github/github-repositories-list-for-org.md
```

```runtime
version: v1

workflow:
  - provider: github
    args: [repo, list]
```
