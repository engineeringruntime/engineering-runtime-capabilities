# Platform capabilities

Capabilities that span providers. The existing folders are named by provider —
`github/`, `gcp/`, `files/` — so work that crosses them breaks to purpose
instead.

## These stop where Runtime stops

A cross-provider capability naturally wants to finish the job: create the
repository, build the image, deploy the service. Runtime deliberately refuses
two of those, and capabilities here are shaped around the refusals rather than
around them.

| Wanted | Runtime | Why |
|---|---|---|
| Create a repository, write files, dispatch CI | **yes** | curated GitHub operations and REST |
| `docker build` | **yes** | pass an absolute context — each step gets a fresh bounded working directory, so `.` builds from an empty one |
| `docker push` to Artifact Registry | **yes, since v0.9.1** | needs one `command_policy.admitted_helpers` entry naming the credential helper |
| `gcloud run deploy` | **no** | every `gcloud` change is refused at `selector_bound` strength, and no policy document lifts it |

So the pattern is: **Runtime bootstraps, builds, pushes and dispatches; CI
deploys.** One stage leaves, not three. That is not a workaround — Runtime does
the governed, auditable part and asks CI for the single operation whose
destination it cannot pin.

The push moved back in on **v0.9.1**, which added `admitted_helpers`. The table
above said "no" for two releases after it became "yes", which is why the release
gate now checks the public surface for claims a release has just falsified.

A capability that found a way past the remaining refusal would be defeating the
control, not completing the feature.

## Capabilities here

| Capability | What it does | Transports |
|---|---|---|
| [`platform-service-bootstrap.md`](./platform-service-bootstrap.md) | Empty repository → scaffolded service → local image → pushed to Artifact Registry → pipeline dispatched | `rest` · `git` · `docker` |
| [`java-service-scaffold-and-ship.md`](./java-service-scaffold-and-ship.md) | Scaffolds a Maven service into an existing repository through a local checkout, commits, pushes, dispatches its pipeline | `rest` · `file` · `git` · `cli` |
| [`repository-delivery-readiness.md`](./repository-delivery-readiness.md) | Compares remote repository/PR/CI state with a local checkout and its declared delivery document | `graphql` · `cli` · `file` · `git` |

## Fixed in v0.9.1 — the `gh` CLI transport

The curated `workflow run`, `run list`, `pr list` and `workflow list` operations
**were refused on v0.8.0**. They route through the `gh` CLI, and the provider path
built a Command Engine request with no pinned executable, so the engine refused
every one of them:

```
runtime github workflow run …  → gh reached the Command Engine with no pinned artifact
```

Sixteen published capabilities depended on that path and were dead for a release.
Nothing reported it, because `go test`, a strict docs build and capability
*validation* all stayed green — validation parses a file, it never runs one.

**v0.9.1 fixed it**, and the CI conformance matrix now executes one real
operation per transport on every release candidate so a whole transport cannot
die silently again. Verified on **0.9.2**: `gh workflow run` returns a run URL and
`gh run list` returns the queue.

## What is here

| Capability | Does |
|---|---|
| `platform-service-bootstrap` | Creates a repository, writes a Java service, Dockerfile and delivery pipeline, dispatches the pipeline, reports the run |

## Composition is not available

Capabilities cannot call capabilities. A step is `provider` or `binary`, there is
no include, and `runtime` is not an allowed binary. An orchestrator must inline
every step, which is why `platform-service-bootstrap` restates work that also
exists in `github/java-service-scaffold-and-ship`. If one changes, check the
other.
