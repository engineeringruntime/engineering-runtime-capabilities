# Bring a repository's labels to a standard set

> **Mutating.** It creates missing labels and corrects the colour and
> description of existing ones. It never deletes or renames a label. Run
> `plan` first.

Every repository gets the same 12 labels, so triage, release gates and
reports mean the same thing everywhere. `repo-release-cut` gates on
`release-blocker`, `repo-change-freeze` uses `incident` and `change-freeze`,
and Dependabot opens its pull requests with `dependencies`; the colours and
descriptions here match those capabilities and Dependabot's own default, so
the two never fight.

| Label | Colour | Description |
|---|---|---|
| `bug` | `d73a4a` | Something isn't working |
| `enhancement` | `a2eeef` | New feature or request |
| `documentation` | `0075ca` | Improvements or additions to documentation |
| `dependencies` | `0366d6` | Pull requests that update a dependency file |
| `security` | `ee0701` | Security fix or hardening |
| `needs-triage` | `fbca04` | Not yet triaged |
| `release-blocker` | `e11d21` | Blocks the next release |
| `breaking-change` | `5319e7` | Changes a public interface |
| `priority-high` | `c2185b` | Needs attention before other work |
| `stale` | `ededed` | No activity for a while |
| `incident` | `b60205` | Production incident |
| `change-freeze` | `d93f0b` | Merges to the default branch are frozen |

For each label: read it, create it when absent, correct the colour or the
description when either differs, then read it back and verify. Colour and
description are separate logical operations (`<label>_verify` and
`<label>_description_verify`): Runtime allows one write per logical operation
and refuses a second as `conflict`, and both fields can drift at once.
Labels that are not in the standard are left alone.

| Run | Result |
|---|---|
| new repository | missing labels created (`APPLIED`) |
| rerun | every label read and verified, nothing written (`SATISFIED`) |
| a label recoloured or reworded by hand | corrected and verified |

## What it needs

- Policy: the GitHub provider with `label get`, `api POST` and `api PATCH`.
- Credential: Issues read/write on the repository.

## Known limits

- **Two writes for one label when both colour and description drifted.** The
  capability grammar has no OR, and
  Runtime allows one write per logical operation, so colour and description
  are separate operations that each send the full update. A rerun writes
  nothing.
- A label whose description was cleared reads as missing and is repaired by
  `add_description`, because `not_equals` does not match a missing value.
- Colours are sent as JSON strings (`color:="..."`): a plain `color=000000`
  would arrive as the number 0.
- Every repository in the organization: run it once per repository from a
  script.

## Run it

