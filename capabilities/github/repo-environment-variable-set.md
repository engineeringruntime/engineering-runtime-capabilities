# Create an environment variable

> **Mutating.** Creates one variable in an environment. Run `plan` first.
> Execute only on an explicit request.

Creates the variable, then reads it back and checks the value.

## Behaviour to know

- A variable that already exists answers `409`; this capability only creates.
  Updating needs `PATCH …/variables/<NAME>`.
- Names: letters, digits and `_` only, no `GITHUB_` prefix. GitHub stores the
  name **upper-cased**, so read it back as `DEPLOY_REGION` even if you sent
  `deploy_region`.
- The value must not be empty, and a very large value is refused (`Value is
  too large`).
- **Secrets are out of reach.** Environment secrets need a libsodium sealed
  box from the repository's public key, which engrt cannot produce.
- There is no remove step: policy denies `api DELETE`.

## Run it

```bash
engrt capability plan github/repo-environment-variable-set \
  --input organization=<organization> --input repository=<repo> \
  --input environment=<name> --input name=DEPLOY_REGION --input value=ap-southeast-2
```

```runtime
version: v1
capability_version: "1.0.0"
engrt_version: ">=0.13.0"

inputs:
  organization:
    description: GitHub organization that owns the repository
    required: true
  repository:
    description: Repository name without the owner
    required: true
  environment:
    description: Environment name, URL-encoded
    required: true
  name:
    description: Variable name, upper case recommended (letters, digits, underscore)
    required: true
  value:
    description: Variable value, not empty
    required: true

workflow:
  - id: create
    provider: github
    args:
      - api
      - POST
      - "/repos/${organization}/${repository}/environments/${environment}/variables"
      - "name=${name}"
      - "value=${value}"

  - id: verify
    needs: [create]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/environments/${environment}/variables/${name}"]
    outputs:
      value: {pointer: /value, type: string}
    expect: [{ref: steps.verify.outputs.value, equals: "${value}"}]
```
