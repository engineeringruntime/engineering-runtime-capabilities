# Push a new file to a repository

Creates a file in a GitHub repository and commits it in one step — the
"drop this note into the repo" workflow, without cloning anything.

Use this when the file does **not** yet exist at that path. To change a file
that is already there, use
[`github-file-update.md`](./github-file-update.md) instead: GitHub requires
the existing blob's `sha` to replace it, and refuses a create that supplies
one.

## Why this uses `api`

The GitHub Provider exposes no first-class file-writing operation today
(`runtime github --help` is the authority). The repository Contents API
covers it, so this capability reaches it through the `api` escape hatch.
That is exactly what the escape hatch is for — and if this workflow becomes
common, the right fix is to add a `file push` operation to the provider
rather than to keep hand-writing the path here.

## Content must be base64

The Contents API takes file content base64-encoded, and the runtime has no
encoding primitive — it is a deterministic executor, not a data-transformer.
So the encoded content is a declared input:

```bash
base64 -i notes.txt          # macOS
base64 -w0 notes.txt         # Linux
```

For short content you can encode inline:

```bash
--input content_base64="$(printf 'hello from the runtime\n' | base64)"
```

## Requirements

- `RUNTIME_GITHUB_TOKEN` set and valid (`runtime auth status`)
- the token needs `contents: write` on the target repository
- the commit is made on the repository's **default branch**

## Run it

```bash
runtime capability validate capabilities/github/github-file-push.md

runtime capability execute capabilities/github/github-file-push.md \
  --input repository=kishore-gutta/my-repo \
  --input path=notes.txt \
  --input message="Add notes via Engineering Runtime" \
  --input content_base64="$(printf 'hello from the runtime\n' | base64)"
```

Every input is required. Optional inputs are deliberately avoided here: an
input that is declared but not supplied is left in the arguments verbatim
as `${name}`, which would be sent to GitHub as a literal string.

## Verify afterwards

```bash
runtime github api GET /repos/kishore-gutta/my-repo/contents/notes.txt
runtime audit tail -n 5
```

```runtime
version: v1

inputs:
  repository:
    description: Target repository as <owner>/<repo>
    required: true
  path:
    description: Path of the file inside the repository, e.g. notes.txt or docs/notes.md
    required: true
  message:
    description: Commit message
    required: true
  content_base64:
    description: File content, base64-encoded
    required: true

workflow:
  - provider: github
    args: [api, PUT, "/repos/${repository}/contents/${path}", "message=${message}", "content=${content_base64}"]
```
