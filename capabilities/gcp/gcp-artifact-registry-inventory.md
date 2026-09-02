# Artifact Registry repositories

Every Artifact Registry repository in a location, with its format, mode and
size. Where the images a Cloud Run service runs actually come from.

`--location` is required and is an input rather than a default: Artifact
Registry is regional, and a capability that guessed would report an empty
registry for anyone using another region. `--location=us` covers the multi-region.

Listing *images* inside a repository resolves a named repository, which the
safety floor refuses at `selector_bound` strength — so this stops at the
repository level. Pair it with `gcp-cloudrun-inventory`: the service list shows
which image each revision runs, and this shows which registries exist to hold
them.

Requires `gcloud`, `authentication.gcp.enabled: true`, ADC, and the Artifact
Registry API enabled on the project.

Run with:

```
runtime capability validate capabilities/gcp/gcp-artifact-registry-inventory.md
runtime capability execute gcp/gcp-artifact-registry-inventory --input location=us-central1
```

```runtime
version: v1

inputs:
  location:
    description: Artifact Registry location, e.g. us-central1 or us
    required: true

workflow:
  - binary: gcloud
    args: [artifacts, repositories, list, "--location=${location}"]
```
