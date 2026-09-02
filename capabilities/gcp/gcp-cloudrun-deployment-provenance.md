# What is deployed, and which image is it running

The Cloud Run services in a region, the revisions behind them, and the tags in
the Artifact Registry repository those images come from. Read together they
answer the question every incident starts with: **what is actually running right
now, and which build is it?**

Cloud Run revisions name their image by digest. Artifact Registry tags map
digests back to the tag someone pushed. Neither half is useful alone: a digest
tells you nothing a human recognises, and a tag list does not say what is live.

**Nothing correlates them for you.** The v1 grammar has no step-output chaining,
so this capability puts both halves in one audited record and a person — or the
agent that called it — matches the digest. That is the honest shape; a
capability that claimed to resolve the mapping would be inventing it.

`${repository}` and `${package}` are usually the same string for a Cloud Run
source deploy, because the deploy names the image after the service.

Requires `gcloud`, `authentication.gcp.enabled: true`, ADC, and the Cloud Run
and Artifact Registry APIs enabled.

Run with:

```
runtime capability validate capabilities/gcp/gcp-cloudrun-deployment-provenance.md
runtime capability execute gcp/gcp-cloudrun-deployment-provenance \
  --input region=us-central1 --input location=us-central1 \
  --input repository=payments-api --input package=payments-api
```

```runtime
version: v1

inputs:
  region:
    description: Cloud Run region
    required: true
  location:
    description: Artifact Registry location
    required: true
  repository:
    description: Artifact Registry repository holding the deployed image
    required: true
  package:
    description: Package (image) name inside that repository
    required: true

workflow:
  - binary: gcloud
    args: [run, services, list, "--region=${region}"]

  - binary: gcloud
    args: [run, revisions, list, "--region=${region}", "--limit=20"]

  - binary: gcloud
    args: [artifacts, tags, list, "--package=${package}", "--repository=${repository}", "--location=${location}"]
```
