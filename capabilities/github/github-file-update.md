# Update an existing file in a repository

Replaces a file that already exists in a GitHub repository and commits the
change. To create a file that isn't there yet, use
[`github-file-push.md`](./github-file-push.md) — omit `sha` to create-only.
A supplied `sha` is compare-and-set: a stale SHA fails rather than
overwriting newer content.

The provider encodes content. Do not base64 it, and do not use
`github api PUT /repos/…/contents/…`.

## The blob SHA, and why it is an input

GitHub requires the **blob sha of the file being replaced**. Fetch it first,
then pass it in. A capability's steps cannot feed values to each other —
every `${name}` is resolved from the inputs you supply before execution
begins.

```bash
runtime github api GET /repos/kishore-gutta/my-repo/contents/notes.txt

runtime capability execute capabilities/github/github-file-update.md \
  --input repository=kishore-gutta/my-repo \
  --input path=notes.txt \
  --input message="Update notes" \
  --input content="updated content" \
  --input sha=<sha from the GET>
```

## Requirements

- `RUNTIME_GITHUB_TOKEN` set and valid, with `contents: write` on the repo
- the file must already exist at `path`

## Run it

```bash
runtime capability validate capabilities/github/github-file-update.md
runtime capability execute capabilities/github/github-file-update.md --input ...
```

```runtime
version: v1

inputs:
  repository:
    description: Target repository as <owner>/<repo>
    required: true
  path:
    description: Path of the file inside the repository, e.g. notes.txt
    required: true
  message:
    description: Commit message
    required: true
  content:
    description: New file content as UTF-8 text. The provider encodes it.
    required: true
  sha:
    description: Blob sha of the file being replaced
    required: true

workflow:
  - provider: github
    args: [file, put, "${repository}", "${path}", "message=${message}", "content=${content}", "sha=${sha}"]
```
