# Add a deployment branch or tag pattern to an environment

> **Mutating.** Adds one pattern to an environment that uses custom branch
> policies. Run `plan` first. Execute only on an explicit request.

Adds one allowed `branch` or `tag` name pattern (`main`, `release/*`, `v*`),
then lists the environment's patterns.

## Behaviour to know

- The environment must already use `custom_branch_policies: true`. On an
  environment without it GitHub answers `404`.
- A pattern that already exists answers `303`, and engrt refuses redirects, so
  the step fails as `http_redirect_refused`. Treat that as "already present".
- `type` must be `branch` or `tag` (`422` otherwise). GitHub defaults an
  omitted type to `branch`; this capability always sends it.
- An empty name is refused with `422`.
- There is no remove step: policy denies `api DELETE`.

## Run it

```bash
engrt capability plan github/repo-environment-branch-policy-add \
  --input organization=<organization> --input repository=<repo> \
  --input environment=<name> --input pattern=release/* --input type=branch
```

```runtime
version: v1
capability_version: "1.0.0"
engrt_version: ">=0.13.0"

inputs:
  organization:
    description: GitHub organization that owns the repository
    required: true
  repository:
    description: Repository name without the owner
    required: true
  environment:
    description: Environment name, URL-encoded
    required: true
  pattern:
    description: Branch or tag name pattern, for example main, release/* or v*
    required: true
  type:
    description: branch or tag
    required: true

workflow:
  - id: add
    provider: github
    args:
      - api
      - POST
      - "/repos/${organization}/${repository}/environments/${environment}/deployment-branch-policies"
      - "name=${pattern}"
      - "type=${type}"

  - id: verify
    needs: [add]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/environments/${environment}/deployment-branch-policies"]
    outputs:
      total: {pointer: /total_count, type: integer}
```
