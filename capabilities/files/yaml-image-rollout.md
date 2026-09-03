# YAML image rollout

Update one named container without reserializing unrelated YAML.

```runtime
version: v1

inputs:
  root:
    description: Policy-granted repository root
    required: true
  container:
    description: Exact container name in the containers sequence
    required: true
  image:
    description: New scalar image value
    required: true

workflow:
  - provider: files
    args: [yaml, set, --path, "spec.template.spec.containers[name=${container}].image", --value, "${image}", --dir, "${root}", --filename, deployment.yaml, --expected-per-file, "1"]
```
