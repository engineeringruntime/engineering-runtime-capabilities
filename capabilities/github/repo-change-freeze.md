# Freeze merges to the default branch during an incident

> **Mutating.** It stops every merge and push to the default branch except an
> organization owner's pull request. Run `plan` first. Execute only when an
> incident commander has asked for the freeze.

Incident response, in one governed run:

1. `layout_gate` checks the repository's rulesets **before anything is
   written** (see "Which repositories").
2. Ruleset `engrt-z-change-freeze` blocks every update to the default branch.
   The only bypass is an **organization owner merging through a pull
   request**, so an emergency fix still has a reviewed, audited path. The
   freeze comes first because it is the point of the run; nothing else is
   written if it cannot be applied and verified.
3. Labels `incident` and `change-freeze` exist (created when absent).
4. One open incident issue, labelled `incident` and `change-freeze`, records
   the freeze, with the summary and how to lift it.

Lift it with [repo-change-freeze-lift](repo-change-freeze-lift.md). The freeze
ruleset is **disabled, not deleted** when lifted (policy denies `api DELETE`),
so it stays as a record and the next freeze reactivates it.

| Run | Result |
|---|---|
| first freeze | labels, ruleset and issue created (`APPLIED`) |
| freeze already active | nothing written (`SATISFIED`) |
| freeze lifted earlier | the disabled ruleset is reactivated; a new incident issue is opened |
| repository not onboarded the standard way | stops at `layout_gate`; nothing written (no ruleset, label or issue) |
| a third ruleset that is not `engrt-z-change-freeze` | stops at `freeze_verify`; no label or issue is written |

## Which repositories

It expects the repository's own rulesets to be the two that
[java-springboot-service-onboard](java-springboot-service-onboard.md) creates
(`engrt-onboard-default-branch`, `engrt-onboard-release-tags`), with
`engrt-z-change-freeze` as the third. GitHub lists a repository's rulesets
**sorted by name** (not creation order) and offers no
lookup by name. The freeze ruleset's `z-` makes it sort after the two
onboarding rulesets, so the layout stays the same whether it is active,
disabled or absent. The capability checks the
names of the first two, and that there are at most three, before it writes
anything. Any other layout stops the run at `layout_gate`.

## What it needs

- Policy: the GitHub provider with `api GET`, `POST` and `PUT`.
- Credential: repository Administration and Issues read/write.

## Run it

