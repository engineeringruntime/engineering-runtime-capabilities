# Open an incident log, add an update, then review it

The full non-destructive lifecycle of a single file in one workflow:
**create** it (`write`), **update** it (`append`), then **review** it
(`read`) — three different operations chained on one `path`, the one
combination neither `notes-roundtrip.md` (`write`+`read`) nor
`log-rotate.md` (`append`+`list`) demonstrates by itself.

Models a realistic on-call shape: open an incident record when something
breaks, append a follow-up once there's more to say, then read the whole
thing back before writing a summary or closing it out. Still auth-free —
no credentials, no Runtime Context.

Run with:

```
runtime capability validate capabilities/files/incident-log-lifecycle.md
runtime capability execute capabilities/files/incident-log-lifecycle.md \
  --input path=/tmp/er-demo/incident-042.log \
  --input opening=$'[opened] payments API returning 500s in prod\n' \
  --input update="[update] rolled back to previous deploy, error rate dropping"
```

Note the `$'...\n'` around `opening` (bash/zsh syntax for a string with a
real newline). Without it the two records land concatenated on one line —
see the File Engine note at the bottom of this file for why.

```runtime
version: v1

inputs:
  path:
    description: Incident log file. Created fresh by the first step — point this at a new path, not an existing log you want to preserve.
    required: true
  opening:
    description: The initial incident record written when the log is opened
    required: true
  update:
    description: A follow-up line appended once there's more to report
    required: true

workflow:
  - provider: files
    args: [write, "${path}", "${opening}"]

  - provider: files
    args: [append, "${path}", "${update}"]

  - provider: files
    args: [read, "${path}"]
```

The `write` step **overwrites** — this is deliberately the "open a new
incident" step, not a safe append-if-missing. Running this capability a
second time against the same `path` discards whatever was there and starts
a fresh log; to keep adding updates to an already-open incident, call
`runtime files append <path> "<update>"` directly (see
`commands/files_commands.txt`) rather than re-running this whole
capability.

The final `read` is what makes this useful in practice: its output (visible
with `--output json`, or just eyeballed from a normal run) is the complete
log — both the opening record and the update — in one call, instead of two
separate operations a human or AI would otherwise have to reconcile by hand.

**One File Engine quirk worth knowing before relying on this**: `write`
stores `opening` exactly as given, with no trailing newline; `append` then
writes `update + "\n"` immediately after whatever bytes are already there.
If `opening` doesn't already end in a newline, the two lines land
concatenated on one line rather than stacked — end `opening` with your own
`\n` (or a trailing space) if you want them visually separated in the raw
file. `log-rotate.md` never hits this because it only ever appends, never
mixes a no-newline `write` with a following `append`.
