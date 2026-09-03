# Recent failed GitHub Actions runs

List recent failed workflow runs for one repository and branch. This is a
read-only triage input: it reports failures but does not rerun or cancel them.

Requires `RUNTIME_GITHUB_TOKEN` with Actions read access.

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  branch:
    description: Branch whose failed runs should be listed
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/actions/runs", "status=failure", "branch=${branch}", "per_page=20"]
```
