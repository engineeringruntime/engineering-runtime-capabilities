# Decommission a repository safely: refuse while work is open, then archive

> **Mutating.** It archives the repository, which makes it read-only. Run
> `plan` first. Execute only when the owning team has asked for that exact
> repository to be retired.

Retiring a service repository is a governed change, not a click:

| Gate | Stops the run when |
|---|---|
| `open_work_gate` | any pull request is still open |
| `running_gate`, `queued_gate`, `requested_gate`, `waiting_gate`, `pending_gate` | any workflow run is `in_progress`, `queued`, `requested`, `waiting` (for example on an environment approval) or `pending` |

Then the description records the reason and the repository is **archived**:
read-only, still searchable, its history, issues, releases and audit trail
kept. It is **never deleted**. Policy denies `api DELETE`, so the only way
back is an owner unarchiving it (`api PATCH /repos/<org>/<repo> archived:=false`),
and nothing is lost either way.

The internal catalog's `github/github-repo-archive` toggles `archived` with no
precondition and no read-back; use it for sandboxes. This capability is for
production repositories, where open work must stop the retirement.

| Run | Result |
|---|---|
| no open work | description set, repository archived (`APPLIED`) |
| already archived | nothing written (`SATISFIED`) |
| an open pull request, or a workflow run in any not-finished state | stops at the gate; nothing written |

## What it needs

- Policy: the GitHub provider with `api GET` and `api PATCH`.
- Credential: repository Administration read/write.

## Known limits

- Open issues do not block decommissioning: they stay readable in the
  archive. Close or transfer them first if they must stay actionable.
- The gates run on every run, also on an already archived repository.
- The five run states are the ones GitHub's workflow-runs `status` filter
  defines for runs that have not finished. Each gate reads only the count
  (`total_count`), so one request per state is enough.

## Run it

```bash
engrt capability plan github/repo-decommission \
  --input organization=<organization> --input repository=<repository> \
  --input "reason=Replaced by er-payments-v2 (ADR-17)."
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
  reason:
    description: Why the repository is retired, e.g. Replaced by er-payments-v2 (ADR-17). Becomes the repository description.
    required: true

workflow:
  - id: repo_observe
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      archived: {pointer: /archived, type: boolean, optional: true}

  # ==== Gates: open work stops the run before anything is written ====
  - id: open_work_gate
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { pullRequests(states: OPEN) { totalCount } } }"
      - "owner=${organization}"
      - "name=${repository}"
    outputs:
      open_pull_requests: {pointer: /repository/pullRequests/totalCount, type: integer}
    expect:
      - {ref: steps.open_work_gate.outputs.open_pull_requests, equals: "0"}

  - id: running_gate
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/runs", "status=in_progress", "per_page=1"]
    outputs:
      runs: {pointer: /total_count, type: integer}
    expect:
      - {ref: steps.running_gate.outputs.runs, equals: "0"}

  - id: queued_gate
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/runs", "status=queued", "per_page=1"]
    outputs:
      runs: {pointer: /total_count, type: integer}
    expect:
      - {ref: steps.queued_gate.outputs.runs, equals: "0"}

  - id: requested_gate
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/runs", "status=requested", "per_page=1"]
    outputs:
      runs: {pointer: /total_count, type: integer}
    expect:
      - {ref: steps.requested_gate.outputs.runs, equals: "0"}

  - id: waiting_gate
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/runs", "status=waiting", "per_page=1"]
    outputs:
      runs: {pointer: /total_count, type: integer}
    expect:
      - {ref: steps.waiting_gate.outputs.runs, equals: "0"}

  - id: pending_gate
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/runs", "status=pending", "per_page=1"]
    outputs:
      runs: {pointer: /total_count, type: integer}
    expect:
      - {ref: steps.pending_gate.outputs.runs, equals: "0"}

  # ==== Archive (never delete) ====
  - id: archive
    needs: [repo_observe]
    when:
      - {ref: steps.repo_observe.observation, equals: PRESENT}
      - {ref: steps.repo_observe.outputs.archived, equals: "false"}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}", "description=Decommissioned: ${reason}", "archived:=true"]

  - id: archive_verify
    needs: [archive]
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      archived: {pointer: /archived, type: boolean}
    expect:
      - {ref: steps.archive_verify.outputs.archived, equals: "true"}
```