```bash
engrt capability plan github/repo-labels-standard-sync \
  --input organization=<organization> --input repository=<repository>
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

workflow:
  # ---- bug ----
  - id: bug_observe
    provider: github
    args: [label, get, "${organization}/${repository}", bug]
    outputs:
      color: {pointer: /color, type: string, optional: true}
      description: {pointer: /description, type: string, optional: true}

  - id: bug_create
    needs: [bug_observe]
    when: [{ref: steps.bug_observe.observation, equals: ABSENT}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/labels", "name=bug", 'color:="d73a4a"', "description=Something isn't working"]

  - id: bug_fix_color
    needs: [bug_observe]
    when: [{ref: steps.bug_observe.outputs.color, not_equals: "d73a4a"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/bug", 'color:="d73a4a"', "description=Something isn't working"]

  - id: bug_fix_description
    needs: [bug_observe]
    when: [{ref: steps.bug_observe.outputs.description, not_equals: "Something isn't working"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/bug", 'color:="d73a4a"', "description=Something isn't working"]

  - id: bug_add_description
    needs: [bug_observe]
    when:
      - {ref: steps.bug_observe.observation, equals: PRESENT}
      - {ref: steps.bug_observe.outputs.description, missing: true}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/bug", 'color:="d73a4a"', "description=Something isn't working"]

  # Two logical operations per label: Runtime allows one write per operation,
  # and colour and description can drift together.
  - id: bug_verify
    needs: [bug_create, bug_fix_color]
    provider: github
    args: [label, get, "${organization}/${repository}", bug]
    outputs:
      name: {pointer: /name, type: string}
      color: {pointer: /color, type: string}
    expect:
      - {ref: steps.bug_verify.outputs.name, equals: bug}
      - {ref: steps.bug_verify.outputs.color, equals: "d73a4a"}

  - id: bug_description_verify
    needs: [bug_fix_description, bug_add_description]
    provider: github
    args: [label, get, "${organization}/${repository}", bug]
    outputs:
      description: {pointer: /description, type: string, optional: true}
    expect:
      - {ref: steps.bug_description_verify.outputs.description, equals: "Something isn't working"}

  # ---- enhancement ----
  - id: enhancement_observe
    provider: github
    args: [label, get, "${organization}/${repository}", enhancement]
    outputs:
      color: {pointer: /color, type: string, optional: true}
      description: {pointer: /description, type: string, optional: true}

  - id: enhancement_create
    needs: [enhancement_observe]
    when: [{ref: steps.enhancement_observe.observation, equals: ABSENT}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/labels", "name=enhancement", 'color:="a2eeef"', "description=New feature or request"]

  - id: enhancement_fix_color
    needs: [enhancement_observe]
    when: [{ref: steps.enhancement_observe.outputs.color, not_equals: "a2eeef"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/enhancement", 'color:="a2eeef"', "description=New feature or request"]

  - id: enhancement_fix_description
    needs: [enhancement_observe]
    when: [{ref: steps.enhancement_observe.outputs.description, not_equals: "New feature or request"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/enhancement", 'color:="a2eeef"', "description=New feature or request"]

  - id: enhancement_add_description
    needs: [enhancement_observe]
    when:
      - {ref: steps.enhancement_observe.observation, equals: PRESENT}
      - {ref: steps.enhancement_observe.outputs.description, missing: true}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/enhancement", 'color:="a2eeef"', "description=New feature or request"]

  # Two logical operations per label: Runtime allows one write per operation,
  # and colour and description can drift together.
  - id: enhancement_verify
    needs: [enhancement_create, enhancement_fix_color]
    provider: github
    args: [label, get, "${organization}/${repository}", enhancement]
    outputs:
      name: {pointer: /name, type: string}
      color: {pointer: /color, type: string}
    expect:
      - {ref: steps.enhancement_verify.outputs.name, equals: enhancement}
      - {ref: steps.enhancement_verify.outputs.color, equals: "a2eeef"}

  - id: enhancement_description_verify
    needs: [enhancement_fix_description, enhancement_add_description]
    provider: github
    args: [label, get, "${organization}/${repository}", enhancement]
    outputs:
      description: {pointer: /description, type: string, optional: true}
    expect:
      - {ref: steps.enhancement_description_verify.outputs.description, equals: "New feature or request"}

  # ---- documentation ----
  - id: documentation_observe
    provider: github
    args: [label, get, "${organization}/${repository}", documentation]
    outputs:
      color: {pointer: /color, type: string, optional: true}
      description: {pointer: /description, type: string, optional: true}

  - id: documentation_create
    needs: [documentation_observe]
    when: [{ref: steps.documentation_observe.observation, equals: ABSENT}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/labels", "name=documentation", 'color:="0075ca"', "description=Improvements or additions to documentation"]

  - id: documentation_fix_color
    needs: [documentation_observe]
    when: [{ref: steps.documentation_observe.outputs.color, not_equals: "0075ca"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/documentation", 'color:="0075ca"', "description=Improvements or additions to documentation"]

  - id: documentation_fix_description
    needs: [documentation_observe]
    when: [{ref: steps.documentation_observe.outputs.description, not_equals: "Improvements or additions to documentation"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/documentation", 'color:="0075ca"', "description=Improvements or additions to documentation"]

  - id: documentation_add_description
    needs: [documentation_observe]
    when:
      - {ref: steps.documentation_observe.observation, equals: PRESENT}
      - {ref: steps.documentation_observe.outputs.description, missing: true}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/documentation", 'color:="0075ca"', "description=Improvements or additions to documentation"]

  # Two logical operations per label: Runtime allows one write per operation,
  # and colour and description can drift together.
  - id: documentation_verify
    needs: [documentation_create, documentation_fix_color]
    provider: github
    args: [label, get, "${organization}/${repository}", documentation]
    outputs:
      name: {pointer: /name, type: string}
      color: {pointer: /color, type: string}
    expect:
      - {ref: steps.documentation_verify.outputs.name, equals: documentation}
      - {ref: steps.documentation_verify.outputs.color, equals: "0075ca"}

  - id: documentation_description_verify
    needs: [documentation_fix_description, documentation_add_description]
    provider: github
    args: [label, get, "${organization}/${repository}", documentation]
    outputs:
      description: {pointer: /description, type: string, optional: true}
    expect:
      - {ref: steps.documentation_description_verify.outputs.description, equals: "Improvements or additions to documentation"}

  # ---- dependencies ----
  - id: dependencies_observe
    provider: github
    args: [label, get, "${organization}/${repository}", dependencies]
    outputs:
      color: {pointer: /color, type: string, optional: true}
      description: {pointer: /description, type: string, optional: true}

  - id: dependencies_create
    needs: [dependencies_observe]
    when: [{ref: steps.dependencies_observe.observation, equals: ABSENT}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/labels", "name=dependencies", 'color:="0366d6"', "description=Pull requests that update a dependency file"]

  - id: dependencies_fix_color
    needs: [dependencies_observe]
    when: [{ref: steps.dependencies_observe.outputs.color, not_equals: "0366d6"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/dependencies", 'color:="0366d6"', "description=Pull requests that update a dependency file"]

  - id: dependencies_fix_description
    needs: [dependencies_observe]
    when: [{ref: steps.dependencies_observe.outputs.description, not_equals: "Pull requests that update a dependency file"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/dependencies", 'color:="0366d6"', "description=Pull requests that update a dependency file"]

  - id: dependencies_add_description
    needs: [dependencies_observe]
    when:
      - {ref: steps.dependencies_observe.observation, equals: PRESENT}
      - {ref: steps.dependencies_observe.outputs.description, missing: true}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/dependencies", 'color:="0366d6"', "description=Pull requests that update a dependency file"]

  # Two logical operations per label: Runtime allows one write per operation,
  # and colour and description can drift together.
  - id: dependencies_verify
    needs: [dependencies_create, dependencies_fix_color]
    provider: github
    args: [label, get, "${organization}/${repository}", dependencies]
    outputs:
      name: {pointer: /name, type: string}
      color: {pointer: /color, type: string}
    expect:
      - {ref: steps.dependencies_verify.outputs.name, equals: dependencies}
      - {ref: steps.dependencies_verify.outputs.color, equals: "0366d6"}

  - id: dependencies_description_verify
    needs: [dependencies_fix_description, dependencies_add_description]
    provider: github
    args: [label, get, "${organization}/${repository}", dependencies]
    outputs:
      description: {pointer: /description, type: string, optional: true}
    expect:
      - {ref: steps.dependencies_description_verify.outputs.description, equals: "Pull requests that update a dependency file"}

  # ---- security ----
  - id: security_observe
    provider: github
    args: [label, get, "${organization}/${repository}", security]
    outputs:
      color: {pointer: /color, type: string, optional: true}
      description: {pointer: /description, type: string, optional: true}

  - id: security_create
    needs: [security_observe]
    when: [{ref: steps.security_observe.observation, equals: ABSENT}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/labels", "name=security", 'color:="ee0701"', "description=Security fix or hardening"]

  - id: security_fix_color
    needs: [security_observe]
    when: [{ref: steps.security_observe.outputs.color, not_equals: "ee0701"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/security", 'color:="ee0701"', "description=Security fix or hardening"]

  - id: security_fix_description
    needs: [security_observe]
    when: [{ref: steps.security_observe.outputs.description, not_equals: "Security fix or hardening"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/security", 'color:="ee0701"', "description=Security fix or hardening"]

  - id: security_add_description
    needs: [security_observe]
    when:
      - {ref: steps.security_observe.observation, equals: PRESENT}
      - {ref: steps.security_observe.outputs.description, missing: true}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/security", 'color:="ee0701"', "description=Security fix or hardening"]

  # Two logical operations per label: Runtime allows one write per operation,
  # and colour and description can drift together.
  - id: security_verify
    needs: [security_create, security_fix_color]
    provider: github
    args: [label, get, "${organization}/${repository}", security]
    outputs:
      name: {pointer: /name, type: string}
      color: {pointer: /color, type: string}
    expect:
      - {ref: steps.security_verify.outputs.name, equals: security}
      - {ref: steps.security_verify.outputs.color, equals: "ee0701"}

  - id: security_description_verify
    needs: [security_fix_description, security_add_description]
    provider: github
    args: [label, get, "${organization}/${repository}", security]
    outputs:
      description: {pointer: /description, type: string, optional: true}
    expect:
      - {ref: steps.security_description_verify.outputs.description, equals: "Security fix or hardening"}

  # ---- needs-triage ----
  - id: needs_triage_observe
    provider: github
    args: [label, get, "${organization}/${repository}", needs-triage]
    outputs:
      color: {pointer: /color, type: string, optional: true}
      description: {pointer: /description, type: string, optional: true}

  - id: needs_triage_create
    needs: [needs_triage_observe]
    when: [{ref: steps.needs_triage_observe.observation, equals: ABSENT}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/labels", "name=needs-triage", 'color:="fbca04"', "description=Not yet triaged"]

  - id: needs_triage_fix_color
    needs: [needs_triage_observe]
    when: [{ref: steps.needs_triage_observe.outputs.color, not_equals: "fbca04"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/needs-triage", 'color:="fbca04"', "description=Not yet triaged"]

  - id: needs_triage_fix_description
    needs: [needs_triage_observe]
    when: [{ref: steps.needs_triage_observe.outputs.description, not_equals: "Not yet triaged"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/needs-triage", 'color:="fbca04"', "description=Not yet triaged"]

  - id: needs_triage_add_description
    needs: [needs_triage_observe]
    when:
      - {ref: steps.needs_triage_observe.observation, equals: PRESENT}
      - {ref: steps.needs_triage_observe.outputs.description, missing: true}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/needs-triage", 'color:="fbca04"', "description=Not yet triaged"]

  # Two logical operations per label: Runtime allows one write per operation,
  # and colour and description can drift together.
  - id: needs_triage_verify
    needs: [needs_triage_create, needs_triage_fix_color]
    provider: github
    args: [label, get, "${organization}/${repository}", needs-triage]
    outputs:
      name: {pointer: /name, type: string}
      color: {pointer: /color, type: string}
    expect:
      - {ref: steps.needs_triage_verify.outputs.name, equals: needs-triage}
      - {ref: steps.needs_triage_verify.outputs.color, equals: "fbca04"}

  - id: needs_triage_description_verify
    needs: [needs_triage_fix_description, needs_triage_add_description]
    provider: github
    args: [label, get, "${organization}/${repository}", needs-triage]
    outputs:
      description: {pointer: /description, type: string, optional: true}
    expect:
      - {ref: steps.needs_triage_description_verify.outputs.description, equals: "Not yet triaged"}

  # ---- release-blocker ----
  - id: release_blocker_observe
    provider: github
    args: [label, get, "${organization}/${repository}", release-blocker]
    outputs:
      color: {pointer: /color, type: string, optional: true}
      description: {pointer: /description, type: string, optional: true}

  - id: release_blocker_create
    needs: [release_blocker_observe]
    when: [{ref: steps.release_blocker_observe.observation, equals: ABSENT}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/labels", "name=release-blocker", 'color:="e11d21"', "description=Blocks the next release"]

  - id: release_blocker_fix_color
    needs: [release_blocker_observe]
    when: [{ref: steps.release_blocker_observe.outputs.color, not_equals: "e11d21"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/release-blocker", 'color:="e11d21"', "description=Blocks the next release"]

  - id: release_blocker_fix_description
    needs: [release_blocker_observe]
    when: [{ref: steps.release_blocker_observe.outputs.description, not_equals: "Blocks the next release"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/release-blocker", 'color:="e11d21"', "description=Blocks the next release"]

  - id: release_blocker_add_description
    needs: [release_blocker_observe]
    when:
      - {ref: steps.release_blocker_observe.observation, equals: PRESENT}
      - {ref: steps.release_blocker_observe.outputs.description, missing: true}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/release-blocker", 'color:="e11d21"', "description=Blocks the next release"]

  # Two logical operations per label: Runtime allows one write per operation,
  # and colour and description can drift together.
  - id: release_blocker_verify
    needs: [release_blocker_create, release_blocker_fix_color]
    provider: github
    args: [label, get, "${organization}/${repository}", release-blocker]
    outputs:
      name: {pointer: /name, type: string}
      color: {pointer: /color, type: string}
    expect:
      - {ref: steps.release_blocker_verify.outputs.name, equals: release-blocker}
      - {ref: steps.release_blocker_verify.outputs.color, equals: "e11d21"}

  - id: release_blocker_description_verify
    needs: [release_blocker_fix_description, release_blocker_add_description]
    provider: github
    args: [label, get, "${organization}/${repository}", release-blocker]
    outputs:
      description: {pointer: /description, type: string, optional: true}
    expect:
      - {ref: steps.release_blocker_description_verify.outputs.description, equals: "Blocks the next release"}

  # ---- breaking-change ----
  - id: breaking_change_observe
    provider: github
    args: [label, get, "${organization}/${repository}", breaking-change]
    outputs:
      color: {pointer: /color, type: string, optional: true}
      description: {pointer: /description, type: string, optional: true}

  - id: breaking_change_create
    needs: [breaking_change_observe]
    when: [{ref: steps.breaking_change_observe.observation, equals: ABSENT}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/labels", "name=breaking-change", 'color:="5319e7"', "description=Changes a public interface"]

  - id: breaking_change_fix_color
    needs: [breaking_change_observe]
    when: [{ref: steps.breaking_change_observe.outputs.color, not_equals: "5319e7"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/breaking-change", 'color:="5319e7"', "description=Changes a public interface"]

  - id: breaking_change_fix_description
    needs: [breaking_change_observe]
    when: [{ref: steps.breaking_change_observe.outputs.description, not_equals: "Changes a public interface"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/breaking-change", 'color:="5319e7"', "description=Changes a public interface"]

  - id: breaking_change_add_description
    needs: [breaking_change_observe]
    when:
      - {ref: steps.breaking_change_observe.observation, equals: PRESENT}
      - {ref: steps.breaking_change_observe.outputs.description, missing: true}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/breaking-change", 'color:="5319e7"', "description=Changes a public interface"]

  # Two logical operations per label: Runtime allows one write per operation,
  # and colour and description can drift together.
  - id: breaking_change_verify
    needs: [breaking_change_create, breaking_change_fix_color]
    provider: github
    args: [label, get, "${organization}/${repository}", breaking-change]
    outputs:
      name: {pointer: /name, type: string}
      color: {pointer: /color, type: string}
    expect:
      - {ref: steps.breaking_change_verify.outputs.name, equals: breaking-change}
      - {ref: steps.breaking_change_verify.outputs.color, equals: "5319e7"}

  - id: breaking_change_description_verify
    needs: [breaking_change_fix_description, breaking_change_add_description]
    provider: github
    args: [label, get, "${organization}/${repository}", breaking-change]
    outputs:
      description: {pointer: /description, type: string, optional: true}
    expect:
      - {ref: steps.breaking_change_description_verify.outputs.description, equals: "Changes a public interface"}

  # ---- priority-high ----
  - id: priority_high_observe
    provider: github
    args: [label, get, "${organization}/${repository}", priority-high]
    outputs:
      color: {pointer: /color, type: string, optional: true}
      description: {pointer: /description, type: string, optional: true}

  - id: priority_high_create
    needs: [priority_high_observe]
    when: [{ref: steps.priority_high_observe.observation, equals: ABSENT}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/labels", "name=priority-high", 'color:="c2185b"', "description=Needs attention before other work"]

  - id: priority_high_fix_color
    needs: [priority_high_observe]
    when: [{ref: steps.priority_high_observe.outputs.color, not_equals: "c2185b"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/priority-high", 'color:="c2185b"', "description=Needs attention before other work"]

  - id: priority_high_fix_description
    needs: [priority_high_observe]
    when: [{ref: steps.priority_high_observe.outputs.description, not_equals: "Needs attention before other work"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/priority-high", 'color:="c2185b"', "description=Needs attention before other work"]

  - id: priority_high_add_description
    needs: [priority_high_observe]
    when:
      - {ref: steps.priority_high_observe.observation, equals: PRESENT}
      - {ref: steps.priority_high_observe.outputs.description, missing: true}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/priority-high", 'color:="c2185b"', "description=Needs attention before other work"]

  # Two logical operations per label: Runtime allows one write per operation,
  # and colour and description can drift together.
  - id: priority_high_verify
    needs: [priority_high_create, priority_high_fix_color]
    provider: github
    args: [label, get, "${organization}/${repository}", priority-high]
    outputs:
      name: {pointer: /name, type: string}
      color: {pointer: /color, type: string}
    expect:
      - {ref: steps.priority_high_verify.outputs.name, equals: priority-high}
      - {ref: steps.priority_high_verify.outputs.color, equals: "c2185b"}

  - id: priority_high_description_verify
    needs: [priority_high_fix_description, priority_high_add_description]
    provider: github
    args: [label, get, "${organization}/${repository}", priority-high]
    outputs:
      description: {pointer: /description, type: string, optional: true}
    expect:
      - {ref: steps.priority_high_description_verify.outputs.description, equals: "Needs attention before other work"}

  # ---- stale ----
  - id: stale_observe
    provider: github
    args: [label, get, "${organization}/${repository}", stale]
    outputs:
      color: {pointer: /color, type: string, optional: true}
      description: {pointer: /description, type: string, optional: true}

  - id: stale_create
    needs: [stale_observe]
    when: [{ref: steps.stale_observe.observation, equals: ABSENT}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/labels", "name=stale", 'color:="ededed"', "description=No activity for a while"]

  - id: stale_fix_color
    needs: [stale_observe]
    when: [{ref: steps.stale_observe.outputs.color, not_equals: "ededed"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/stale", 'color:="ededed"', "description=No activity for a while"]

  - id: stale_fix_description
    needs: [stale_observe]
    when: [{ref: steps.stale_observe.outputs.description, not_equals: "No activity for a while"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/stale", 'color:="ededed"', "description=No activity for a while"]

  - id: stale_add_description
    needs: [stale_observe]
    when:
      - {ref: steps.stale_observe.observation, equals: PRESENT}
      - {ref: steps.stale_observe.outputs.description, missing: true}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/stale", 'color:="ededed"', "description=No activity for a while"]

  # Two logical operations per label: Runtime allows one write per operation,
  # and colour and description can drift together.
  - id: stale_verify
    needs: [stale_create, stale_fix_color]
    provider: github
    args: [label, get, "${organization}/${repository}", stale]
    outputs:
      name: {pointer: /name, type: string}
      color: {pointer: /color, type: string}
    expect:
      - {ref: steps.stale_verify.outputs.name, equals: stale}
      - {ref: steps.stale_verify.outputs.color, equals: "ededed"}

  - id: stale_description_verify
    needs: [stale_fix_description, stale_add_description]
    provider: github
    args: [label, get, "${organization}/${repository}", stale]
    outputs:
      description: {pointer: /description, type: string, optional: true}
    expect:
      - {ref: steps.stale_description_verify.outputs.description, equals: "No activity for a while"}

  # ---- incident ----
  - id: incident_observe
    provider: github
    args: [label, get, "${organization}/${repository}", incident]
    outputs:
      color: {pointer: /color, type: string, optional: true}
      description: {pointer: /description, type: string, optional: true}

  - id: incident_create
    needs: [incident_observe]
    when: [{ref: steps.incident_observe.observation, equals: ABSENT}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/labels", "name=incident", 'color:="b60205"', "description=Production incident"]

  - id: incident_fix_color
    needs: [incident_observe]
    when: [{ref: steps.incident_observe.outputs.color, not_equals: "b60205"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/incident", 'color:="b60205"', "description=Production incident"]

  - id: incident_fix_description
    needs: [incident_observe]
    when: [{ref: steps.incident_observe.outputs.description, not_equals: "Production incident"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/incident", 'color:="b60205"', "description=Production incident"]

  - id: incident_add_description
    needs: [incident_observe]
    when:
      - {ref: steps.incident_observe.observation, equals: PRESENT}
      - {ref: steps.incident_observe.outputs.description, missing: true}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/incident", 'color:="b60205"', "description=Production incident"]

  # Two logical operations per label: Runtime allows one write per operation,
  # and colour and description can drift together.
  - id: incident_verify
    needs: [incident_create, incident_fix_color]
    provider: github
    args: [label, get, "${organization}/${repository}", incident]
    outputs:
      name: {pointer: /name, type: string}
      color: {pointer: /color, type: string}
    expect:
      - {ref: steps.incident_verify.outputs.name, equals: incident}
      - {ref: steps.incident_verify.outputs.color, equals: "b60205"}

  - id: incident_description_verify
    needs: [incident_fix_description, incident_add_description]
    provider: github
    args: [label, get, "${organization}/${repository}", incident]
    outputs:
      description: {pointer: /description, type: string, optional: true}
    expect:
      - {ref: steps.incident_description_verify.outputs.description, equals: "Production incident"}

  # ---- change-freeze ----
  - id: change_freeze_observe
    provider: github
    args: [label, get, "${organization}/${repository}", change-freeze]
    outputs:
      color: {pointer: /color, type: string, optional: true}
      description: {pointer: /description, type: string, optional: true}

  - id: change_freeze_create
    needs: [change_freeze_observe]
    when: [{ref: steps.change_freeze_observe.observation, equals: ABSENT}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/labels", "name=change-freeze", 'color:="d93f0b"', "description=Merges to the default branch are frozen"]

  - id: change_freeze_fix_color
    needs: [change_freeze_observe]
    when: [{ref: steps.change_freeze_observe.outputs.color, not_equals: "d93f0b"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/change-freeze", 'color:="d93f0b"', "description=Merges to the default branch are frozen"]

  - id: change_freeze_fix_description
    needs: [change_freeze_observe]
    when: [{ref: steps.change_freeze_observe.outputs.description, not_equals: "Merges to the default branch are frozen"}]
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/change-freeze", 'color:="d93f0b"', "description=Merges to the default branch are frozen"]

  - id: change_freeze_add_description
    needs: [change_freeze_observe]
    when:
      - {ref: steps.change_freeze_observe.observation, equals: PRESENT}
      - {ref: steps.change_freeze_observe.outputs.description, missing: true}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}/labels/change-freeze", 'color:="d93f0b"', "description=Merges to the default branch are frozen"]

  # Two logical operations per label: Runtime allows one write per operation,
  # and colour and description can drift together.
  - id: change_freeze_verify
    needs: [change_freeze_create, change_freeze_fix_color]
    provider: github
    args: [label, get, "${organization}/${repository}", change-freeze]
    outputs:
      name: {pointer: /name, type: string}
      color: {pointer: /color, type: string}
    expect:
      - {ref: steps.change_freeze_verify.outputs.name, equals: change-freeze}
      - {ref: steps.change_freeze_verify.outputs.color, equals: "d93f0b"}

  - id: change_freeze_description_verify
    needs: [change_freeze_fix_description, change_freeze_add_description]
    provider: github
    args: [label, get, "${organization}/${repository}", change-freeze]
    outputs:
      description: {pointer: /description, type: string, optional: true}
    expect:
      - {ref: steps.change_freeze_description_verify.outputs.description, equals: "Merges to the default branch are frozen"}
```