```bash
engrt capability plan github/repo-change-freeze \
  --input organization=<organization> --input repository=<repository> \
  --input "incident_title=INC-1042 payment authorisations failing" \
  --input "incident_summary=Error rate above 5% since 14:05 UTC after release v0.1.0."
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
  incident_title:
    description: Incident issue title, e.g. INC-1042 payment authorisations failing
    required: true
  incident_summary:
    description: One or two sentences on impact and start time
    required: true

workflow:
  # ==== Precondition: the onboarding ruleset layout, checked before any write ====
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
      fourth: {pointer: /repository/rulesets/nodes/3/name, type: string, optional: true}
    expect:
      - {ref: steps.layout_gate.outputs.first, equals: engrt-onboard-default-branch}
      - {ref: steps.layout_gate.outputs.second, equals: engrt-onboard-release-tags}
      - {ref: steps.layout_gate.outputs.fourth, missing: true}

  # ==== Freeze ruleset: create it, or reactivate the one a lift disabled ====
  - id: freeze_observe
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 4, includeParents: false) { totalCount nodes { databaseId name enforcement } } } }"
      - "owner=${organization}"
      - "name=${repository}"
    outputs:
      total: {pointer: /repository/rulesets/totalCount, type: integer}
      first: {pointer: /repository/rulesets/nodes/0/name, type: string, optional: true}
      second: {pointer: /repository/rulesets/nodes/1/name, type: string, optional: true}
      freeze: {pointer: /repository/rulesets/nodes/2/name, type: string, optional: true}
      freeze_id: {pointer: /repository/rulesets/nodes/2/databaseId, type: integer, optional: true}
      freeze_enforcement: {pointer: /repository/rulesets/nodes/2/enforcement, type: string, optional: true}

  - id: freeze_create
    needs: [freeze_observe]
    when:
      - {ref: steps.freeze_observe.outputs.total, equals: "2"}
      - {ref: steps.freeze_observe.outputs.first, equals: engrt-onboard-default-branch}
      - {ref: steps.freeze_observe.outputs.second, equals: engrt-onboard-release-tags}
    provider: github
    args:
      - api
      - POST
      - "/repos/${organization}/${repository}/rulesets"
      - "name=engrt-z-change-freeze"
      - "target=branch"
      - "enforcement=active"
      - 'bypass_actors:=[{"actor_id":1,"actor_type":"OrganizationAdmin","bypass_mode":"pull_request"}]'
      - 'conditions:={"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}}'
      - 'rules:=[{"type":"update"}]'

  - id: freeze_reactivate
    needs: [freeze_observe]
    when:
      - {ref: steps.freeze_observe.outputs.total, equals: "3"}
      - {ref: steps.freeze_observe.outputs.freeze, equals: engrt-z-change-freeze}
      - {ref: steps.freeze_observe.outputs.freeze_enforcement, not_equals: ACTIVE}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${steps.freeze_observe.outputs.freeze_id}", "enforcement=active"]

  - id: freeze_verify
    needs: [freeze_create, freeze_reactivate]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 4, includeParents: false) { totalCount nodes { name target enforcement } } } }"
      - "owner=${organization}"
      - "name=${repository}"
    outputs:
      total: {pointer: /repository/rulesets/totalCount, type: integer}
      name: {pointer: /repository/rulesets/nodes/2/name, type: string}
      target: {pointer: /repository/rulesets/nodes/2/target, type: string}
      enforcement: {pointer: /repository/rulesets/nodes/2/enforcement, type: string}
    expect:
      - {ref: steps.freeze_verify.outputs.total, equals: "3"}
      - {ref: steps.freeze_verify.outputs.name, equals: engrt-z-change-freeze}
      - {ref: steps.freeze_verify.outputs.target, equals: BRANCH}
      - {ref: steps.freeze_verify.outputs.enforcement, equals: ACTIVE}

  # ==== Labels ====
  - id: label_incident_observe
    provider: github
    args: [label, get, "${organization}/${repository}", incident]

  - id: label_incident_create
    needs: [label_incident_observe]
    when: [{ref: steps.label_incident_observe.observation, equals: ABSENT}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/labels", "name=incident", "color=b60205", "description=Production incident"]

  - id: label_incident_verify
    needs: [label_incident_create]
    provider: github
    args: [label, get, "${organization}/${repository}", incident]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.label_incident_verify.outputs.name, equals: incident}

  - id: label_freeze_observe
    provider: github
    args: [label, get, "${organization}/${repository}", change-freeze]

  - id: label_freeze_create
    needs: [label_freeze_observe]
    when: [{ref: steps.label_freeze_observe.observation, equals: ABSENT}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/labels", "name=change-freeze", "color=d93f0b", "description=Merges to the default branch are frozen"]

  - id: label_freeze_verify
    needs: [label_freeze_create]
    provider: github
    args: [label, get, "${organization}/${repository}", change-freeze]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.label_freeze_verify.outputs.name, equals: change-freeze}

  # ==== Incident record: one open issue per freeze ====
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

  - id: incident_create
    needs: [incident_observe]
    when: [{ref: steps.incident_observe.outputs.number, missing: true}]
    provider: github
    args:
      - api
      - POST
      - "/repos/${organization}/${repository}/issues"
      - "title=${incident_title}"
      - 'labels:=["incident","change-freeze"]'
      - |
        body=${incident_summary}

        **Change freeze is active.** Ruleset `engrt-z-change-freeze` blocks every
        update to the default branch. An organization owner can still merge an
        emergency fix through a pull request.

        Lift it with `engrt capability execute github/repo-change-freeze-lift`
        once the incident is resolved. Frozen by Engineering Runtime; the run is
        in the operator's Runtime audit log.

  - id: incident_verify
    needs: [incident_create]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { issues(labels: [\"change-freeze\"], states: OPEN, first: 1) { nodes { number url } } } }"
      - "owner=${organization}"
      - "name=${repository}"
    outputs:
      number: {pointer: /repository/issues/nodes/0/number, type: integer}
      url: {pointer: /repository/issues/nodes/0/url, type: string}
    expect:
      - {ref: steps.incident_verify.outputs.number, exists: true}
```
