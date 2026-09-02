# Cut a release with generated notes

Generate release notes for a tag, create the GitHub Release from them,
then list releases to verify. The generate/create steps use the Releases
REST API via `api` (no curated `release create` operation yet); the
verify step uses `binary: gh` because artifact-oriented release listing
is still a `gh` strength the provider has not wrapped.

Pass `previous_tag_name` when you want notes scoped against a known prior
tag; GitHub will infer otherwise if you omit generate-notes and only use
`generate_release_notes=true` on create — this capability does both
explicitly so the notes response is visible in the audit trail before the
release is cut.

Requires `RUNTIME_GITHUB_TOKEN` with `contents: write` (releases) and
`gh` installed for the list step.

Run with:

```
runtime capability validate capabilities/github/github-release-cut.md

runtime capability execute capabilities/github/github-release-cut.md \
  --input repository=acme/payments-api \
  --input tag_name=v1.2.0 \
  --input previous_tag_name=v1.1.0
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  tag_name:
    description: Tag / release name to cut (e.g. v1.2.0)
    required: true
  previous_tag_name:
    description: Prior tag to diff against when generating notes
    required: true

workflow:
  - provider: github
    args: [api, POST, "/repos/${repository}/releases/generate-notes", "tag_name=${tag_name}", "previous_tag_name=${previous_tag_name}"]

  - provider: github
    args: [api, POST, "/repos/${repository}/releases", "tag_name=${tag_name}", "name=${tag_name}", "generate_release_notes=true", "draft=false"]

  - binary: gh
    args: [release, list, --repo, "${repository}", --limit, "5"]
```
