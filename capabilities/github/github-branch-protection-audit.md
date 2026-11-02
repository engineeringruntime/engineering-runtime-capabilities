# Branch protection audit — prove main cannot be force-pushed

Fetch a branch's protection rules and the repository's rulesets. Answers
"is main protected / why could someone merge without approval?" as
read-only evidence. Setting or deleting protection is intentionally out
of scope here (and `api DELETE` is denied by default policy anyway).

Both steps use the `api` escape hatch — there is no curated
`branch protection get` operation yet.

Requires `ENGRT_GITHUB_TOKEN` with admin read on the repository.
GitHub returns 404 when protection is not configured — that *is* the
audit signal ("unprotected").

**When this reports failure.** `GET /branches/{branch}/protection` returns 404 "Branch not protected" for a branch with no protection rule, and 403 "Upgrade to GitHub Pro or make this repository public" for a private repository on a plan without branch protection or rulesets. Runtime reports both as a failed step.

Run with:

```
engrt capability validate capabilities/github/github-branch-protection-audit.md

engrt capability execute capabilities/github/github-branch-protection-audit.md \
  --input repository=acme/orders-api \
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
