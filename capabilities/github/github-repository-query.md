# GitHub repository query with literal variable binding

Read repository metadata with a fixed GraphQL query and caller-supplied variables,
then read language byte totals through the GitHub API. Both operations are
read-only. Declare the owner and repository name separately; neither is inferred
from the caller's checkout.

This example requires Engineering Runtime 0.10.0 or later; older releases
reject its new fields. It uses a prerelease/build SemVer to
demonstrate the `capability_version` syntax. It does not select a binary version,
Git revision, source trust or policy permission. `needs` labels an earlier-step dependency,
not a reference to GraphQL response data.

Input data is bound as GraphQL variables, never interpolated into query source.
The native GraphQL `$owner` and `$name` references remain literal: capability
input interpolation uses `${name}`. Authentication requires a valid
`ENGRT_GITHUB_TOKEN`; credentials never belong in this source or its inputs.

The commands below read the public Go language repository, `golang/go`.

The declaration `engrt_version: ">=0.10.0"` requires an installed Runtime
version of 0.10.0 or later. Runtime checks it before authentication or workflow
execution; `capability_version` separately versions this definition.

```sh
engrt capability validate capabilities/github/github-repository-query.md
engrt capability plan capabilities/github/github-repository-query.md \
  --input owner=golang --input repository=go
engrt --output json capability execute capabilities/github/github-repository-query.md \
  --input owner=golang --input repository=go
```

```runtime
version: v1
engrt_version: ">=0.10.0"
capability_version: "1.0.0-rc.1+examples.1"

inputs:
  owner:
    description: Explicit GitHub organization or user login
    required: true
  repository:
    description: Repository name within that owner, without an OWNER/ prefix
    required: true

workflow:
  - id: repository_metadata
    provider: github
    args: [graphql, 'query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { nameWithOwner defaultBranchRef { name } } }', "owner=${owner}", "name=${repository}"]

  - id: repository_languages
    needs: [repository_metadata]
    provider: github
    args: [api, GET, "/repos/${owner}/${repository}/languages"]
```
