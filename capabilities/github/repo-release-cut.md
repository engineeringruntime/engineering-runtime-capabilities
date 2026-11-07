# Cut a release of one verified commit: green, on the branch, unblocked, free of serious vulnerabilities

> **Mutating.** It creates a published GitHub release and, when needed, its
> tag. Run `plan` first. Execute only when a person has asked for that exact
> version and commit.

The release is of **one named commit** (`commit`, a full 40-character SHA),
not "whatever the branch head is when the run gets there". Five gates run
first, and **each one stops the run before anything is written**:

| Gate | Passes when | Read |
|---|---|---|
| `commit_gate` | `commit` exists and its combined check state is `SUCCESS`: no check failed or is pending (no checks at all also stops the run) | GraphQL `object(oid:)`, `statusCheckRollup` |
| `build_gate` | `commit` has a successful `build` check from GitHub Actions (app 15368) | REST `commits/<commit>/check-runs` |
| `branch_gate` | `commit` is on `branch`: the branch contains it (compare `behind_by` is 0) | REST `compare/<commit>...<branch>` |
| `blockers_gate` | no open issue and no open pull request carries the `release-blocker` label | GraphQL counts |
| `vulnerability_gate` | no open Dependabot alert of severity `critical` or `high` | REST `dependabot/alerts` |

Then the tag and release are checked together, and the release is created
only where that cannot attach it to another commit:

| State of `version` | Action |
|---|---|
| no release, no tag | release created; GitHub creates the tag on `commit` (`target_commitish` is the SHA) |
| no release, a lightweight tag on `commit` | release created on the existing tag |
| no release, a tag on another commit, or an annotated tag | **nothing written**; `release_verify` fails. GitHub ignores `target_commitish` when the tag exists, so creating the release would publish the other commit |
| a release whose tag is on `commit` | nothing written (`SATISFIED`) |
| a release whose tag is on another commit | nothing written; `release_verify` fails |

`release_verify` always proves the end state: the release exists, is not a
draft, and its tag is a lightweight tag on exactly `commit`.

| Run | Result |
|---|---|
| gates pass, version new | release created and verified (`APPLIED`) |
| rerun after success | nothing written (`SATISFIED`) |
| CI red, pending or absent on `commit` | stops at `commit_gate`; nothing written |
| `commit` green only from another app's check (no `build` run) | stops at `build_gate`; nothing written |
| `commit` not on `branch` | stops at `branch_gate`; nothing written |
| an open `release-blocker` | stops at `blockers_gate`; nothing written |
| Dependabot alerts disabled on the repository | stops at `vulnerability_gate` (GitHub answers 403): a repository that cannot see its vulnerabilities is not released |

## What it needs

- Policy: the GitHub provider with `api GET` and `api POST`; no binaries, no
  file roots.
- Credential: Contents read/write and Dependabot alerts read on the
  repository (classic token: `repo`; reading Dependabot alerts also needs
  `security_events` on some token types).
- The repository should protect `v*` tags, as
  [java-springboot-service-onboard](java-springboot-service-onboard.md) does,
  so a release tag can never be moved or deleted afterwards.

## Known limits

- `commit` must be the full 40-character SHA. `commit_gate` compares the
  object GitHub returns with it, so a short SHA fails the gate.
- The required check is `build` from GitHub Actions, the standard
  `java-springboot-service-onboard` writes. A repository with another
  required check name fails `build_gate`.
- Only lightweight tags are accepted. An existing annotated `version` tag fails
  `release_verify`; GitHub's release API creates lightweight tags.
- The gates read the current state on every run, also when the release
  already exists; a later red build stops a rerun at `commit_gate`.
- `version` is used verbatim as tag and release name and must not look like a
  number or boolean (`key=value` arguments become JSON numbers and booleans).
  Use `vMAJOR.MINOR.PATCH`.
- The release is published immediately and marked Latest
  (`make_latest` is sent as the JSON string `"true"`, the type the API
  defines). For a staged rollout, cut a pre-release by hand.

## Run it

```bash
engrt capability plan github/repo-release-cut \
  --input organization=<organization> --input repository=<repository> \
  --input branch=main --input commit=<40-character sha> --input version=v0.1.0
```

