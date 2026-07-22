# Organization health check

Chains four read-only Runtime Commands into a single snapshot of the
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
  - command: github.organizations.list

  - command: github.repositories.list_for_org

  - command: github.teams.list

  - command: github.issues.list_for_org
```
