# Secrets & variables inventory (metadata only)

List which Actions secrets and variables exist for a repository, plus
its environments. Names and metadata are readable; **values never are**,
by GitHub's design — this is an inventory / rotation-planning report, not
a secret dump.

All steps use the `api` escape hatch. Org-level variants
(`/orgs/{org}/actions/secrets`, …) are the same shape if you need a
fleet inventory later.

Requires `RUNTIME_GITHUB_TOKEN` with Actions secrets read on the
repository.

Run with:

```
runtime capability validate capabilities/github/github-secrets-inventory.md

runtime capability execute capabilities/github/github-secrets-inventory.md \
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
    args: [api, GET, "/repos/${repository}/actions/secrets"]

  - provider: github
    args: [api, GET, "/repos/${repository}/actions/variables"]

  - provider: github
    args: [api, GET, "/repos/${repository}/environments"]
```
