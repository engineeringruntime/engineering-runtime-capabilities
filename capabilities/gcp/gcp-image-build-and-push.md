# Build a container image and push it to Artifact Registry

Build an image from a local working directory and push it to a container
registry. Two steps, both through the Command Engine, both governed and audited.

> **Status: step 1 works, step 2 is blocked for Artifact Registry.** The build is
> verified. The push fails because Runtime's bounded execution environment cannot
> reach `docker-credential-gcloud`. Read *Prerequisites* before using this.

## Why this is expressible when `gcloud run deploy` is not

`docker push` changes infrastructure — it puts an image into a registry — and it
is permitted. `gcloud run deploy` also changes infrastructure and is refused.
The difference is not severity, it is **bindability**: `docker push` names its
destination as a fully-qualified registry URI in the argument itself, so Runtime
can pin exactly where the image lands. `gcloud run deploy` names a service that
`gcloud` resolves through project and region configuration Runtime cannot pin,
so the compiled safety profile refuses it at `selector_bound` strength.

That is why this capability stops at the push. Deploying the image is
`platform-service-deploy-dispatch`, which asks the service's own CI to do it.

## Prerequisites Runtime will not do for you

- **Docker must be running.** The build executes on whatever machine runs the
  capability, so reproducibility comes from your `Dockerfile`, not from Runtime.
- **Pushing to a registry that uses a credential helper needs one policy entry.**
  Artifact Registry with the standard setup is exactly that case: `credHelpers`
  in `~/.docker/config.json` points at `docker-credential-gcloud`, and Runtime
  executes commands in a bounded environment, so the helper is not on `PATH`
  unless you admit it. Without it the push fails with

  ```
  error getting credentials - err: exec: "docker-credential-gcloud":
  executable file not found in $PATH
  ```

  Since **Runtime 0.9.1**, `command_policy.admitted_helpers` closes that gap:

  ```yaml
  schema_version: 3

  allowed_binaries:
    - docker

  command_policy:
    admitted_helpers:
      docker:
        - /opt/homebrew/bin/docker-credential-gcloud
  ```

  Verified on 0.9.2 — the same command against Artifact Registry, with and
  without that block:

  | Policy | Result |
  |---|---|
  | no `admitted_helpers` | `exec: "docker-credential-gcloud": executable file not found in $PATH` |
  | with it | authentication succeeds; the command reaches the registry |

  The admission is deliberately narrow: absolute paths only, scoped to the one
  parent binary, exposing only the named files rather than the directory they
  sit in, and empty by default. Runtime still pins `docker` itself — this admits
  its transitive helper and nothing else. Use the path your own machine has;
  `docker-credential-gcloud` sits elsewhere on Linux.
- **The target repository must exist.** Creating one is a `gcloud` write and is
  refused; use `gcp-artifact-registry-footprint` to confirm it is there first.

`${image_uri}` must be fully qualified and include the tag, e.g.
`us-central1-docker.pkg.dev/my-project/my-repo/payments-api:v1`.

Requires `docker` in `allowed_binaries`.

Run with:

```
runtime capability validate capabilities/gcp/gcp-image-build-and-push.md
runtime capability execute gcp/gcp-image-build-and-push \
  --input workdir=/path/to/checkout \
  --input image_uri=us-central1-docker.pkg.dev/my-project/my-repo/payments-api:v1
```

Verify afterwards with `gcp-artifact-repository-contents` and
`gcp-artifact-image-versions-and-tags` — the tag you pushed should be the tag
they list.

```runtime
version: v1

inputs:
  workdir:
    description: Directory containing the Dockerfile and build context
    required: true
  image_uri:
    description: Fully-qualified image URI including tag
    required: true

workflow:
  - binary: docker
    args: [build, "-t", "${image_uri}", "${workdir}"]

  - binary: docker
    args: [push, "${image_uri}"]
```
