# The commits behind a pull request

List the commits a pull request carries, with author and message. Reviewing a
branch by its commits rather than its squashed diff is how you find the change
that was made and then quietly reverted inside the same PR.

Also the fastest way to see whether a branch has been rebased or has merge
commits from the base branch mixed in — which decides whether the merge policy
in `github-repo-merge-policy-enforce` will do what the team expects.

Requires `RUNTIME_GITHUB_TOKEN` with read access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-pr-commits.md
runtime capability execute github/github-pr-commits \
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
    args: [api, GET, "/repos/${repository}/pulls/${number}/commits", "per_page=100"]
```
