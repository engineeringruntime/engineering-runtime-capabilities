# Branches and what protects the default one

List every branch, then read the protection actually in force on one of them.
The list shows which branches exist and which are already marked protected; the
second step shows what that protection contains.

Read-only. Setting protection is **not** possible from a v1 capability — the
body is a nested object with arrays (`required_status_checks.contexts`,
`required_pull_request_reviews`), and `api` takes flat `key=value` arguments.
This reads; enforcement stays a deliberate action elsewhere.

**A branch with no protection returns `404`, and that ends the run.** Verified
against `cli/cli`: step 1 lists the branches, step 2 stops with
`returned status 404`. The abort *is* the finding — an unprotected branch — but
it is reported as a failed capability, not as a clean result, so read the step-1
output before reacting to the error. Run this against a branch you expect to be
protected; use step 1's `"protected": true|false` field to decide which.

Requires `ENGRT_GITHUB_TOKEN` with admin read on the repository.

**When this reports failure.** `GET /branches/{branch}/protection` returns 404 "Branch not protected" for a branch with no protection rule, and 403 "Upgrade to GitHub Pro or make this repository public" for a private repository on a plan without branch protection. Runtime reports both as a failed step.

Run with:

```
engrt capability validate capabilities/github/github-repo-branches-and-protection.md
engrt capability execute github/github-repo-branches-and-protection \
  --input repository=cli/cli --input branch=trunk
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  branch:
    description: Branch whose protection to read
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/branches", "per_page=100"]

  - provider: github
    args: [api, GET, "/repos/${repository}/branches/${branch}/protection"]
```
