# Scaffold starter docs for a new service directory

Bootstraps the three starter documents most new service/project directories
need on day one, then lists the directory to confirm all three landed.
Unlike `notes-roundtrip.md` and `log-rotate.md`, which each touch a single
`path`, this capability writes to **three different paths** in one
workflow — the shape worth exercising when a capability's job is
"create a set of files," not "operate on one already-known file."

Still auth-free, like every `files` capability — no credentials, no
Runtime Context, nothing but the File Engine.

Run with:

```
mkdir -p /tmp/er-new-service
runtime capability validate capabilities/files/scaffold-service-docs.md
runtime capability execute capabilities/files/scaffold-service-docs.md \
  --input dir=/tmp/er-new-service \
  --input readme_content="# my-service" \
  --input changelog_content="## Unreleased" \
  --input notes_content="Bootstrapped via Engineering Runtime."
```

```runtime
version: v1

inputs:
  dir:
    description: Directory to scaffold (must already exist — files does not create directories)
    required: true
  readme_content:
    description: Content for README.md
    required: true
  changelog_content:
    description: Content for CHANGELOG.md
    required: true
  notes_content:
    description: Content for NOTES.md
    required: true

workflow:
  - provider: files
    args: [write, "${dir}/README.md", "${readme_content}"]

  - provider: files
    args: [write, "${dir}/CHANGELOG.md", "${changelog_content}"]

  - provider: files
    args: [write, "${dir}/NOTES.md", "${notes_content}"]

  - provider: files
    args: [list, "${dir}"]
```

The final `list` step is the confirmation: `runtime audit tail -n 5` after
running this shows four entries — three `write`s and the `list` — and the
`list` step's output (visible with `--output json`) is the three filenames,
proof all three writes landed before this workflow reports success.

Note `write` overwrites: re-running this against a `dir` that already has
these three files replaces their content rather than erroring — useful for
re-scaffolding, but not what you want if you've since hand-edited any of
them.
