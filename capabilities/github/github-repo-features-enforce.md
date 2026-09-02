# Enforce which repository features are on

Turn Issues, Wiki and Projects on or off for a repository. Small, but it is the
difference between "every service repo has an issue tracker" as a stated
standard and as an enforced one.

Three booleans, three steps, each separately audited. Idempotent — setting a
feature to the value it already has returns the current state and changes
nothing.

Read the current state first with `github-repo-settings-get`; turning Issues
*off* on a repository that has open issues hides them rather than closing them,
which is rarely what anyone means.

Requires `RUNTIME_GITHUB_TOKEN` with admin access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-repo-features-enforce.md
runtime capability execute github/github-repo-features-enforce \
  --input repository=acme/payments-api \
  --input has_issues=true --input has_wiki=false --input has_projects=false
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  has_issues:
    description: Enable the issue tracker (true/false)
    required: true
  has_wiki:
    description: Enable the wiki (true/false)
    required: true
  has_projects:
    description: Enable projects (true/false)
    required: true

workflow:
  - provider: github
    args: [api, PATCH, "/repos/${repository}", "has_issues=${has_issues}"]

  - provider: github
    args: [api, PATCH, "/repos/${repository}", "has_wiki=${has_wiki}"]

  - provider: github
    args: [api, PATCH, "/repos/${repository}", "has_projects=${has_projects}"]
```
