# Reviews and review comments on a pull request

Who reviewed, what they decided, and every line comment they left. The record
that matters when a PR has been open long enough that the conversation is the
history.

Two steps because GitHub keeps them apart: `reviews` holds the verdicts
(`APPROVED`, `CHANGES_REQUESTED`, `COMMENTED`), `comments` holds the inline
threads. Neither contains the other.

Requesting a reviewer is **not** possible here: that endpoint takes a
`reviewers` array, and the `api` operation accepts flat `key=value` arguments
only. This capability reads; assigning stays a deliberate action elsewhere.

Requires `RUNTIME_GITHUB_TOKEN` with read access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-pr-reviews.md
runtime capability execute github/github-pr-reviews \
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
    args: [api, GET, "/repos/${repository}/pulls/${number}/reviews", "per_page=100"]

  - provider: github
    args: [api, GET, "/repos/${repository}/pulls/${number}/comments", "per_page=100"]
```
