# Security posture — open vulnerability alerts for a repository

Roll up the three alert surfaces GitHub exposes for one repository:
Dependabot, code scanning, and secret scanning. Answers "are we
vulnerable / did anyone leak a secret?" without opening three browser
tabs.

All three steps use the `api` escape hatch — there is no curated
`dependabot list` / `code-scanning list` operation today. Org-wide
variants (`/orgs/{org}/dependabot/alerts`, …) are the same shape with a
different path if you need a fleet rollup later.

Requires `ENGRT_GITHUB_TOKEN` with `security_events` (and related)
read access on the repository. Alerts APIs return empty / 404 when the
feature is not enabled for that repo — that is GitHub's response, not a
runtime failure of the capability grammar.

**When this reports failure.** Each alert endpoint answers 403 when that feature is off, for example "Dependabot alerts are disabled for this repository". Runtime reports the first such response as a failed step and later steps do not run, so a repository with Dependabot disabled never reaches the code-scanning and secret-scanning reads.

Run with:

```
engrt capability validate capabilities/github/github-security-posture.md

engrt capability execute capabilities/github/github-security-posture.md \
  --input repository=acme/orders-api
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
