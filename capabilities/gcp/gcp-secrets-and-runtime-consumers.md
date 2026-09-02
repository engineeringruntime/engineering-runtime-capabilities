# Secrets, and the services that could be consuming them

Every secret in the project, and every Cloud Run service and job that could
reference one. The inventory half of a secret rotation: what exists, and what
would break.

**No value is read, and none can be.** Accessing a version's payload resolves a
named secret positionally, which the compiled safety profile refuses. That
refusal is doing real work here — the one surface where a capability could
exfiltrate credentials is the one made unreachable.

**Nothing correlates the two lists.** Which service mounts which secret lives in
each service's own configuration, and reading that resolves a named service,
which is also refused. So this shows both sides and a person joins them. A
capability that implied it had traced the dependency would be claiming an
analysis it did not perform.

Still worth running: a secret created two years ago with no service that plausibly
uses it is either dead or load-bearing and undocumented, and both are findings.

Requires `gcloud`, `authentication.gcp.enabled: true`, ADC, and the Secret
Manager and Cloud Run APIs enabled.

Run with:

```
runtime capability validate capabilities/gcp/gcp-secrets-and-runtime-consumers.md
runtime capability execute gcp/gcp-secrets-and-runtime-consumers --input region=us-central1
```

```runtime
version: v1

inputs:
  region:
    description: Cloud Run region to list potential consumers in
    required: true

workflow:
  - binary: gcloud
    args: [secrets, list, "--limit=50"]

  - binary: gcloud
    args: [run, services, list, "--region=${region}"]

  - binary: gcloud
    args: [run, jobs, list, "--region=${region}"]
```
