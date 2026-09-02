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
| `docker build` | yes | but the image has nowhere useful to go |
| `docker push` to Artifact Registry | **no** | `docker` cannot reach `docker-credential-gcloud`; Runtime's bounded environment does not admit transitive helpers |
| `gcloud run deploy` | **no** | every `gcloud` change is refused at `selector_bound` strength |

So the pattern is: **Runtime bootstraps and dispatches; CI builds, pushes and
deploys.** That is not a workaround. Runtime is doing the governed, auditable
part — creating repositories, writing contracts, triggering pipelines — and
asking CI to do the two things whose destination Runtime cannot pin.

A capability that found a way past either refusal would be defeating the
control, not completing the feature.

## Known transport defect on v0.8.0

The curated `workflow run`, `run list`, `pr list` and `workflow list` operations
**do not work**. They route through the `gh` CLI, and `gh` is registered as
context-unsupported because it resolves the repository from the working
directory:

```
runtime github workflow run …  → gh reached the Command Engine with no pinned artifact
runtime command run gh …       → gh is registered as context-unsupported …
                                  Use the curated `runtime github ...` operations
```

The refusal points at the curated operations, and the curated operations route
through the refused binary. **Twelve shipped capabilities depend on that
transport.** REST operations are unaffected.

Capabilities here therefore use `api` where a curated operation would read
better. Those uses are marked, and should be reverted when the transport is
fixed.

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
