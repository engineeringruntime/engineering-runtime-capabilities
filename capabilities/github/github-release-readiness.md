# Repository release readiness

Gather the repository summary, latest release, recent tags, and available
workflows before a release is authorized. A repository without a published
release returns 404 at the second step; use `github-release-notes-preview` for
first-release preparation.

Requires `RUNTIME_GITHUB_TOKEN` and `gh`; every step is read-only.

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [repo, summary, "${repository}"]
  - provider: github
    args: [api, GET, "/repos/${repository}/releases/latest"]
  - provider: github
    args: [api, GET, "/repos/${repository}/tags", "per_page=20"]
  - provider: github
    args: [workflow, list, --repo, "${repository}"]
```
