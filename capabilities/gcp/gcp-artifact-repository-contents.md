# What is stored in an Artifact Registry repository

The packages a repository holds and the files behind them, with sizes. The
answer to "what is in here, and what is it costing?"

Registry growth is the quiet cost in a container pipeline: every push of every
branch keeps its layers, and nothing removes them by default. `files list`
carries the byte sizes that make that concrete.

**`--repository` and `--location` are flags, and that is why this works.** The
same information via the positional form — `gcloud artifacts docker images list
<repo-uri>` — is refused by the compiled safety profile, because a positional
target is resolved through a mapping Runtime cannot pin. Flags are part of the
pinned invocation; positional targets are not. Verified both ways.

Read-only. Deleting a package or version resolves a named target and is refused.

Requires `gcloud`, `authentication.gcp.enabled: true`, ADC, and the Artifact
Registry API enabled.

Run with:

```
runtime capability validate capabilities/gcp/gcp-artifact-repository-contents.md
runtime capability execute gcp/gcp-artifact-repository-contents \
  --input repository=payments-api --input location=us-central1
```

```runtime
version: v1

inputs:
  repository:
    description: Artifact Registry repository name
    required: true
  location:
    description: Artifact Registry location, e.g. us-central1
    required: true

workflow:
  - binary: gcloud
    args: [artifacts, packages, list, "--repository=${repository}", "--location=${location}"]

  - binary: gcloud
    args: [artifacts, files, list, "--repository=${repository}", "--location=${location}", "--limit=50"]
```
