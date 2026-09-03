# Inspect the inputs to a local engineering change

List a workspace and read its two declared source documents before work begins.
This is intentionally a gatherer: Runtime returns the bytes and directory
entries; the human or AI decides whether they agree.

All paths are inputs because Runtime owns no working-directory convention.
The File Provider is auth-free, but policy must grant reads to these paths.

```runtime
version: v1

inputs:
  workspace_dir:
    description: Workspace directory to list
    required: true
  readme_path:
    description: README or task-orientation file to read
    required: true
  config_path:
    description: Configuration or manifest file to read
    required: true

workflow:
  - provider: files
    args: [list, "${workspace_dir}"]
  - provider: files
    args: [read, "${readme_path}"]
  - provider: files
    args: [read, "${config_path}"]
```
