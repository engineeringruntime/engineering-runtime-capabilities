# Cloud Run jobs and how they have been running

Every Cloud Run job defined in a region, then the executions behind them with
their completion state. Jobs are the half of Cloud Run that has no URL to check,
so a failing nightly job is invisible until something downstream is missing.

Services and jobs are separate resources with separate list commands —
`gcp-cloudrun-inventory` covers services and revisions, this covers jobs and
executions. A project can have plenty of one and none of the other, and an empty
list here is a real answer, not a fault.

Executions carry task counts and completion status. A job whose recent
executions all show failed tasks is the finding; this lists them and a person
decides.

Read-only. Executing a job resolves a named target and is refused at
`selector_bound` strength — see this directory's `README.md`.

Requires `gcloud`, `authentication.gcp.enabled: true`, ADC, and the Cloud Run
API enabled.

Run with:

```
runtime capability validate capabilities/gcp/gcp-cloudrun-jobs-and-executions.md
runtime capability execute gcp/gcp-cloudrun-jobs-and-executions --input region=us-central1
```

```runtime
version: v1

inputs:
  region:
    description: Cloud Run region
    required: true

workflow:
  - binary: gcloud
    args: [run, jobs, list, "--region=${region}"]

  - binary: gcloud
    args: [run, jobs, executions, list, "--region=${region}", "--limit=20"]
```
