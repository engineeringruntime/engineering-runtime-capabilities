# Converge `engrt-ruleset-default` to its baseline

> **Mutating when it finds drift.** On a ruleset that already matches, every
> fix step is `not_required` and nothing is written. Run `plan` first. Execute
> only on an explicit request for that repository.

Reads an existing `engrt-ruleset-default` and repairs only what has drifted,
using the pattern **observe → gated fix → verify**, one chain per concern. Rerun it any
time; the result says what happened:

| Run | Per-concern outcome |
|---|---|
| Ruleset already matches | `SATISFIED`, every fix step `not_required`, no write |
| One thing drifted (a bypass actor, enforcement off, a changed rule) | that chain `APPLIED`, the rest `SATISFIED` |
| Several things drifted | each drifted chain `APPLIED`, the rest `SATISFIED` |
| Wrong `ruleset_id` (another ruleset) | `verify_name` `FAILED`, the rest `NOT_EXECUTED`, nothing written |

**Why `APPLIED`, not `RECONCILED`.** The engine reports `RECONCILED` only when
a gate requires an observation of `PRESENT`, and observations exist only for
curated reads (`repo view`, `file get`, `label get`, `release get`). There is
no curated read for rulesets, so this reads through `api GET` and a repair
counts as `APPLIED`. The detecting, gating and verifying work as they would
for `RECONCILED`.

## What it converges

The baseline is what [repo-ruleset-default](repo-ruleset-default.md) creates.
Each row is a chain; every fix is a **partial `PUT`** that writes only its own
field. Rules are counted **by type** through GraphQL, so the checks do not
depend on the order GitHub returns them in.

| Concern | Baseline | Repair |
|---|---|---|
| name, target (guards) | `engrt-ruleset-default`, branch | none; a mismatch fails the run |
| enforcement | active | `enforcement=active` |
| bypass actors | none, of any type | `bypass_actors:=[]` |
| rules | exactly one each of `deletion`, `non_fast_forward`, `pull_request`, and three in all | the three baseline rules |
| `pull_request` options | 0 approvals; stale-review dismissal, code-owner review, last-push approval and thread resolution all off | the three baseline rules |
| branch patterns | first pattern `~DEFAULT_BRANCH`, no second pattern, no `exclude` | `conditions` reset |

## Rule order is GitHub's, not ours

GitHub stores rules in the order of their internal records and ignores the
order of a `PUT`. A rule that was removed and added back comes back **last**,
and no `PUT` moves it. An earlier version of this capability checked rules by
position and could never converge after such a change: the repair succeeded,
the position check still failed, and the run stopped. The checks now count by
type, and order is not converged.

## Known limits

- Not checked: `pull_request.allowed_merge_methods`, the dismissal and reviewer
  lists, and the parameters of rules other than `pull_request`.
- No OR in the grammar, so each concern is its own chain, and a gate holds at
  most four tests.
- `ruleset_id` is the repository's own id for the ruleset (it differs per
  repository). Find it with
  `engrt github api GET /repos/<organization>/<repository>/rulesets`.
- A deleted ruleset cannot be recreated here: run
  [repo-ruleset-default](repo-ruleset-default.md).
- Other rulesets on the repository are never touched: every fix is gated on
  the name.
- The bypass check counts actors, so an organization-admin actor
  (`actor_id: null`) is seen like any other. An earlier version read `actor_id`
  and reported a false `SATISFIED`.

## Run it

```bash
engrt capability plan github/repo-ruleset-default-reconcile \
  --input organization=<organization> --input repository=<repo> --input ruleset_id=<id>
```

Execute with the same inputs after review. `--output json` lists each
operation's outcome under `operations`.

