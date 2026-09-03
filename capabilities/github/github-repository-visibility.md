# Verify repository visibility

Read repository metadata through both the curated operation and REST surface.
The returned `visibility`, `private`, `archived`, and default-branch fields are
the evidence; this capability never changes them.

Requires `RUNTIME_GITHUB_TOKEN` with repository read access.

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [repo, view, "${repository}"]
  - provider: github
    args: [api, GET, "/repos/${repository}"]
```
