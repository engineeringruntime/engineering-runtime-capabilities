# List an organization's repositories and open pull requests

Lists every repository in a GitHub organization via the REST API (a
a provider operation), then lists open pull requests via the
GitHub CLI (a raw Command Engine invocation). The clearest illustration
of why the Runtime block grammar has two step shapes — both dispatch
through the identical `Execute`/`RunCommand` lifecycle. Requires
`RUNTIME_GITHUB_TOKEN` to be exported and `gh` to be installed and
authenticated.

Run with:

```
runtime capability validate github/github-org-repos-and-open-prs.md
runtime capability execute github/github-org-repos-and-open-prs.md \
  --input organization=octocat
```

```runtime
version: v1

inputs:
  organization:
    description: GitHub organization to inspect
    required: true

workflow:
  - provider: github
    args: [api, GET, "/orgs/${organization}/repos"]

  - binary: gh
    args: [pr, list]
```
