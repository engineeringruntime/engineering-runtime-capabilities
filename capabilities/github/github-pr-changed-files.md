# What a pull request actually changes

List every file a pull request touches, with additions, deletions and status.
The review question "how big is this really?" answered before opening a diff —
and the input to any policy about PR size or protected paths.

Paginated at 100 files. A very large pull request will be truncated at that
boundary; the count in `github-pr-status` tells you whether that happened.

Requires `RUNTIME_GITHUB_TOKEN` with read access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-pr-changed-files.md
runtime capability execute github/github-pr-changed-files \
  --input repository=cli/cli --input number=11000
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  number:
    description: Pull request number
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/pulls/${number}/files", "per_page=100"]
```
