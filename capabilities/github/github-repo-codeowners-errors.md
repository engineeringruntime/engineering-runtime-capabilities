# Is CODEOWNERS actually valid

Ask GitHub to parse the repository's CODEOWNERS file and report its errors:
unknown owners, users without access, malformed patterns, lines that match
nothing.

Worth running because a CODEOWNERS file with a broken line does not fail loudly
— it silently stops requesting review from the team that line named, and nobody
notices until an unreviewed change lands.

GitHub validates it server-side, so this is one call rather than a
reimplementation of their parser. A repository with no CODEOWNERS returns an
empty error list, not a 404.

`github-service-onboarding` also checks CODEOWNERS as its last step; this is the
same check on its own, for a repository that already exists.

Requires `ENGRT_GITHUB_TOKEN` with read access to the repository.

**When this reports failure.** `GET /codeowners/errors` returned 404 on a repository with no CODEOWNERS file. Runtime reports a 404 on a generic `api GET` step as a failed step, not as "nothing configured".

Run with:

```
engrt capability validate capabilities/github/github-repo-codeowners-errors.md
engrt capability execute github/github-repo-codeowners-errors --input repository=cli/cli
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/codeowners/errors"]
```