```runtime
version: v1
capability_version: "2.1.0"
engrt_version: ">=0.13.0"

inputs:
  organization:
    description: GitHub organization that owns the repository
    required: true
  repository:
    description: Repository name without the owner
    required: true
  branch:
    description: Branch the release comes from, normally the default branch (main); must contain commit
    required: true
  commit:
    description: Full 40-character SHA of the commit to release
    required: true
  version:
    description: Release tag and name, e.g. v0.1.0
    required: true

workflow:
  # ==== Gates: each verification stops the run before anything is written ====
  - id: commit_gate
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $oid: GitObjectID!) { repository(owner: $owner, name: $name) { object(oid: $oid) { ... on Commit { oid statusCheckRollup { state } } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "oid=${commit}"
    outputs:
      commit: {pointer: /repository/object/oid, type: string, optional: true}
      state: {pointer: /repository/object/statusCheckRollup/state, type: string, optional: true}
    expect:
      - {ref: steps.commit_gate.outputs.commit, equals: "${commit}"}
      - {ref: steps.commit_gate.outputs.state, equals: SUCCESS}

  # The combined state alone is not enough: other apps post checks too (for
  # example Dependabot's dependabot.yml validation), and a commit whose only
  # check is one of those reads SUCCESS without ever being built. The commit
  # must carry a successful `build` check from GitHub Actions (app 15368), the
  # required check java-springboot-service-onboard puts in the ruleset.
  - id: build_gate
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/commits/${commit}/check-runs", "check_name=build", "app_id=15368", "filter=latest", "per_page=1"]
    outputs:
      conclusion: {pointer: /check_runs/0/conclusion, type: string, optional: true}
      app: {pointer: /check_runs/0/app/id, type: integer, optional: true}
    expect:
      - {ref: steps.build_gate.outputs.conclusion, equals: success}
      - {ref: steps.build_gate.outputs.app, equals: "15368"}

  - id: branch_gate
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/compare/${commit}...${branch}"]
    outputs:
      behind_by: {pointer: /behind_by, type: integer}
      status: {pointer: /status, type: string}
    expect:
      - {ref: steps.branch_gate.outputs.behind_by, equals: "0"}

  - id: blockers_gate
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $label: String!) { repository(owner: $owner, name: $name) { pullRequests(states: OPEN, labels: [$label]) { totalCount } issues(states: OPEN, labels: [$label]) { totalCount } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "label=release-blocker"
    outputs:
      pull_requests: {pointer: /repository/pullRequests/totalCount, type: integer}
      issues: {pointer: /repository/issues/totalCount, type: integer}
    expect:
      - {ref: steps.blockers_gate.outputs.pull_requests, equals: "0"}
      - {ref: steps.blockers_gate.outputs.issues, equals: "0"}

  - id: vulnerability_gate
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/dependabot/alerts", "state=open", "severity=critical,high", "per_page=1"]
    outputs:
      first_alert: {pointer: /0/number, type: integer, optional: true}
    expect:
      - {ref: steps.vulnerability_gate.outputs.first_alert, missing: true}

  # ==== Release and tag, read together ====
  - id: release_observe
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $tag: String!, $ref: String!) { repository(owner: $owner, name: $name) { release(tagName: $tag) { tagName isDraft } ref(qualifiedName: $ref) { target { __typename oid } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "tag=${version}"
      - "ref=refs/tags/${version}"
    outputs:
      release: {pointer: /repository/release/tagName, type: string, optional: true}
      tag_type: {pointer: /repository/ref/target/__typename, type: string, optional: true}
      tag_commit: {pointer: /repository/ref/target/oid, type: string, optional: true}

  # No tag yet: GitHub creates it on the verified commit.
  - id: release_create
    needs: [release_observe]
    when:
      - {ref: steps.release_observe.outputs.release, missing: true}
      - {ref: steps.release_observe.outputs.tag_commit, missing: true}
    provider: github
    args:
      - api
      - POST
      - "/repos/${organization}/${repository}/releases"
      - "tag_name=${version}"
      - "target_commitish=${commit}"
      - "name=${version}"
      - "generate_release_notes:=true"
      - "draft:=false"
      - "prerelease:=false"
      - 'make_latest:="true"'

  # A lightweight tag already on the verified commit: release it as it is.
  - id: release_create_on_tag
    needs: [release_observe]
    when:
      - {ref: steps.release_observe.outputs.release, missing: true}
      - {ref: steps.release_observe.outputs.tag_type, equals: Commit}
      - {ref: steps.release_observe.outputs.tag_commit, equals: "${commit}"}
    provider: github
    args:
      - api
      - POST
      - "/repos/${organization}/${repository}/releases"
      - "tag_name=${version}"
      - "name=${version}"
      - "generate_release_notes:=true"
      - "draft:=false"
      - "prerelease:=false"
      - 'make_latest:="true"'

  - id: release_verify
    needs: [release_create, release_create_on_tag]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $tag: String!, $ref: String!) { repository(owner: $owner, name: $name) { release(tagName: $tag) { tagName isDraft url } ref(qualifiedName: $ref) { target { __typename oid } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "tag=${version}"
      - "ref=refs/tags/${version}"
    outputs:
      release: {pointer: /repository/release/tagName, type: string, optional: true}
      draft: {pointer: /repository/release/isDraft, type: boolean, optional: true}
      url: {pointer: /repository/release/url, type: string, optional: true}
      tag_type: {pointer: /repository/ref/target/__typename, type: string, optional: true}
      tag_commit: {pointer: /repository/ref/target/oid, type: string, optional: true}
    expect:
      - {ref: steps.release_verify.outputs.release, equals: "${version}"}
      - {ref: steps.release_verify.outputs.draft, equals: "false"}
      - {ref: steps.release_verify.outputs.tag_type, equals: Commit}
      - {ref: steps.release_verify.outputs.tag_commit, equals: "${commit}"}
```
