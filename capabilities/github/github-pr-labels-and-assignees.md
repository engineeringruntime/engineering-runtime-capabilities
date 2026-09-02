# Labels and assignees on a pull request

Read the labels, assignees and requested reviewers attached to a pull request.
GitHub stores these on the *issue* record behind every PR, which is why they are
absent from the pull-request endpoint and why this capability reads a different
path than the other PR capabilities here.

That detail matters when writing your own: `/pulls/{n}` and `/issues/{n}` are
the same object seen through two APIs, and each hides half the fields.

Read-only. Adding a label takes an array body, which `api` cannot express.

Requires `RUNTIME_GITHUB_TOKEN` with read access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-pr-labels-and-assignees.md
runtime capability execute github/github-pr-labels-and-assignees \
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
    args: [api, GET, "/repos/${repository}/issues/${number}"]

  - provider: github
    args: [api, GET, "/repos/${repository}/issues/${number}/labels"]
```
