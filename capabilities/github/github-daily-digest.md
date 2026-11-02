# Daily GitHub digest

A personal catch-up workflow: unread notifications, issues assigned to
you across the organization you name, and open pull requests on the one
repository you name. Requires `ENGRT_GITHUB_TOKEN` to be exported and
`gh` to be installed (no `gh auth login`: Runtime passes the validated token).

Why it takes explicit inputs:

- `issue list` needs an organization argument (`engrt github issue list <org>`);
  Runtime keeps no active context to read one from.
- `gh` always runs in a private working directory Runtime controls, never in
  your clone, so it cannot infer a repository from the current directory.
  There is also no single curated call for "your open PRs across every
  repository", so this capability reports one named repository's open PRs.

Run with:

```
engrt capability validate github/github-daily-digest.md
engrt capability execute github/github-daily-digest.md \
  --input organization=octocat \
  --input repository=acme/orders-api
```

```runtime
version: v1

inputs:
  organization:
    description: GitHub organization to list assigned issues for
    required: true
  repository:
    description: Repository as <owner>/<repo> to list open pull requests for
    required: true

workflow:
  - provider: github
    args: [notification, list]

  - provider: github
    args: [issue, list, "${organization}"]

  - provider: github
    args: [pr, list, --repo, "${repository}"]
```
