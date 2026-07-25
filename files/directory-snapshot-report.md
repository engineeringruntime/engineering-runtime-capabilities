# List two directories side by side, and record the comparison

Lists two directories in one workflow — a "current state" directory and a
"reference/archive" directory — then writes both listings into a single
report file. Where every other `files` capability in this folder operates
on one location, this one is the multi-location shape: useful for a
recurring check like "does this release's output directory still look like
the last known-good one," without the runtime doing any diffing itself —
it only gathers what's actually on disk into one place for a human or AI to
compare.

Still auth-free, like every `files` capability.

Run with:

```
mkdir -p /tmp/er-demo/current /tmp/er-demo/reference
runtime capability validate capabilities/files/directory-snapshot-report.md
runtime capability execute capabilities/files/directory-snapshot-report.md \
  --input current_dir=/tmp/er-demo/current \
  --input reference_dir=/tmp/er-demo/reference \
  --input report_path=/tmp/er-demo/snapshot-report.txt
```

```runtime
version: v1

inputs:
  current_dir:
    description: Directory reflecting the current state to check
    required: true
  reference_dir:
    description: Directory to compare it against (e.g. a known-good archive or previous release)
    required: true
  report_path:
    description: File the comparison note is written to
    required: true

workflow:
  - provider: files
    args: [list, "${current_dir}"]

  - provider: files
    args: [list, "${reference_dir}"]

  - provider: files
    args: [write, "${report_path}", "snapshot comparison recorded — see runtime audit tail for both directory listings"]
```

The two `list` steps are what actually matter here: run with `--output
json` (or check `runtime audit tail -n 5` afterward) to see each
directory's real entries in its own audit record — one `transport=file
command=files list` entry per directory, each with its own listing in the
result, so nothing from one directory ever gets merged into the other's
record. The `write` step only leaves a marker that a comparison ran and
when; comparing the two listings themselves is a human/AI reasoning step
over the audit output, consistent with "the runtime executes, AI reasons."

If you need the actual entries side by side without opening the audit log,
use `runtime --output json capability execute ... ` and read the two
`list` results directly from the JSON, rather than adding diff logic to
this capability — a workflow step never gets its own execution path beyond
what the File Engine already does.
