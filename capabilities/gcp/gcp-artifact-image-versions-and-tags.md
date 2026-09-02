# Which image version carries which tag

Every version of one image, and the tags pointing at them. The pair that shows
whether `latest` still means what anyone thinks it means.

A version with no tag is an orphan: pushed, superseded, and now retained
indefinitely because nothing removes untagged versions by default. A tag on an
old version is worse — it means a deploy referencing that tag ships something
nobody expects.

Read together with `gcp-cloudrun-deployment-provenance`, which shows the digest
Cloud Run is actually running. These two are how you establish that the tag, the
version and the running revision agree.

`--package`, `--repository` and `--location` are all flags. The positional form
of the same query is refused by the safety floor — see
`gcp-artifact-repository-contents` for why that distinction exists.

Requires `gcloud`, `authentication.gcp.enabled: true`, ADC, and the Artifact
Registry API enabled.

Run with:

```
runtime capability validate capabilities/gcp/gcp-artifact-image-versions-and-tags.md
runtime capability execute gcp/gcp-artifact-image-versions-and-tags \
  --input package=payments-api --input repository=payments-api \
  --input location=us-central1
```

```runtime
version: v1

inputs:
  package:
    description: Image (package) name inside the repository
    required: true
  repository:
    description: Artifact Registry repository name
    required: true
  location:
    description: Artifact Registry location
    required: true

workflow:
  - binary: gcloud
    args: [artifacts, versions, list, "--package=${package}", "--repository=${repository}", "--location=${location}", "--limit=50"]

  - binary: gcloud
    args: [artifacts, tags, list, "--package=${package}", "--repository=${repository}", "--location=${location}"]
```
