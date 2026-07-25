# Update an existing file in a repository

Replaces a file that already exists in a GitHub repository and commits the
change. To create a file that isn't there yet, use
[`github-file-push.md`](./github-file-push.md) — GitHub rejects a create
that supplies a `sha`, and rejects an update that omits one.

## The two-command shape, and why

GitHub requires the **blob sha of the file being replaced**, so you fetch it
first:

```bash
# 1. get the current sha
runtime github api GET /repos/kishore-gutta/my-repo/contents/notes.txt

# 2. pass it in
runtime capability execute capabilities/github/github-file-update.md \
  --input repository=kishore-gutta/my-repo \
  --input path=notes.txt \
  --input message="Update notes" \
  --input content_base64="$(printf 'updated content\n' | base64)" \
  --input sha=<sha from step 1>
```

This is two commands rather than one because a capability's steps cannot
feed values to each other — every `${name}` is resolved from the inputs you
supply before execution begins, never from a previous step's output. That
keeps execution deterministic and every step independently auditable, and it
is a real constraint to design around, not an oversight.

The first step below re-fetches the file anyway, so the run records what was
replaced: the audit log then holds both the old state and the write.

## Content must be base64

```bash
base64 -i notes.txt          # macOS
base64 -w0 notes.txt         # Linux
```

## Requirements

- `RUNTIME_GITHUB_TOKEN` set and valid, with `contents: write` on the repo
- the file must already exist at `path` — step 1 fails and stops the run if
  it does not, which is the intended guard

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
  content_base64:
    description: New file content, base64-encoded
    required: true
  sha:
    description: Blob sha of the file being replaced (from `github api GET /repos/<repo>/contents/<path>`)
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/contents/${path}"]

  - provider: github
    args: [api, PUT, "/repos/${repository}/contents/${path}", "message=${message}", "content=${content_base64}", "sha=${sha}"]
```
