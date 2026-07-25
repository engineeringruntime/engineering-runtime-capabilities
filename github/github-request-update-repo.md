# Update a repository's description

Uses the generic `github.request` pass-through to `PATCH
/repos/{owner}/{repo}` with a new `description`. Requires
`RUNTIME_GITHUB_TOKEN` to be exported, and write access to the target
repository.

Run with:

```
runtime capability validate github/github-request-update-repo.md
runtime capability execute github/github-request-update-repo.md \
  --input owner=octocat --input repo=hello-world \
  --input description="updated via runtime"
```

```runtime
version: v1

inputs:
  owner:
    description: Repository owner (user or organization)
    required: true
  repo:
    description: Repository name
    required: true
  description:
    description: New repository description
    required: true

workflow:
  - provider: github
    args: [api, PATCH, "/repos/${owner}/${repo}", "description=${description}"]
```
