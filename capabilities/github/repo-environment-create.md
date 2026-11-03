# Create or update a GitHub Actions environment

> **Mutating.** Creates the environment, or updates it if it exists
> (`PUT` is create-or-update). Run `plan` first. Execute only on an explicit
> request for that repository and environment name.

Creates an environment and sets its deployment branch policy, then reads it
back.

## Inputs

- `environment`: the name, **URL-encoded** when it holds a space or `/`
  (`staging`, `my%20env`, `team%2Fprod`). Names are case-insensitive: GitHub
  keeps the first spelling. At most 255 characters.
- `deployment_branch_policy`: JSON, one of
  - `{"protected_branches":true,"custom_branch_policies":false}`: only branches
    with protection;
  - `{"protected_branches":false,"custom_branch_policies":true}`: only the
    patterns added with [repo-environment-branch-policy-add](repo-environment-branch-policy-add.md);
  - `null`: any branch can deploy.

  Both flags `true`, or both `false`, are refused with `422`.

## What this capability leaves out, and why

`wait_timer`, `reviewers` and `prevent_self_review` are **not** sent. On a
private repository under the `team` plan GitHub answers `422 … ensure the
billing plan supports …` to any of them, even `wait_timer=0` or
`reviewers:=[]`. The only way to avoid that is to leave them out, so this
capability cannot set them. Set protection rules in the repository settings
instead, on a plan that supports them.

## Behaviour to know

- A repeat run with the same policy changes nothing. A `PUT` that omits
  `deployment_branch_policy` **keeps** the existing policy; only `null` clears
  it, and this capability always sends the input.
- A failed `PUT` can leave the environment created without the policy
  (observed with both flags `true`). Run the verify read again, or re-run.
- Policy denies `api DELETE`, so engrt cannot remove an environment.

## Run it

```bash
engrt capability plan github/repo-environment-create \
  --input organization=<organization> --input repository=<repo> \
  --input environment=<name> \
  --input 'deployment_branch_policy={"protected_branches":false,"custom_branch_policies":true}'
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
    description: Environment name, URL-encoded (space is %20, slash is %2F), at most 255 characters
    required: true
  deployment_branch_policy:
    description: JSON object with protected_branches and custom_branch_policies (exactly one true), or null for any branch
    required: true

workflow:
  - id: create
    provider: github
    args:
      - api
      - PUT
      - "/repos/${organization}/${repository}/environments/${environment}"
      - 'deployment_branch_policy:=${deployment_branch_policy}'

  - id: verify
    needs: [create]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/environments/${environment}"]
    outputs:
      id: {pointer: /id, type: integer}
```
