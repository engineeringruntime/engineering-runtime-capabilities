# Organization health check

Chains four read-only operations into a single snapshot of the
active Runtime Context's GitHub organization: the orgs the token
belongs to, the org's repositories, its teams, and issues assigned to
the authenticated user across it. No inputs — every step resolves
`{org}` from the active Runtime Context. Requires
`RUNTIME_GITHUB_TOKEN` to be exported.

Run with:

```
runtime capability validate github/github-org-health-check.md
runtime capability execute github/github-org-health-check.md
```

```runtime
version: v1

workflow:
  - provider: github
    args: [org, list]

  - provider: github
    args: [repo, list]

  - provider: github
    args: [team, list]

  - provider: github
    args: [issue, list]
```
