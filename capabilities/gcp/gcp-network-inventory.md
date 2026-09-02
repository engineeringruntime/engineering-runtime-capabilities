# Networks and subnets

Every VPC network in the project and the subnets inside them. The map you need
before reasoning about anything else in the project, and the one most teams
reconstruct from memory.

Subnets carry their region and CIDR range. Two subnets with overlapping ranges
in different regions is a peering problem waiting to happen, and it is visible
here as two rows rather than as a failed connection later.

Read-only. Creating or modifying a network resolves a named target and is
refused at `selector_bound` strength — see `gcp-project-baseline`.

Requires `gcloud`, `authentication.gcp.enabled: true`, and ADC. The Compute
Engine API must be enabled on the project; if it is not, `gcloud` reports
`has not been used in project ... before or it is disabled` and the capability
ends there.

Run with:

```
runtime capability validate capabilities/gcp/gcp-network-inventory.md
runtime capability execute gcp/gcp-network-inventory
```

```runtime
version: v1

workflow:
  - binary: gcloud
    args: [compute, networks, list]

  - binary: gcloud
    args: [compute, networks, subnets, list, "--limit=50"]
```
