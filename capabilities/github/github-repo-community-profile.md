# Which standard files a repository actually has

Read GitHub's community profile: a health percentage plus, for each of README,
LICENSE, CODE_OF_CONDUCT, CONTRIBUTING, issue template and pull-request
template, whether it exists and where.

**This is how to answer "does the repo have a README?" without breaking.** The
obvious approach — `GET /contents/README.md` — returns `404` when the file is
missing, and a 404 aborts the whole capability. So the check that matters most
would fail precisely on the repositories that fail it. This endpoint returns
`200` either way and reports absence as `null`, which is the difference between
a usable standards check and one that only works on compliant repos.

Read-only. Creating a missing file is `github-file-push`.

Requires `RUNTIME_GITHUB_TOKEN` with read access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-repo-community-profile.md
runtime capability execute github/github-repo-community-profile --input repository=cli/cli
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/community/profile"]
```
