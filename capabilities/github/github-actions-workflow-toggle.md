# Enable or disable a workflow

Turn a single workflow on or off without editing or deleting its file. The
control for "this workflow is noisy, stop it running while we fix it" that does
not require a commit to the default branch.

`${state}` is `enable` or `disable` — it becomes the last path segment, so any
other value is a `404` rather than a silent no-op.

**Idempotent**, and verified so: enabling an already-enabled workflow succeeds
and changes nothing. Neither endpoint takes a request body, which is why this
write is expressible at all — most Actions writes need nested JSON the `api`
operation cannot send.

Get the workflow id from `github-actions-workflows-inventory`. There is no
step-output chaining; pass it explicitly.

Requires `RUNTIME_GITHUB_TOKEN` with write access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-actions-workflow-toggle.md
runtime capability execute github/github-actions-workflow-toggle \
  --input repository=acme/payments-api --input workflow_id=1234567 --input state=enable
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  workflow_id:
    description: Numeric workflow id, from github-actions-workflows-inventory
    required: true
  state:
    description: enable or disable
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/actions/workflows/${workflow_id}"]

  - provider: github
    args: [api, PUT, "/repos/${repository}/actions/workflows/${workflow_id}/${state}"]
```
