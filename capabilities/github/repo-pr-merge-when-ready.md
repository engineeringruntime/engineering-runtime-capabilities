# Merge one pull request at the reviewed commit, only when GitHub says it is ready and the build is green

> **Mutating.** It squash-merges a pull request. Run `plan` first. Execute only
> when a person has asked for this pull request to be merged at this commit.

The merge is of **one named commit** (`head_sha`, a full 40-character SHA): the
commit someone reviewed. If anything was pushed after it, the run stops. This is
what a merge bot does, with each check stated and recorded.

| Gate | Passes when | Read |
|---|---|---|
| `head_gate` | the pull request is open, not a draft, its head is exactly `head_sha`, and GitHub's merge state is `CLEAN` (every ruleset requirement met: required reviews, required checks, branch up to date, no conflicts) | GraphQL `pullRequest(number:)` |
| `checks_gate` | every check on `head_sha` passed (combined state `SUCCESS`), including checks the ruleset does not require | GraphQL `statusCheckRollup` |
| `build_gate` | `head_sha` has a successful `build` check from GitHub Actions (app 15368), so a commit is never merged on another app's green alone | REST `commits/<sha>/check-runs` |

Then the pull request is squash-merged with `sha=<head_sha>`, which makes GitHub
itself refuse the merge if the head moved between the gates and the write.
`merge_verify` proves the pull request is merged and its head was `head_sha`.

| Run | Result |
|---|---|
| ready | merged and verified (`APPLIED`) |
| rerun after the merge | gates and merge not required, verify passes (`SATISFIED`) |
| a commit pushed after review | stops at `head_gate`; nothing written |
| review missing, branch behind, conflicts | stops at `head_gate` (`BLOCKED`, `BEHIND`, `DIRTY`); nothing written |
| a failing or pending check | stops at `checks_gate`; nothing written |
| no `build` check from GitHub Actions | stops at `build_gate`; nothing written |
| pull request closed without merging | gates and merge not required; `merge_verify` fails |

## What it needs

- Policy: the GitHub provider with `graphql`, `api GET` and `api PUT`.
- Credential: Contents and Pull requests read/write on the repository.
- A repository whose ruleset defines what "ready" means (required reviews and
  checks), as [java-springboot-service-onboard](java-springboot-service-onboard.md)
  sets up. `CLEAN` is GitHub's own verdict against those rules.

## Known limits

- **`HAS_HOOKS` is refused.** GitHub reports `HAS_HOOKS` for a mergeable pull
  request on a repository with pre-receive hooks (GitHub Enterprise Server). The
  grammar cannot accept one of two values on one output, so only `CLEAN` passes.
- **`UNKNOWN` merge state stops the run.** GitHub computes mergeability in the
  background; straight after a push the state can be `UNKNOWN`. Run again a few
  seconds later.
- The merge method is squash, the only method the onboarding standard allows.
- The pull request merges into its own base branch; the gates do not name the
  base.

## Run it

```bash
engrt capability plan github/repo-pr-merge-when-ready \
  --input organization=<organization> --input repository=<repository> \
  --input pull_request=12 --input head_sha=<40-character sha>
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
  pull_request:
    description: Pull request number
    required: true
  head_sha:
    description: Full 40-character SHA of the reviewed head commit
    required: true

workflow:
  - id: pr_observe
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $number: Int!) { repository(owner: $owner, name: $name) { pullRequest(number: $number) { state merged headRefOid } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "number:=${pull_request}"
    outputs:
      state: {pointer: /repository/pullRequest/state, type: string}
      head: {pointer: /repository/pullRequest/headRefOid, type: string}

  # ==== Gates: run only while the pull request is open; each stops the run before the merge ====
  - id: head_gate
    needs: [pr_observe]
    when: [{ref: steps.pr_observe.outputs.state, equals: OPEN}]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $number: Int!) { repository(owner: $owner, name: $name) { pullRequest(number: $number) { state isDraft headRefOid mergeStateStatus baseRefName } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "number:=${pull_request}"
    outputs:
      state: {pointer: /repository/pullRequest/state, type: string}
      draft: {pointer: /repository/pullRequest/isDraft, type: boolean}
      head: {pointer: /repository/pullRequest/headRefOid, type: string}
      merge_state: {pointer: /repository/pullRequest/mergeStateStatus, type: string}
      base: {pointer: /repository/pullRequest/baseRefName, type: string}
    expect:
      - {ref: steps.head_gate.outputs.state, equals: OPEN}
      - {ref: steps.head_gate.outputs.draft, equals: "false"}
      - {ref: steps.head_gate.outputs.head, equals: "${head_sha}"}
      - {ref: steps.head_gate.outputs.merge_state, equals: CLEAN}

  - id: checks_gate
    needs: [pr_observe]
    when: [{ref: steps.pr_observe.outputs.state, equals: OPEN}]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $oid: GitObjectID!) { repository(owner: $owner, name: $name) { object(oid: $oid) { ... on Commit { oid statusCheckRollup { state } } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "oid=${head_sha}"
    outputs:
      commit: {pointer: /repository/object/oid, type: string, optional: true}
      state: {pointer: /repository/object/statusCheckRollup/state, type: string, optional: true}
    expect:
      - {ref: steps.checks_gate.outputs.commit, equals: "${head_sha}"}
      - {ref: steps.checks_gate.outputs.state, equals: SUCCESS}

  - id: build_gate
    needs: [pr_observe]
    when: [{ref: steps.pr_observe.outputs.state, equals: OPEN}]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/commits/${head_sha}/check-runs", "check_name=build", "app_id=15368", "filter=latest", "per_page=1"]
    outputs:
      conclusion: {pointer: /check_runs/0/conclusion, type: string, optional: true}
      app: {pointer: /check_runs/0/app/id, type: integer, optional: true}
    expect:
      - {ref: steps.build_gate.outputs.conclusion, equals: success}
      - {ref: steps.build_gate.outputs.app, equals: "15368"}

  # ==== Merge: GitHub refuses it (409) if the head is no longer head_sha ====
  - id: merge
    needs: [pr_observe, head_gate, checks_gate, build_gate]
    when: [{ref: steps.pr_observe.outputs.state, equals: OPEN}]
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/pulls/${pull_request}/merge", "merge_method=squash", "sha=${head_sha}"]

  - id: merge_verify
    needs: [merge]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $number: Int!) { repository(owner: $owner, name: $name) { pullRequest(number: $number) { merged headRefOid mergeCommit { oid } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "number:=${pull_request}"
    outputs:
      merged: {pointer: /repository/pullRequest/merged, type: boolean}
      head: {pointer: /repository/pullRequest/headRefOid, type: string}
      merge_commit: {pointer: /repository/pullRequest/mergeCommit/oid, type: string, optional: true}
    expect:
      - {ref: steps.merge_verify.outputs.merged, equals: "true"}
      - {ref: steps.merge_verify.outputs.head, equals: "${head_sha}"}
```
