# Organization health check

Chains four read-only operations into a single snapshot of one GitHub
organization: the orgs the token belongs to, the org's repositories, its
teams, and issues assigned to the authenticated user across it. Requires
`RUNTIME_GITHUB_TOKEN` to be exported.

The organization is an explicit input. GitHub has no native context for
Runtime to read — there is no equivalent of a current kubeconfig context
— so nothing can supply it on your behalf. Passing it means the same
command means the same thing on a laptop and in CI.

**Requires a real GitHub organization**, not a personal account: `team
list` has no user-account equivalent, so a personal login returns `404
Not Found` on step 3. Run `runtime github org list` first if you are not
sure which organizations your token can see.

Run with:

```
runtime capability validate github/github-org-health-check.md
runtime capability execute github/github-org-health-check.md --input organization=acme
```

```runtime
version: v1

inputs:
  organization:
    description: GitHub organization to report on
    required: true

workflow:
  - provider: github
    args: [org, list]

  - provider: github
    args: [repo, list, "${organization}"]

  - provider: github
    args: [team, list, "${organization}"]

  - provider: github
    args: [issue, list, "${organization}"]
```
