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

## The refinement that matters: flags pass, positionals do not

A later pass found the boundary is narrower than "no targets at all". A target
supplied as a **flag** is part of the pinned invocation and runs; the same
target supplied **positionally** is refused.

| Command | Result |
|---|---|
| `artifacts packages list --repository=X --location=Y` | **runs** |
| `artifacts versions list --package=X --repository=Y --location=Z` | **runs** |
| `artifacts tags list --package=X --repository=Y --location=Z` | **runs** |
| `artifacts files list --repository=X --location=Y` | **runs** |
| `run jobs executions list --region=X` | **runs** |
| `artifacts docker images list <repo-uri>` | **denied** |
| `run services describe <service> --region=X` | **denied** |
| `secrets versions list <secret>` | **denied** |

So "list the versions of this specific image" is expressible and "describe this
specific service" is not — the difference is entirely how `gcloud` accepts the
target, not how specific the question is. When a `gcloud` command offers both
forms, use the flag form.

This is why the Artifact Registry capabilities here reach package, version, tag
and file level while Cloud Run stops at the revision list: `gcloud run` takes
service and revision names positionally, and Artifact Registry takes them as
flags.

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
| `gcp-cloudrun-deployment-provenance` | services, revisions and the image tags behind them |
| `gcp-cloudrun-jobs-and-executions` | jobs, and how they have been running |
| `gcp-artifact-repository-contents` | packages and files, with sizes |
| `gcp-artifact-image-versions-and-tags` | which version carries which tag |
| `gcp-artifact-registry-footprint` | every registry, and where registries can live |
| `gcp-secrets-and-runtime-consumers` | secrets, and the services that could use them |

Two are deliberately narrower than their `gcloud` equivalent: secrets lists
metadata and cannot read a payload, and logging lists names rather than reading
entries. Both restraints are explained in the files.
