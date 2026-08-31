# Security posture — open vulnerability alerts for a repository

Roll up the three alert surfaces GitHub exposes for one repository:
Dependabot, code scanning, and secret scanning. Answers "are we
vulnerable / did anyone leak a secret?" without opening three browser
tabs.

All three steps use the `api` escape hatch — there is no curated
`dependabot list` / `code-scanning list` operation today. Org-wide
variants (`/orgs/{org}/dependabot/alerts`, …) are the same shape with a
different path if you need a fleet rollup later.

Requires `RUNTIME_GITHUB_TOKEN` with `security_events` (and related)
read access on the repository. Alerts APIs return empty / 404 when the
feature is not enabled for that repo — that is GitHub's response, not a
runtime failure of the capability grammar.

Run with:

```
runtime capability validate capabilities/github/github-security-posture.md

runtime capability execute capabilities/github/github-security-posture.md \
  --input repository=acme/payments-api
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/dependabot/alerts", "state=open", "per_page=100"]

  - provider: github
    args: [api, GET, "/repos/${repository}/code-scanning/alerts", "state=open", "per_page=100"]

  - provider: github
    args: [api, GET, "/repos/${repository}/secret-scanning/alerts", "state=open", "per_page=100"]
```
