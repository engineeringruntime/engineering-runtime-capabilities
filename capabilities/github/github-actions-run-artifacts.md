# What a workflow run produced

List the artifacts a run uploaded, with size and expiry, and the jobs it ran
with their conclusions. The pair that answers "did the build actually publish
what it claims, and which step decided that?"

Artifact *download* is not here. The download endpoint returns a redirect to a
short-lived blob URL, and following it writes a file — an egress the capability
grammar does not express and should not pretend to. This lists; fetching stays
an explicit `gh run download`.

Expired artifacts still appear with `"expired": true`. A release that references
an artifact past its retention window is a real failure mode, and this is where
it shows up.

Requires `RUNTIME_GITHUB_TOKEN` with read access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-actions-run-artifacts.md
runtime capability execute github/github-actions-run-artifacts \
  --input repository=engineeringruntime/engineering-runtime-ci --input run_id=1234567890
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  run_id:
    description: Workflow run id, from run list or github-ci-failure-triage
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/actions/runs/${run_id}/artifacts"]

  - provider: github
    args: [api, GET, "/repos/${repository}/actions/runs/${run_id}/jobs"]
```
