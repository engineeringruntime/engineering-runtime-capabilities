# Estate configuration update

Apply one reviewed platform change across an explicitly checked-out repository
root. Runtime does not clone, stage, commit or push: those remain separate
governed steps.

Preview the entire workflow before any local mutation:

```sh
runtime capability execute capabilities/files/estate-config-update.md \
  --input root=./checked-out-repositories \
  --input old_branch=master --input new_branch=main \
  --input owner=@platform --dry-run
```

Remove `--dry-run` to recalculate and apply the same bounded local edits.

```runtime
version: v1

inputs:
  root:
    description: Policy-granted root containing checked-out repositories
    required: true
  old_branch:
    description: Exact branch value expected in workflow YAML
    required: true
  new_branch:
    description: Replacement branch value
    required: true
  owner:
    description: CODEOWNERS team or user beginning with @
    required: true

workflow:
  - provider: files
    args: [yaml, replace, --from, "${old_branch}", --to, "${new_branch}", --dir, "${root}", --filename, build.yaml, --expected-per-file, "1"]

  - provider: files
    args: [terraform, set-attribute, --block, module, --label, repository, --attribute, branch, --value, "\"${new_branch}\"", --dir, "${root}", --include, "*.tf", --expected-per-file, "1"]

  - provider: files
    args: [codeowners, add-owner, --pattern, "*", --owner, "${owner}", --dir, "${root}", --filename, CODEOWNERS]
```
