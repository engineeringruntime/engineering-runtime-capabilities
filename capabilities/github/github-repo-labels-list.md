# List a repository's issue labels

Read every label a repository defines, with colour and description. The input to
any "our repos should share one label taxonomy" exercise, and the fastest way to
see why two teams' boards do not line up.

Read-only. Creating labels is possible in principle — `POST /repos/{repo}/labels`
takes flat fields — but syncing a *set* of labels needs iteration the v1 grammar
does not have, so this capability reads and stops rather than half-implementing
a sync.

Requires `RUNTIME_GITHUB_TOKEN` with read access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-repo-labels-list.md
runtime capability execute github/github-repo-labels-list --input repository=cli/cli
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/labels", "per_page=100"]
```
