# Secrets in Secret Manager

Every secret the project defines, with its replication policy and creation time.
**Names and metadata only — no secret values are read, and none can be.**

Accessing a version's payload resolves a named secret, which the safety floor
refuses at `selector_bound` strength. That refusal is doing real work here: the
one GCP surface where a careless capability could exfiltrate credentials is the
one the boundary makes unreachable. This lists what exists so an inventory or a
rotation review can be done without ever touching a value.

The creation timestamp is the rotation signal. A secret created two years ago
and never versioned since is the finding; this capability shows it, and a person
decides what to do.

Requires `gcloud`, `authentication.gcp.enabled: true`, ADC, and the Secret
Manager API enabled.

Run with:

```
runtime capability validate capabilities/gcp/gcp-secrets-inventory.md
runtime capability execute gcp/gcp-secrets-inventory
```

```runtime
version: v1

workflow:
  - binary: gcloud
    args: [secrets, list, "--limit=50"]
```
