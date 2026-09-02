# GCP capabilities

Enumerations of a Google Cloud project, run through the Command Engine.

## Everything here is a listing, and that is not an oversight

Runtime binds GCP context as `selector_bound`. The selectors are pinned, but
`gcloud` re-reads its own mutable configuration to interpret them, so Runtime
will not promise that a *targeted* operation lands where policy approved. The
compiled safety profile refuses those commands — including read-only ones.

Measured on Runtime v0.8.0:

| Command | Result |
|---|---|
| `gcloud projects list` | runs, `--project` injected from context |
| `gcloud services list` | runs |
| `gcloud run services list --region=…` | runs |
| `gcloud compute networks list` | runs |
| `gcloud projects describe <project>` | **denied** — `unpinned-side-effect` |

The line is **enumeration versus named target**, not read versus write.
`describe` is read-only and still refused.

Targeted reads and every mutation wait for a GCP provider, which is what would
resolve targets strongly instead of through a mutable mapping. Until then this
directory covers what can be run safely and honestly. Do not work around the
refusal — it is the control described in the context-binding architecture doing
its job.

## Prerequisites

1. `gcloud` in `allowed_binaries` in your policy.
2. `authentication.gcp.enabled: true` in your config. A `binary: gcloud` step
   inside a capability is treated as a provider operation and is refused until
   this is set — `runtime command run gcloud …` is governed by command policy
   instead, which is why one can work while the other does not.
3. Application Default Credentials: `gcloud auth application-default login`.
   Runtime never starts that flow itself.

A missing API surfaces as `has not been used in project … before or it is
disabled` and ends the capability. That is the project's state, not a fault in
the file.

## What is here

| Capability | Covers |
|---|---|
| `gcp-project-baseline` | projects, enabled services, service accounts |
| `gcp-cloudrun-inventory` | Cloud Run services and revisions |
| `gcp-network-inventory` | VPC networks and subnets |
| `gcp-firewall-and-addresses` | firewall rules, reserved addresses |
| `gcp-artifact-registry-inventory` | Artifact Registry repositories |
| `gcp-secrets-inventory` | secret names and metadata, never values |
| `gcp-logging-inventory` | log names only, never log contents |

Two are deliberately narrower than their `gcloud` equivalent: secrets lists
metadata and cannot read a payload, and logging lists names rather than reading
entries. Both restraints are explained in the files.
