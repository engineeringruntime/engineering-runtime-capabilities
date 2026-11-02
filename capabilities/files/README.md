# Files capabilities

Local File Engine workflows. They need no credentials, which makes them the
quickest way to check that capability execution works on your machine.

| Capability | What it does |
|---|---|
| [`notes-roundtrip`](notes-roundtrip.md) | Writes a file, then reads it back |

File Engine access is a grant: the policy in force must list the directory in
`file_policy.read_roots` and `file_policy.write_roots`, or the step is refused.
