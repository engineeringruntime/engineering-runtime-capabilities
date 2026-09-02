# What is at the root of a repository, and in .github

List the repository root and its `.github` directory. Between them they hold
almost everything a standards review looks for: README, LICENSE, gitignore,
editorconfig, CODEOWNERS, issue templates and workflow files.

Listing a directory returns `200` with its entries; asking for a named file that
does not exist returns `404` and aborts. Listing is therefore the right shape
for "what is here?", and `github-repo-community-profile` is the right shape for
"which of the standard files are present?"

A repository with no `.github` directory returns `404` on the second step and
the run ends there. The first step's output still stands — and the absence is
itself the finding.

Requires `RUNTIME_GITHUB_TOKEN` with read access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-repo-root-files.md
runtime capability execute github/github-repo-root-files --input repository=cli/cli
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/contents"]

  - provider: github
    args: [api, GET, "/repos/${repository}/contents/.github"]
```
