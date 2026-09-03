# Terraform provider upgrade

Update a selected required-provider object and optional Terraform version
constraint across an explicitly bounded checkout.

```runtime
version: v1

inputs:
  root:
    description: Policy-granted repository root
    required: true
  source:
    description: Exact provider source, for example integrations/github
    required: true
  provider_version:
    description: New provider constraint without surrounding quotes
    required: true
  terraform_version:
    description: New required_version constraint without surrounding quotes
    required: true

workflow:
  - provider: files
    args: [terraform, update-provider, --source, "${source}", --version, "${provider_version}", --terraform-version, "${terraform_version}", --dir, "${root}", --include, "*.tf", --expected-per-file, "2"]
```
