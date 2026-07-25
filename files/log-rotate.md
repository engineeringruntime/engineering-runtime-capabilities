# Append to a log file, then confirm it via a directory listing

Exercises the two `files` operations `notes-roundtrip.md` doesn't cover
(`append`, `list`) — between the two capabilities in this folder, every
non-destructive `files` operation has a checked-in, runnable example.
Still auth-free, like every `files` capability.

Point `dir` at an empty or small scratch directory — `list` prints every
entry in it, so a directory with hundreds of files makes for a noisy demo,
not a broken one.

Run with:

```
mkdir -p /tmp/er-demo
runtime capability validate capabilities/files/log-rotate.md
runtime capability execute capabilities/files/log-rotate.md \
  --input path=/tmp/er-demo/example.log --input entry="job finished" --input dir=/tmp/er-demo
```

```runtime
version: v1

inputs:
  path:
    description: Log file to append an entry to
    required: true
  entry:
    description: Line to append
    required: true
  dir:
    description: Directory containing path, listed afterward to confirm the append landed
    required: true

workflow:
  - provider: files
    args: [append, "${path}", "${entry}"]

  - provider: files
    args: [list, "${dir}"]
```

`delete` is intentionally not exercised here — the seeded default policy's
`providers.files.denied: [delete]` rule denies it, so a workflow relying on
it would fail under the out-of-the-box policy. See
`specs/files/capability-spec-files.md` for the full operation table,
including `delete`.
