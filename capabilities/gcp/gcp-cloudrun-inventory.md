# Cloud Run services and their revisions

Every Cloud Run service in a region, then the revisions behind them. The pair
that answers "what is deployed, and what did it replace?"

`--region` is required by `gcloud` for both commands and is an input here rather
than a default: a capability that silently assumed `us-central1` would report an
empty inventory for anyone deployed elsewhere, which reads as "nothing deployed"
rather than "wrong region".

Revisions carry the traffic split. A service with traffic still on an older
revision after a deploy is the shape of a rollout that stalled, and it is
visible here without opening the console.

Read-only, and structurally so: deploying, rolling back and shifting traffic all
resolve a named service, which the safety floor refuses at `selector_bound`
strength. See `gcp-project-baseline` for why.

Requires `gcloud`, `authentication.gcp.enabled: true`, and ADC.

Run with:

```
runtime capability validate capabilities/gcp/gcp-cloudrun-inventory.md
runtime capability execute gcp/gcp-cloudrun-inventory --input region=us-central1
```

```runtime
version: v1

inputs:
  region:
    description: Cloud Run region, e.g. us-central1
    required: true

workflow:
  - binary: gcloud
    args: [run, services, list, "--region=${region}"]

  - binary: gcloud
    args: [run, revisions, list, "--region=${region}", "--limit=25"]
```