```runtime
version: v1
capability_version: "3.0.0"
engrt_version: ">=0.13.0"

inputs:
  organization:
    description: GitHub organization that owns the repository
    required: true
  repository:
    description: Repository name without the owner
    required: true
  ruleset_id:
    description: Numeric id of the engrt-ruleset-default ruleset in this repository
    required: true

workflow:
  - id: observe
    provider: github
    args:
      - graphql
      - |
        query($owner: String!, $name: String!, $id: Int!) {
          repository(owner: $owner, name: $name) {
            ruleset(databaseId: $id) {
              name
              target
              enforcement
              bypassActors(first: 1) { totalCount }
              conditions { refName { include exclude } }
              total: rules(first: 1) { totalCount }
              del: rules(first: 1, type: DELETION) { totalCount }
              nff: rules(first: 1, type: NON_FAST_FORWARD) { totalCount }
              prc: rules(first: 1, type: PULL_REQUEST) { totalCount }
              pr: rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { requiredApprovingReviewCount dismissStaleReviewsOnPush requireCodeOwnerReview requireLastPushApproval requiredReviewThreadResolution } } } }
            }
          }
        }
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      name: {pointer: /repository/ruleset/name, type: string}
      target: {pointer: /repository/ruleset/target, type: string}
      enf: {pointer: /repository/ruleset/enforcement, type: string}
      bypass: {pointer: /repository/ruleset/bypassActors/totalCount, type: integer}
      total: {pointer: /repository/ruleset/total/totalCount, type: integer}
      del: {pointer: /repository/ruleset/del/totalCount, type: integer}
      nff: {pointer: /repository/ruleset/nff/totalCount, type: integer}
      prc: {pointer: /repository/ruleset/prc/totalCount, type: integer}
      approvals: {pointer: /repository/ruleset/pr/nodes/0/parameters/requiredApprovingReviewCount, type: integer, optional: true}
      dismiss: {pointer: /repository/ruleset/pr/nodes/0/parameters/dismissStaleReviewsOnPush, type: boolean, optional: true}
      owner: {pointer: /repository/ruleset/pr/nodes/0/parameters/requireCodeOwnerReview, type: boolean, optional: true}
      lastpush: {pointer: /repository/ruleset/pr/nodes/0/parameters/requireLastPushApproval, type: boolean, optional: true}
      threads: {pointer: /repository/ruleset/pr/nodes/0/parameters/requiredReviewThreadResolution, type: boolean, optional: true}
      inc0: {pointer: /repository/ruleset/conditions/refName/include/0, type: string, optional: true}
      inc1: {pointer: /repository/ruleset/conditions/refName/include/1, type: string, optional: true}
      exc0: {pointer: /repository/ruleset/conditions/refName/exclude/0, type: string, optional: true}

  # ---- Name and target guards: no mutation, fail the run on a mismatch ----
  - id: verify_name
    needs: [observe]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { name } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/name, type: string}
    expect:
      - {ref: steps.verify_name.outputs.v, equals: engrt-ruleset-default}

  - id: verify_target
    needs: [observe]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { target } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/target, type: string}
    expect:
      - {ref: steps.verify_target.outputs.v, equals: BRANCH}

  # ---- enforcement is active ----
  - id: fix_enforcement
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.enf, not_equals: ACTIVE}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", "enforcement=active"]

  - id: verify_enforcement
    needs: [fix_enforcement]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { enforcement } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/enforcement, type: string, optional: true}
    expect:
      - {ref: steps.verify_enforcement.outputs.v, equals: ACTIVE}

  # ---- no bypass actors (any type) ----
  - id: fix_bypass
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.bypass, not_equals: "0"}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", 'bypass_actors:=[]']

  - id: verify_bypass
    needs: [fix_bypass]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { bypassActors(first: 1) { totalCount } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/bypassActors/totalCount, type: integer, optional: true}
    expect:
      - {ref: steps.verify_bypass.outputs.v, equals: "0"}

  # ---- exactly one `deletion` rule ----
  - id: fix_rule_deletion
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.del, not_equals: "1"}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", 'rules:=[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}}]']

  - id: verify_rule_deletion
    needs: [fix_rule_deletion]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { rules(first: 1, type: DELETION) { totalCount } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/rules/totalCount, type: integer, optional: true}
    expect:
      - {ref: steps.verify_rule_deletion.outputs.v, equals: "1"}

  # ---- exactly one `non_fast_forward` rule ----
  - id: fix_rule_nff
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.nff, not_equals: "1"}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", 'rules:=[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}}]']

  - id: verify_rule_nff
    needs: [fix_rule_nff]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { rules(first: 1, type: NON_FAST_FORWARD) { totalCount } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/rules/totalCount, type: integer, optional: true}
    expect:
      - {ref: steps.verify_rule_nff.outputs.v, equals: "1"}

  # ---- exactly one `pull_request` rule ----
  - id: fix_rule_pr
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.prc, not_equals: "1"}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", 'rules:=[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}}]']

  - id: verify_rule_pr
    needs: [fix_rule_pr]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { rules(first: 1, type: PULL_REQUEST) { totalCount } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/rules/totalCount, type: integer, optional: true}
    expect:
      - {ref: steps.verify_rule_pr.outputs.v, equals: "1"}

  # ---- exactly three rules in all ----
  - id: fix_rule_total
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.total, not_equals: "3"}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", 'rules:=[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}}]']

  - id: verify_rule_total
    needs: [fix_rule_total]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { rules(first: 1) { totalCount } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/rules/totalCount, type: integer, optional: true}
    expect:
      - {ref: steps.verify_rule_total.outputs.v, equals: "3"}

  # ---- 0 required approvals ----
  - id: fix_approvals
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.approvals, not_equals: "0"}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", 'rules:=[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}}]']

  - id: verify_approvals
    needs: [fix_approvals]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { requiredApprovingReviewCount } } } } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/rules/nodes/0/parameters/requiredApprovingReviewCount, type: integer, optional: true}
    expect:
      - {ref: steps.verify_approvals.outputs.v, equals: "0"}

  # ---- `dismiss_stale_reviews_on_push` is off ----
  - id: fix_dismiss_stale_reviews_on_push
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.dismiss, not_equals: "false"}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", 'rules:=[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}}]']

  - id: verify_dismiss_stale_reviews_on_push
    needs: [fix_dismiss_stale_reviews_on_push]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { dismissStaleReviewsOnPush } } } } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/rules/nodes/0/parameters/dismissStaleReviewsOnPush, type: boolean, optional: true}
    expect:
      - {ref: steps.verify_dismiss_stale_reviews_on_push.outputs.v, equals: "false"}

  # ---- `require_code_owner_review` is off ----
  - id: fix_require_code_owner_review
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.owner, not_equals: "false"}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", 'rules:=[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}}]']

  - id: verify_require_code_owner_review
    needs: [fix_require_code_owner_review]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { requireCodeOwnerReview } } } } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/rules/nodes/0/parameters/requireCodeOwnerReview, type: boolean, optional: true}
    expect:
      - {ref: steps.verify_require_code_owner_review.outputs.v, equals: "false"}

  # ---- `require_last_push_approval` is off ----
  - id: fix_require_last_push_approval
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.lastpush, not_equals: "false"}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", 'rules:=[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}}]']

  - id: verify_require_last_push_approval
    needs: [fix_require_last_push_approval]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { requireLastPushApproval } } } } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/rules/nodes/0/parameters/requireLastPushApproval, type: boolean, optional: true}
    expect:
      - {ref: steps.verify_require_last_push_approval.outputs.v, equals: "false"}

  # ---- `required_review_thread_resolution` is off ----
  - id: fix_required_review_thread_resolution
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.threads, not_equals: "false"}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", 'rules:=[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}}]']

  - id: verify_required_review_thread_resolution
    needs: [fix_required_review_thread_resolution]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { requiredReviewThreadResolution } } } } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/rules/nodes/0/parameters/requiredReviewThreadResolution, type: boolean, optional: true}
    expect:
      - {ref: steps.verify_required_review_thread_resolution.outputs.v, equals: "false"}

  # ---- first branch pattern is the default branch ----
  - id: fix_include_wrong
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.inc0, not_equals: "~DEFAULT_BRANCH"}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", 'conditions:={"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}}']

  - id: verify_include_wrong
    needs: [fix_include_wrong]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { conditions { refName { include exclude } } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/conditions/refName/include/0, type: string, optional: true}
    expect:
      - {ref: steps.verify_include_wrong.outputs.v, equals: "~DEFAULT_BRANCH"}

  # ---- a branch pattern exists ----
  - id: fix_include_missing
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.inc0, missing: true}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", 'conditions:={"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}}']

  - id: verify_include_missing
    needs: [fix_include_missing]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { conditions { refName { include exclude } } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/conditions/refName/include/0, type: string, optional: true}
    expect:
      - {ref: steps.verify_include_missing.outputs.v, equals: "~DEFAULT_BRANCH"}

  # ---- no second branch pattern ----
  - id: fix_extra_pattern
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.inc1, exists: true}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", 'conditions:={"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}}']

  - id: verify_extra_pattern
    needs: [fix_extra_pattern]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { conditions { refName { include exclude } } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/conditions/refName/include/1, type: string, optional: true}
    expect:
      - {ref: steps.verify_extra_pattern.outputs.v, missing: true}

  # ---- no exclude pattern ----
  - id: fix_exclude
    needs: [observe]
    when:
      - {ref: steps.observe.outputs.name, equals: engrt-ruleset-default}
      - {ref: steps.observe.outputs.exc0, exists: true}
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/rulesets/${ruleset_id}", 'conditions:={"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}}']

  - id: verify_exclude
    needs: [fix_exclude]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $id: Int!) { repository(owner: $owner, name: $name) { ruleset(databaseId: $id) { conditions { refName { include exclude } } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "id:=${ruleset_id}"
    outputs:
      v: {pointer: /repository/ruleset/conditions/refName/exclude/0, type: string, optional: true}
    expect:
      - {ref: steps.verify_exclude.outputs.v, missing: true}
```
