# Repository deployment and environment inventory

Read the deployment environments and the latest deployments for a repository.
The capability does not expose environment secrets and performs no deployment.

Requires `RUNTIME_GITHUB_TOKEN` with repository metadata and Actions read access.

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/environments", "per_page=100"]
  - provider: github
    args: [api, GET, "/repos/${repository}/deployments", "per_page=20"]
```
