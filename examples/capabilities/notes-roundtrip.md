# Write and read back a notes file

A minimal, auth-free capability (both steps use `provider: none`) useful
for proving the capability execution path end-to-end without any
credentials configured.

Run with:

```
runtime capability validate examples/capabilities/notes-roundtrip.md
runtime capability execute examples/capabilities/notes-roundtrip.md --input path=./notes.txt --input message=hello
```

```runtime
version: v1

inputs:
  path:
    description: File to write and read back
    required: true
  message:
    description: Content to write
    required: true

workflow:
  - command: files.write
    args: ["${path}", "${message}"]

  - command: files.read
    args: ["${path}"]
```
