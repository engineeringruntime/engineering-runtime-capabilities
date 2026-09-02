# GCP project baseline — what this project actually is

The enabled services, the service accounts, and the projects the caller can see.
The three reads that answer "what is this project, and who acts inside it?"
before any change is proposed.

## Why every GCP capability here is an enumeration

Runtime binds GCP context as `selector_bound`: the selectors are pinned, but
`gcloud` re-reads its own mutable configuration to interpret them, so Runtime
will not promise a *targeted* operation lands where policy approved. The
compiled safety profile therefore refuses commands that resolve a specific named
resource — including read-only ones.

Measured, not assumed:

| Command | Result |
|---|---|
| `gcloud projects list` | runs, with `--project` injected from context |
| `gcloud services list` | runs |
| `gcloud projects describe <project>` | **denied** — `unpinned-side-effect` |

`describe` is read-only and still refused. The line is enumeration versus named
target, not read versus write. Every capability in this directory is therefore a
listing; targeted reads wait for a GCP provider that can pin them strongly.

Requires `gcloud` in `allowed_binaries`, `authentication.gcp.enabled: true` in
config, and working Application Default Credentials. Runtime never starts the
login flow — run `gcloud auth application-default login` yourself first.

Run with:

```
runtime capability validate capabilities/gcp/gcp-project-baseline.md
runtime capability execute gcp/gcp-project-baseline
```

```runtime
version: v1

workflow:
  - binary: gcloud
    args: [projects, list, "--limit=25"]

  - binary: gcloud
    args: [services, list, "--limit=50"]

  - binary: gcloud
    args: [iam, service-accounts, list]
```
