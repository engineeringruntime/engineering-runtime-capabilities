# Promote a verified release to an environment through the repository's deploy workflow

> **Mutating.** It starts a GitHub Actions deployment workflow, which runs on
> GitHub and uses Actions minutes. Run `plan` first. Execute only when a person
> has asked for this version to go to this environment.

Deploys **one released version** (`version`, the release tag) to one
environment, by dispatching the repository's deploy workflow at that tag.
GitHub's environment rules still apply when the workflow runs: on a
`production` set up by [repo-environment-protect](repo-environment-protect.md),
the deployment waits for the reviewer team and the wait timer. This capability
decides **whether** to start; GitHub decides **whether it may proceed**.

| Gate | Passes when | Read |
|---|---|---|
| `release_gate` | a published (not draft) release `version` exists | GraphQL `release(tagName:)` |
| `build_gate` | the release's commit has a successful `build` check from GitHub Actions (app 15368) | REST `commits/<sha>/check-runs` |
| `workflow_gate` | the deploy workflow exists and is `active` | REST `actions/workflows/<file>` |
| `env_gate` | the environment exists | GraphQL `environment(name:)` |
| `busy_gate` | the environment's latest deployment is not in progress, queued, pending or waiting for approval | GraphQL `deployments` |
| `runs_<status>_gate` | no run of the deploy workflow is queued, in progress, waiting, requested or pending (a dispatched run exists at once; its deployment only once the job starts) | REST `actions/workflows/<file>/runs` |

Then the workflow is dispatched **only when the environment does not already
have this version**:

| Latest deployment to the environment | Action |
|---|---|
| none | dispatch |
| another version | dispatch |
| this version, failed or inactive | dispatch again |
| this version, `ACTIVE` or `SUCCESS` | nothing (`SATISFIED`) |

| Run | Result |
|---|---|
| new version, gates pass | workflow dispatched (`APPLIED`); GitHub runs it under the environment's rules |
| rerun while it waits for approval or runs | stops at a `runs_<status>_gate` or `busy_gate`; nothing dispatched |
| rerun after it deployed | nothing dispatched (`SATISFIED`) |
| release missing or a draft | stops at `release_gate` |
| release commit never built by GitHub Actions | stops at `build_gate` |

## The deploy workflow it expects

A workflow file (input `workflow`, e.g. `deploy.yml`) on the release tag, with a
`workflow_dispatch` input named `environment`, and a job that names that
environment so GitHub creates the deployment and applies its rules:

    on:
      workflow_dispatch:
        inputs:
          environment:
            required: true
            type: string
    permissions:
      contents: read
    concurrency:
      group: deploy-${{ inputs.environment }}
      cancel-in-progress: false
    jobs:
      deploy:
        runs-on: ubuntu-latest
        environment: ${{ inputs.environment }}
        steps:
          - run: echo "deploy ${{ github.ref_name }} to ${{ inputs.environment }}"

The `concurrency` group is a second guard: GitHub queues a second deployment to
the same environment instead of running both. The workflow runs at the tag
(`--ref <version>`), so `github.ref_name` is the
version and GitHub records the deployment's ref as that tag. The environment
must allow `v*` tags to deploy; `repo-environment-protect` adds that.

## What it needs

- Policy: the GitHub provider with `graphql`, `api GET` and `workflow run`.
- Credential: Actions read/write and Contents read on the repository.
- Actions minutes for the workflow run.

## Known limits

- **Dispatch is checked, the deployment is not.** GitHub runs the workflow
  after this capability returns; whether it succeeded is visible on the next
  run (`SATISFIED` once the deployment is `ACTIVE`) or in GitHub. Workflow logs
  are readable through `engrt github run view`. Artifacts are not.
- The comparison uses the deployment's ref name, so the deploy workflow must
  run at the tag. A deployment created at a branch or a bare SHA is treated as
  "another version".
- One deploy run of the workflow at a time, across environments: while
  `production` waits for approval, a `staging` promotion through the same
  workflow is refused.
- A draft or pre-release check is not applied per environment: `release_gate`
  refuses drafts, and pre-releases may be deployed anywhere.

