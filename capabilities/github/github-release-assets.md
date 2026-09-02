# What a release actually shipped

List a release's assets with name, size, content type and download count, and
read the release itself for its tag, target commit and draft/prerelease flags.

The check that catches a release published with the wrong artifacts, or with
none at all. A release whose body promises six platform archives and whose
asset list has four is a broken install for two platforms, and nothing in the
GitHub UI makes that obvious.

Asset **download** is not here: the endpoint redirects to a short-lived blob URL
and following it writes a file, which the capability grammar does not express.
Verify checksums with the published checksums file after downloading through
`gh release download`.

`${release_id}` comes from `github-release-latest-and-history`. There is no
step-output chaining; pass it explicitly.

Requires `RUNTIME_GITHUB_TOKEN` with read access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-release-assets.md
runtime capability execute github/github-release-assets \
  --input repository=cli/cli --input release_id=1234567
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  release_id:
    description: Numeric release id, from github-release-latest-and-history
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/releases/${release_id}"]

  - provider: github
    args: [api, GET, "/repos/${repository}/releases/${release_id}/assets", "per_page=100"]
```
