# Every workflow in a repository, and its state

List the workflows a repository defines, each with its path, id and whether it
is `active` or `disabled_manually`. The id is what every other workflow
operation needs, and the UI never shows it.

Pairs with `github-actions-workflow-toggle`, which takes that id. Run this
first: there is no step-output chaining, so the id has to be read here and
passed there by hand.

Distinct from `github-workflow-dispatch-and-list`, which triggers a run. This
one only inventories, and shows disabled workflows that a dispatch would fail
against.

Requires `RUNTIME_GITHUB_TOKEN` with read access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-actions-workflows-inventory.md
runtime capability execute github/github-actions-workflows-inventory \
  --input repository=engineeringruntime/engineering-runtime-ci
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/actions/workflows"]
```
