# files Capabilities

Every capability in this folder is a Markdown file with an embedded
` ```runtime ` workflow block, authored against:

- [`specs/capability-spec.md`](../../specs/capability-spec.md) — the generic grammar and rules
- [`specs/files/capability-spec-files.md`](../../specs/files/capability-spec-files.md) — the files Provider's operations

All `files` capabilities are auth-free — the provider declares no Auth
Engine provider, so none of these need any credential configured. They
are the recommended first capabilities to run in a fresh Runtime Home.

## Index

| Capability | Operations used | Inputs |
|---|---|---|
| `notes-roundtrip.md` | `write`, `read` | `path`, `message` |
| `log-rotate.md` | `append`, `list` | `path`, `entry`, `dir` |
| `scaffold-service-docs.md` | `write` ×3, `list` | `dir`, `readme_content`, `changelog_content`, `notes_content` |
| `incident-log-lifecycle.md` | `write`, `append`, `read` | `path`, `opening`, `update` |
| `directory-snapshot-report.md` | `list` ×2, `write` | `current_dir`, `reference_dir`, `report_path` |

Every non-destructive `files` operation has a checked-in example, in more
than one combination — single-path (`notes-roundtrip.md`,
`incident-log-lifecycle.md`), multi-path within one directory
(`scaffold-service-docs.md`), and multi-directory
(`directory-snapshot-report.md`). `delete` is intentionally not exercised
by any of them — the seeded default policy denies it
(`providers.files.denied: [delete]`) — see
`specs/files/capability-spec-files.md`.

## Running them

```bash
runtime capability validate capabilities/files/notes-roundtrip.md
runtime capability execute capabilities/files/notes-roundtrip.md \
  --input path=./notes.txt --input message=hello

runtime capability validate capabilities/files/log-rotate.md
runtime capability execute capabilities/files/log-rotate.md \
  --input path=/tmp/er-demo/example.log --input entry="job finished" --input dir=/tmp/er-demo

mkdir -p /tmp/er-new-service
runtime capability validate capabilities/files/scaffold-service-docs.md
runtime capability execute capabilities/files/scaffold-service-docs.md \
  --input dir=/tmp/er-new-service --input readme_content="# my-service" \
  --input changelog_content="## Unreleased" --input notes_content="Bootstrapped via Engineering Runtime."

runtime capability validate capabilities/files/incident-log-lifecycle.md
runtime capability execute capabilities/files/incident-log-lifecycle.md \
  --input path=/tmp/er-demo/incident-042.log \
  --input opening=$'[opened] payments API returning 500s in prod\n' \
  --input update="[update] rolled back to previous deploy, error rate dropping"

mkdir -p /tmp/er-demo/current /tmp/er-demo/reference
runtime capability validate capabilities/files/directory-snapshot-report.md
runtime capability execute capabilities/files/directory-snapshot-report.md \
  --input current_dir=/tmp/er-demo/current --input reference_dir=/tmp/er-demo/reference \
  --input report_path=/tmp/er-demo/snapshot-report.txt
```

Validate the whole folder at once:

```bash
for f in capabilities/files/*.md; do
  [ "$(basename "$f")" = README.md ] && continue
  runtime capability validate "$f"
done
```