## Run it

```bash
engrt capability plan github/repo-deploy-promote \
  --input organization=<organization> --input repository=<repository> \
  --input version=v0.1.0 --input environment=staging --input workflow=deploy.yml
```

```runtime
version: v1
capability_version: "1.1.0"
engrt_version: ">=0.13.0"

inputs:
  organization:
    description: GitHub organization that owns the repository
    required: true
  repository:
    description: Repository name without the owner
    required: true
  version:
    description: Release tag to deploy, e.g. v0.1.0
    required: true
  environment:
    description: Environment to deploy to, e.g. staging or production
    required: true
  workflow:
    description: Deploy workflow file name, e.g. deploy.yml
    required: true

workflow:
  # ==== Release and its build ====
  - id: release_observe
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $tag: String!) { repository(owner: $owner, name: $name) { release(tagName: $tag) { tagName tagCommit { oid } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "tag=${version}"
    outputs:
      tag: {pointer: /repository/release/tagName, type: string, optional: true}
      commit: {pointer: /repository/release/tagCommit/oid, type: string, optional: true}

  - id: release_gate
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $tag: String!) { repository(owner: $owner, name: $name) { release(tagName: $tag) { tagName isDraft isPrerelease } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "tag=${version}"
    outputs:
      tag: {pointer: /repository/release/tagName, type: string, optional: true}
      draft: {pointer: /repository/release/isDraft, type: boolean, optional: true}
      prerelease: {pointer: /repository/release/isPrerelease, type: boolean, optional: true}
    expect:
      - {ref: steps.release_gate.outputs.tag, equals: "${version}"}
      - {ref: steps.release_gate.outputs.draft, equals: "false"}

  - id: build_gate
    needs: [release_observe]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/commits/${steps.release_observe.outputs.commit}/check-runs", "check_name=build", "app_id=15368", "filter=latest", "per_page=1"]
    outputs:
      conclusion: {pointer: /check_runs/0/conclusion, type: string, optional: true}
      app: {pointer: /check_runs/0/app/id, type: integer, optional: true}
    expect:
      - {ref: steps.build_gate.outputs.conclusion, equals: success}
      - {ref: steps.build_gate.outputs.app, equals: "15368"}

  # ==== Workflow and environment ====
  - id: workflow_gate
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/workflows/${workflow}"]
    outputs:
      state: {pointer: /state, type: string}
      path: {pointer: /path, type: string}
    expect:
      - {ref: steps.workflow_gate.outputs.state, equals: active}

  - id: env_gate
    provider: github
    args: [graphql, "query($owner: String!, $name: String!, $env: String!) { repository(owner: $owner, name: $name) { environment(name: $env) { name } } }", "owner=${organization}", "name=${repository}", "env=${environment}"]
    outputs:
      name: {pointer: /repository/environment/name, type: string, optional: true}
    expect:
      - {ref: steps.env_gate.outputs.name, equals: "${environment}"}

  # ==== No run of the deploy workflow in flight: a dispatched run exists at once, its deployment only when the job starts ====
  - id: runs_queued_gate
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/workflows/${workflow}/runs", "status=queued", "per_page=1"]
    outputs:
      runs: {pointer: /total_count, type: integer}
    expect:
      - {ref: steps.runs_queued_gate.outputs.runs, equals: "0"}

  - id: runs_in_progress_gate
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/workflows/${workflow}/runs", "status=in_progress", "per_page=1"]
    outputs:
      runs: {pointer: /total_count, type: integer}
    expect:
      - {ref: steps.runs_in_progress_gate.outputs.runs, equals: "0"}

  - id: runs_waiting_gate
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/workflows/${workflow}/runs", "status=waiting", "per_page=1"]
    outputs:
      runs: {pointer: /total_count, type: integer}
    expect:
      - {ref: steps.runs_waiting_gate.outputs.runs, equals: "0"}

  - id: runs_requested_gate
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/workflows/${workflow}/runs", "status=requested", "per_page=1"]
    outputs:
      runs: {pointer: /total_count, type: integer}
    expect:
      - {ref: steps.runs_requested_gate.outputs.runs, equals: "0"}

  - id: runs_pending_gate
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/workflows/${workflow}/runs", "status=pending", "per_page=1"]
    outputs:
      runs: {pointer: /total_count, type: integer}
    expect:
      - {ref: steps.runs_pending_gate.outputs.runs, equals: "0"}

  # ==== Current deployment to the environment (read after the run gates: with no deploy run in flight, the state read here is settled) ====
  - id: deploy_observe
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $env: String!) { repository(owner: $owner, name: $name) { deployments(environments: [$env], first: 1, orderBy: {field: CREATED_AT, direction: DESC}) { totalCount nodes { state ref { name } } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "env=${environment}"
    outputs:
      total: {pointer: /repository/deployments/totalCount, type: integer}
      state: {pointer: /repository/deployments/nodes/0/state, type: string, optional: true}
      ref: {pointer: /repository/deployments/nodes/0/ref/name, type: string, optional: true}

  - id: busy_gate
    needs: [deploy_observe]
    when: [{ref: steps.deploy_observe.outputs.total, not_equals: "0"}]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $env: String!) { repository(owner: $owner, name: $name) { deployments(environments: [$env], first: 1, orderBy: {field: CREATED_AT, direction: DESC}) { nodes { state } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "env=${environment}"
    outputs:
      state: {pointer: /repository/deployments/nodes/0/state, type: string}
    expect:
      - {ref: steps.busy_gate.outputs.state, not_equals: IN_PROGRESS}
      - {ref: steps.busy_gate.outputs.state, not_equals: QUEUED}
      - {ref: steps.busy_gate.outputs.state, not_equals: PENDING}
      - {ref: steps.busy_gate.outputs.state, not_equals: WAITING}

  # ==== Dispatch, only when the environment does not already have this version ====
  # Three mutually exclusive cases; no OR in the grammar, so one step each.
  # Every case is decided on the same deploy_observe read, excluding busy
  # states (at most four predicates per gate). busy_gate's own, later read only
  # ever adds a refusal; it never lets a decision taken on an earlier read through.
  - id: dispatch_first
    needs: [release_gate, build_gate, workflow_gate, env_gate, deploy_observe, busy_gate, runs_queued_gate, runs_in_progress_gate, runs_waiting_gate, runs_requested_gate, runs_pending_gate]
    when: [{ref: steps.deploy_observe.outputs.total, equals: "0"}]
    provider: github
    args: [workflow, run, "${workflow}", --repo, "${organization}/${repository}", --ref, "${version}", -f, "environment=${environment}"]

  - id: dispatch_new_version
    needs: [release_gate, build_gate, workflow_gate, env_gate, deploy_observe, busy_gate, runs_queued_gate, runs_in_progress_gate, runs_waiting_gate, runs_requested_gate, runs_pending_gate]
    when:
      - {ref: steps.deploy_observe.outputs.ref, not_equals: "${version}"}
      - {ref: steps.deploy_observe.outputs.state, not_equals: IN_PROGRESS}
      - {ref: steps.deploy_observe.outputs.state, not_equals: QUEUED}
      - {ref: steps.deploy_observe.outputs.state, not_equals: WAITING}
    provider: github
    args: [workflow, run, "${workflow}", --repo, "${organization}/${repository}", --ref, "${version}", -f, "environment=${environment}"]

  - id: dispatch_retry
    needs: [release_gate, build_gate, workflow_gate, env_gate, deploy_observe, busy_gate, runs_queued_gate, runs_in_progress_gate, runs_waiting_gate, runs_requested_gate, runs_pending_gate]
    when:
      - {ref: steps.deploy_observe.outputs.ref, equals: "${version}"}
      - {ref: steps.deploy_observe.outputs.state, not_equals: ACTIVE}
      - {ref: steps.deploy_observe.outputs.state, not_equals: SUCCESS}
      - {ref: steps.deploy_observe.outputs.state, not_equals: IN_PROGRESS}
    provider: github
    args: [workflow, run, "${workflow}", --repo, "${organization}/${repository}", --ref, "${version}", -f, "environment=${environment}"]
```
