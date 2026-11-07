# Lift an incident change freeze

> **Mutating.** It reopens the default branch for merges and closes the
> incident issue. Run `plan` first. Execute only when the incident commander
> has declared the incident resolved.

The counterpart of [repo-change-freeze](repo-change-freeze.md). `layout_gate`
first checks the rulesets are the two onboarding ones with
`engrt-z-change-freeze` third, and stops before any write otherwise. Then:

1. Ruleset `engrt-z-change-freeze` is set to `disabled`. It is **not deleted**:
   policy denies `api DELETE`, and the disabled ruleset stays as the record of
   the freeze. The next freeze reactivates it.
2. The open incident issue gets the resolution as a comment and is closed as
   completed.

| Run | Result |
|---|---|
| freeze active | ruleset disabled, issue commented and closed (`APPLIED`) |
| already lifted | nothing written (`SATISFIED`) |
| no `engrt-z-change-freeze` ruleset in third place, or another ruleset layout | stops at `layout_gate`; nothing is changed, the incident issue stays open |

## What it needs

- Policy: the GitHub provider with `api GET`, `POST`, `PUT` and `PATCH`.
- Credential: repository Administration and Issues read/write.

## Run it

```bash
engrt capability plan github/repo-change-freeze-lift \
  --input organization=<organization> --input repository=<repository> \
  --input "resolution=Rolled back to v0.1.0 at 14:40 UTC; error rate back to baseline."
```

```runtime
version: v1
capability_version: "1.3.0"
engrt_version: ">=0.13.0"

inputs:
  organization:
    description: GitHub organization that owns the repository
    required: true
  repository:
    description: Repository name without the owner
    required: true
  resolution:
    description: How the incident was resolved; posted on the incident issue before it is closed
    required: true

workflow:
  # ==== Precondition: the onboarding layout with the freeze third, before any write ====
  - id: layout_gate
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 4, includeParents: false) { totalCount nodes { name } } } }"
      - "owner=${organization}"
      - "name=${repository}"
    outputs:
      first: {pointer: /repository/rulesets/nodes/0/name, type: string, optional: true}
      second: {pointer: /repository/rulesets/nodes/1/name, type: string, optional: true}
      third: {pointer: /repository/rulesets/nodes/2/name, type: string, optional: true}
      fourth: {pointer: /repository/rulesets/nodes/3/name, type: string, optional: true}
    expect:
      - {ref: steps.layout_gate.outputs.first, equals: engrt-onboard-default-branch}
      - {ref: steps.layout_gate.outputs.second, equals: engrt-onboard-release-tags}
      - {ref: steps.layout_gate.outputs.third, equals: engrt-z-change-freeze}
      - {ref: steps.layout_gate.outputs.fourth, missing: true}

  # ==== Disable the freeze ruleset (never deleted) ====
  - id: lift_observe
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 4, includeParents: false) { totalCount nodes { databaseId name enforcement } } } }"
      - "owner=${organization}"
      - "name=${repository}"
    outputs:
      total: {pointer: /repository/rulesets/totalCount, type: integer}
      freeze: {pointer: /repository/rulesets/nodes/2/name, type: string, optional: true}
      freeze_id: {pointer: /repository/rulesets/nodes/2/databaseId, type: integer, optional: true}
      freeze_enforcement: {pointer: /repository/rulesets/nodes/2/enforcement, type: string, optional: true}

  - id: lift_disable
    needs: [lift_observe]
    when:
      - {ref: steps.lift_observe.outputs.total, equals: "3"}
      - {ref: steps.lift_observe.outputs.freeze, equals: engrt-z-change-freeze}
      - {ref: steps.lift_observe.outputs.freeze_enforcement, equals: ACTIVE}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${steps.lift_observe.outputs.freeze_id}", "enforcement=disabled"]

  - id: lift_verify
    needs: [lift_disable]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 4, includeParents: false) { nodes { name enforcement } } } }"
      - "owner=${organization}"
      - "name=${repository}"
    outputs:
      name: {pointer: /repository/rulesets/nodes/2/name, type: string}
      enforcement: {pointer: /repository/rulesets/nodes/2/enforcement, type: string}
    expect:
      - {ref: steps.lift_verify.outputs.name, equals: engrt-z-change-freeze}
      - {ref: steps.lift_verify.outputs.enforcement, equals: DISABLED}

  # ==== Close the incident record ====
  # Read through GraphQL: GitHub's REST issue list filtered by label lags a
  # write by more than a second in both directions (a new issue is missing, a
  # closed one still listed; reproduced 2026-11-06). GraphQL issues(labels:)
  # reflects the write immediately.
  - id: incident_observe
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { issues(labels: [\"change-freeze\"], states: OPEN, first: 1) { nodes { number url } } } }"
      - "owner=${organization}"
      - "name=${repository}"
    outputs:
      number: {pointer: /repository/issues/nodes/0/number, type: integer, optional: true}

  - id: incident_comment
    needs: [incident_observe]
    when: [{ref: steps.incident_observe.outputs.number, exists: true}]
    provider: github
    args:
      - api
      - POST
      - "/repos/${organization}/${repository}/issues/${steps.incident_observe.outputs.number}/comments"
      - |
        body=**Change freeze lifted.** ${resolution}

        Ruleset `engrt-z-change-freeze` is disabled (kept as the record of this
        freeze). Lifted by Engineering Runtime; the run is in the operator's
        Runtime audit log.

  - id: incident_close
    needs: [incident_observe]
    when: [{ref: steps.incident_observe.outputs.number, exists: true}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/issues/${steps.incident_observe.outputs.number}", "state=closed", "state_reason=completed"]

  - id: incident_verify
    needs: [incident_close]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { issues(labels: [\"change-freeze\"], states: OPEN, first: 1) { nodes { number url } } } }"
      - "owner=${organization}"
      - "name=${repository}"
    outputs:
      open_incident: {pointer: /repository/issues/nodes/0/number, type: integer, optional: true}
    expect:
      - {ref: steps.incident_verify.outputs.open_incident, missing: true}
```
