# Repository delivery readiness across GitHub and the local checkout

Gather remote repository, pull-request and CI state beside the local working
tree and its declared delivery document. Runtime returns each source separately;
the reviewer decides whether they describe the same releasable change.

This workflow is read-only. It requires `RUNTIME_GITHUB_TOKEN`, `gh`, `git`, and
File Provider read access to the declared document.

```runtime
version: v1

inputs:
  repository:
    description: GitHub repository as <owner>/<repo>
    required: true
  workdir:
    description: Absolute path to the corresponding local Git checkout
    required: true
  delivery_document:
    description: Absolute path to the release, change, or delivery document
    required: true

workflow:
  - provider: github
    args: [repo, summary, "${repository}"]
  - provider: github
    args: [pr, list, --repo, "${repository}", --limit, "20", --json, "number,title,state,isDraft,reviewDecision,statusCheckRollup"]
  - provider: github
    args: [run, list, --repo, "${repository}", --limit, "10"]
  - provider: files
    args: [read, "${delivery_document}"]
  - binary: git
    args: [-C, "${workdir}", status, --short]
  - binary: git
    args: [-C, "${workdir}", diff, --check]
  - binary: git
    args: [-C, "${workdir}", log, -5, --oneline]
```
