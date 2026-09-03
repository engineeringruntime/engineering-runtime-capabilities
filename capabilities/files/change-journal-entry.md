# Append and verify a local change-journal entry

Append one caller-supplied line, read the journal back, then list its directory.
This is useful for append-only operator notes where the write must be visible in
the same governed workflow. It never deletes or truncates the journal.

```runtime
version: v1

inputs:
  journal_path:
    description: Journal file to append and read
    required: true
  entry:
    description: Single journal entry to append
    required: true
  journal_dir:
    description: Directory containing the journal
    required: true

workflow:
  - provider: files
    args: [append, "${journal_path}", "${entry}"]
  - provider: files
    args: [read, "${journal_path}"]
  - provider: files
    args: [list, "${journal_dir}"]
```
