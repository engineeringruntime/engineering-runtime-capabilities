# Push a new file to a repository

Creates a file in a GitHub repository and commits it in one step — the
"drop this note into the repo" workflow, without cloning anything.

Use this when the file does **not** yet exist at that path. To change a file
that is already there, use
[`github-file-update.md`](./github-file-update.md) instead: omit `sha` to
create-only; GitHub refuses to overwrite an existing path.

The provider encodes content. Do not base64 it, and do not use
`github api PUT /repos/…/contents/…`.

## Requirements

- `RUNTIME_GITHUB_TOKEN` set and valid (`runtime auth status`)
- the token needs `contents: write` on the target repository
- the commit is made on the repository's **default branch** unless `branch=` is set

## Run it

```bash
runtime capability validate capabilities/github/github-file-push.md

runtime capability execute capabilities/github/github-file-push.md \
  --input repository=kishore-gutta/my-repo \
  --input path=notes.txt \
  --input message="Add notes via Engineering Runtime" \
  --input content="hello from the runtime"
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
  content:
    description: File content as UTF-8 text. The provider encodes it.
    required: true

workflow:
  - provider: github
    args: [file, put, "${repository}", "${path}", "message=${message}", "content=${content}"]
```
