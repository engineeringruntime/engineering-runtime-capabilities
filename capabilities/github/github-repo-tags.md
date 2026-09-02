# Tags, and what they point at

List the repository's tags with the commit each resolves to. The answer to "was
this release cut from the commit we think it was?" and to "does this tag still
exist, or did someone move it?"

Tags are mutable in git and immutable by convention. Comparing a tag's SHA here
against the commit a release names in `github-release-assets` is how you catch a
tag that was force-moved after publication — rare, and serious when it happens,
because every checksum published against the old commit is now unverifiable.

Read-only. Deleting a tag is a `DELETE`, which default policy denies.

Requires `RUNTIME_GITHUB_TOKEN` with read access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-repo-tags.md
runtime capability execute github/github-repo-tags --input repository=cli/cli
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/tags", "per_page=50"]
```
