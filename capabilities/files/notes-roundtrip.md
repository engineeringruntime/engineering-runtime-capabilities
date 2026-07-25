# Write and read back a notes file

A minimal, auth-free capability (the `files` provider declares no auth
provider) useful for proving the capability execution path end-to-end
without any credentials configured.

Run with:

```
runtime capability validate capabilities/files/notes-roundtrip.md
runtime capability execute capabilities/files/notes-roundtrip.md --input path=./notes.txt --input message=hello
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
  - provider: files
    args: [write, "${path}", "${message}"]

  - provider: files
    args: [read, "${path}"]
```
