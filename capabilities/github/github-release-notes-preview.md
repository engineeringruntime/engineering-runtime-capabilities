# Generate release notes without publishing anything

Ask GitHub to compose the release notes for a tag — merged pull requests, new
contributors, the full changelog link — and return them **without creating a
release**.

The endpoint is a `POST`, but it publishes nothing: it computes the notes and
hands them back. That makes it the safe half of `github-release-cut`, which
generates *and* creates. Use this one to read what the notes would say before
committing to them, especially when `previous_tag_name` changes the range.

The tag does not have to exist yet. GitHub composes notes for what *would* be
released, which is exactly what a pre-release review wants — verified against a
tag that had not been cut.

**It needs write access, and says `404` when it does not have it.** Not `403`.
GitHub answers a permission failure on this endpoint by claiming the endpoint is
not there, presumably so a read-only token cannot probe which repositories it
could write to. Verified both ways: `404` against `cli/cli` with a read-only
token, `200` against a repository the same token can write. So a `404` here
means "this token cannot write to that repository" far more often than it means
the repository is missing.

Requires `RUNTIME_GITHUB_TOKEN` with **write access** to the repository, even
though nothing is written.

Run with:

```
runtime capability validate capabilities/github/github-release-notes-preview.md
runtime capability execute github/github-release-notes-preview \
  --input repository=cli/cli --input tag_name=v2.60.0
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  tag_name:
    description: Tag the notes are composed for; need not exist yet
    required: true

workflow:
  - provider: github
    args: [api, POST, "/repos/${repository}/releases/generate-notes", "tag_name=${tag_name}"]
```
