# Set a repository's default branch

Point a repository's default branch at a different existing branch — the
`master` → `main` move, or redirecting a fork to its long-lived integration
branch.

**The branch must already exist.** GitHub returns `422` if it does not, and this
capability does not create it; use `git push` or `github-file-push` for that.
Renaming is a different operation from repointing, and this is the repointing
one: existing pull requests are retargeted by GitHub, open branches are not
deleted.

Read the branch list first with `github-repo-settings-get` so the value you pass
is one that exists.

Requires `RUNTIME_GITHUB_TOKEN` with admin access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-repo-default-branch-set.md
runtime capability execute github/github-repo-default-branch-set \
  --input repository=acme/payments-api --input branch=main
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  branch:
    description: Existing branch to make the default
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/branches"]

  - provider: github
    args: [api, PATCH, "/repos/${repository}", "default_branch=${branch}"]
```
