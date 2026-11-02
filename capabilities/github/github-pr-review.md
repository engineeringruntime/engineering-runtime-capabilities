# GitHub pull request review snapshot

Read a repository summary, one explicit pull request, and repository language
totals. This read-only example requires Engineering Runtime 0.10.0 or later;
older releases reject its `capability_version`, `id` and `needs` fields.

`version: v1` selects the grammar. `capability_version` versions this definition;
it does not select the Runtime release or a Git revision. `id` names each step,
and `needs` refers only to earlier named steps. Execution stays sequential and
globally fail-fast: dependencies do not pass outputs, schedule parallel work,
retry failures or provide rollback.

The GitHub provider chooses GraphQL for the summary, the admitted native `gh`
CLI for PR inspection, and REST for language totals. The capability names
operations, not transports. Supply an explicit repository and PR number;
Runtime does not infer them from the caller's checkout. Authentication requires
a valid `ENGRT_GITHUB_TOKEN`, and the curated PR operation requires `gh` installed.
Keep credentials outside this source and its inputs. Execution policy still
applies to every step.

The commands below read the public GitHub CLI repository, `cli/cli`, and PR
14485. With the installed binary available as `engrt`, run from this repository:

The declaration `engrt_version: ">=0.10.0"` requires an installed Runtime
version of 0.10.0 or later. Runtime checks it before authentication or workflow
execution; `capability_version` separately versions this definition.

```sh
engrt capability validate capabilities/github/github-pr-review.md
engrt --output json capability plan capabilities/github/github-pr-review.md \
  --input repository=cli/cli --input pull_request=14485
engrt --output json capability execute capabilities/github/github-pr-review.md \
  --input repository=cli/cli --input pull_request=14485
```

```runtime
version: v1
engrt_version: ">=0.10.0"
capability_version: "1.0.0"

inputs:
  repository:
    description: Explicit GitHub repository as OWNER/REPO
    required: true
  pull_request:
    description: Pull request number in that repository
    required: true

workflow:
  - id: repository_summary
    provider: github
    args: [repo, summary, "${repository}"]

  - id: pull_request
    needs: [repository_summary]
    provider: github
    args: [pr, view, "${pull_request}", --repo, "${repository}", --json, "number,title,state,mergeable,headRefOid,url"]

  - id: repository_languages
    needs: [repository_summary, pull_request]
    provider: github
    args: [api, GET, "/repos/${repository}/languages"]
```
