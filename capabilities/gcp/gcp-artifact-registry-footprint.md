# Every registry in the project, and where registries can live

All Artifact Registry repositories across every location, with format, mode and
size, plus the locations Artifact Registry supports.

`repositories list` without `--location` searches all locations, which is what
you want when the question is "how many registries do we have and where did they
end up?" Registries created by different pipelines drift into different regions,
and the cost of a multi-region repository is not the same as a regional one.

The locations list is there to make the second question answerable: whether a
repository is somewhere deliberate or somewhere a default put it.

Narrower than `gcp-artifact-registry-inventory`, which takes a location and
lists that one. This is the estate view.

Requires `gcloud`, `authentication.gcp.enabled: true`, ADC, and the Artifact
Registry API enabled.

Run with:

```
runtime capability validate capabilities/gcp/gcp-artifact-registry-footprint.md
runtime capability execute gcp/gcp-artifact-registry-footprint
```

```runtime
version: v1

workflow:
  - binary: gcloud
    args: [artifacts, repositories, list]

  - binary: gcloud
    args: [artifacts, locations, list]
```
