# Branch protection audit — prove main cannot be force-pushed

Fetch a branch's protection rules and the repository's rulesets. Answers
"is main protected / why could someone merge without approval?" as
read-only evidence. Setting or deleting protection is intentionally out
of scope here (and `api DELETE` is denied by default policy anyway).

Both steps use the `api` escape hatch — there is no curated
`branch protection get` operation yet.

Requires `RUNTIME_GITHUB_TOKEN` with admin read on the repository.
GitHub returns 404 when protection is not configured — that *is* the
audit signal ("unprotected").

Run with:

```
runtime capability validate capabilities/github/github-branch-protection-audit.md

runtime capability execute capabilities/github/github-branch-protection-audit.md \
  --input repository=acme/payments-api \
  --input branch=main
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  branch:
    description: Branch whose protection to inspect (usually main)
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/branches/${branch}/protection"]

  - provider: github
    args: [api, GET, "/repos/${repository}/rulesets"]
```
