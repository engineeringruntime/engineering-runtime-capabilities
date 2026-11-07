# Report how a repository has drifted from the onboarding GitHub standard

Read-only. Safe to execute on any repository, any time.

Compares one repository with the standard that
[java-springboot-service-onboard](java-springboot-service-onboard.md) applies,
and reports every difference in one run. **It never fails on drift.** Each
control is a `drift_*` step that runs only when the repository differs from
the standard, and reads the actual value back:

| Step status | Meaning |
|---|---|
| `drift_*` **ran** (`success`) | the control has drifted; `outputs.actual` is the value found |
| `drift_*` `not required` | the control matches the standard |

| Area | Controls (standard value) |
|---|---|
| Merging | merge commits off, rebase merges off, squash merge on, merged branches deleted, wiki off |
| Dependency security | Dependabot alerts on, Dependabot security updates on |
| Actions | Actions enabled, restricted to selected actions, SHA pinning required, GitHub-owned actions allowed, Marketplace-verified actions not allowed, `GITHUB_TOKEN` read-only, token cannot approve pull requests |
| Default-branch ruleset: identity | `engrt-onboard-default-branch` present and first, active, no bypass actors |
| Default-branch ruleset: targeting | targets branches; includes exactly `~DEFAULT_BRANCH`; excludes nothing |
| Default-branch ruleset: rules | deletion, force push, linear history, required status checks and pull request rules present |
| Default-branch ruleset: pull request | stale approvals dismissed, conversations must be resolved, last-push approval off, merge methods exactly `SQUASH` |
| Default-branch ruleset: status checks | strict (branch up to date), exactly one required check, `build`, from GitHub Actions (app 15368, never unrestricted) |
| Tag ruleset | `engrt-onboard-release-tags` present and second, active, targets tags, includes exactly `refs/tags/v*`, excludes nothing, tag deletion and rewrite blocked |
| Governance files | `.github/CODEOWNERS` present and free of the syntax errors GitHub reports, `SECURITY.md` present, `.github/dependabot.yml` present |

## What is compared, and what is not

- **Equality, not just presence,** for every value in the table: an extra
  branch pattern, merge method or required check is drift, as is a missing
  one.
- **Reported, not compared:** the number of required approvals and whether
  code-owner review is required. Onboarding takes both as inputs
  (`required_approvals`, `require_code_owner_review`), so there is no single
  standard value. Their actual values are in
  `branch_rule_parameters.outputs.approvals` and `.code_owner_review`.
- **Absence is drift too (1.2.0).** A `not_equals` gate does not open when
  the value is missing, so each value that can be absent while its parent
  exists has its own `missing` marker:
  - `drift_merge_settings_not_visible`: the token cannot see the merge
    settings, so they could not be checked;
  - `drift_branch_ruleset_targets_nothing` / `drift_tag_ruleset_targets_nothing`:
    the ruleset exists but includes no ref;
  - `drift_branch_required_checks_empty`: the status-check rule lists no check;
  - `drift_branch_build_check_any_app`: `build` is required but from no
    particular app, so any app or commit status named `build` satisfies it.
- **Out of scope: file contents.** `SECURITY.md` and `dependabot.yml` are
  checked for presence only, and `CODEOWNERS` for presence and syntax. Their
  wording and owners are a review matter, not a drift control.

To check every repository in the organization, run this capability once per
repository and [org-standards-drift](org-standards-drift.md) once for the
organization.

## The standard lives in two places

The values above are the ones `java-springboot-service-onboard` writes. Change
both capabilities together, or this report drifts from the standard it
checks.

## Known limits

- Rulesets are matched by position, because GitHub lists them sorted by name
  and has no lookup by name. A ruleset whose name sorts
  before `engrt-onboard-default-branch` shifts the positions and is reported as
  drift. The freeze ruleset is named `engrt-z-change-freeze` so it sorts
  after both standard rulesets. A repository protected by a differently
  named ruleset reports `drift_branch_ruleset_not_standard` and its rules are
  not inspected.
- Organization rulesets are checked by `org-standards-drift`, not here.
- Visibility is reported in `settings.outputs.visibility` but is not a drift:
  some repositories are public on purpose.
- `CODEOWNERS` is looked for in `.github/` only.
- Environments are not compared.
- `java-springboot-service-onboard` creates rulesets only when there are none,
  and verifies the rules are present, not their parameters. This check is what
  finds a changed parameter (for example a required check whose app
  restriction was removed).

## Run it

```bash
engrt capability execute github/repo-standards-drift \
  --input organization=<organization> --input repository=<repository>
engrt --output json capability execute github/repo-standards-drift \
  --input organization=<organization> --input repository=<repository>   # for scripts
```

```runtime
version: v1
capability_version: "1.2.0"
engrt_version: ">=0.13.0"

inputs:
  organization:
    description: GitHub organization that owns the repository
    required: true
  repository:
    description: Repository name without the owner
    required: true

workflow:
  # ==== Repository settings (standard: squash only, delete merged branches, no wiki) ====
  - id: settings
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      visibility: {pointer: /visibility, type: string}
      allow_merge_commit: {pointer: /allow_merge_commit, type: boolean, optional: true}
      allow_rebase_merge: {pointer: /allow_rebase_merge, type: boolean, optional: true}
      allow_squash_merge: {pointer: /allow_squash_merge, type: boolean, optional: true}
      delete_branch_on_merge: {pointer: /delete_branch_on_merge, type: boolean, optional: true}
      has_wiki: {pointer: /has_wiki, type: boolean, optional: true}
      default_branch: {pointer: /default_branch, type: string}
  # `not_equals` never matches a missing value, so absence gets its own marker:
  # a token without admin access does not see the merge settings at all.
  - id: drift_merge_settings_not_visible
    needs: [settings]
    when: [{ref: steps.settings.outputs.allow_merge_commit, missing: true}]
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      actual: {pointer: /allow_merge_commit, type: boolean, optional: true}
  - id: drift_merge_commits_allowed
    needs: [settings]
    when:
      - {ref: steps.settings.outputs.allow_merge_commit, not_equals: "false"}
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      actual: {pointer: /allow_merge_commit, type: boolean}
  - id: drift_rebase_merges_allowed
    needs: [settings]
    when:
      - {ref: steps.settings.outputs.allow_rebase_merge, not_equals: "false"}
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      actual: {pointer: /allow_rebase_merge, type: boolean}
  - id: drift_squash_merge_disabled
    needs: [settings]
    when:
      - {ref: steps.settings.outputs.allow_squash_merge, not_equals: "true"}
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      actual: {pointer: /allow_squash_merge, type: boolean}
  - id: drift_merged_branches_kept
    needs: [settings]
    when:
      - {ref: steps.settings.outputs.delete_branch_on_merge, not_equals: "true"}
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      actual: {pointer: /delete_branch_on_merge, type: boolean}
  - id: drift_wiki_enabled
    needs: [settings]
    when:
      - {ref: steps.settings.outputs.has_wiki, not_equals: "false"}
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      actual: {pointer: /has_wiki, type: boolean}

  # ==== Dependency security (standard: Dependabot alerts and security updates on) ====
  - id: security
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { hasVulnerabilityAlertsEnabled } }", "owner=${organization}", "name=${repository}"]
    outputs:
      alerts: {pointer: /repository/hasVulnerabilityAlertsEnabled, type: boolean}
  - id: drift_dependabot_alerts_off
    needs: [security]
    when:
      - {ref: steps.security.outputs.alerts, not_equals: "true"}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { hasVulnerabilityAlertsEnabled } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/hasVulnerabilityAlertsEnabled, type: boolean}
  - id: security_updates
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/automated-security-fixes"]
    outputs:
      enabled: {pointer: /enabled, type: boolean}
  - id: drift_dependabot_security_updates_off
    needs: [security_updates]
    when:
      - {ref: steps.security_updates.outputs.enabled, not_equals: "true"}
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/automated-security-fixes"]
    outputs:
      actual: {pointer: /enabled, type: boolean}

  # ==== Actions (standard: GitHub-owned actions only, SHA pinning, read-only token) ====
  - id: actions
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions"]
    outputs:
      enabled: {pointer: /enabled, type: boolean}
      allowed: {pointer: /allowed_actions, type: string, optional: true}
      pinned: {pointer: /sha_pinning_required, type: boolean, optional: true}
  - id: drift_actions_disabled
    needs: [actions]
    when:
      - {ref: steps.actions.outputs.enabled, not_equals: "true"}
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions"]
    outputs:
      actual: {pointer: /enabled, type: boolean}
  - id: drift_actions_not_restricted
    needs: [actions]
    when:
      - {ref: steps.actions.outputs.allowed, not_equals: selected}
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions"]
    outputs:
      actual: {pointer: /allowed_actions, type: string}
  - id: drift_actions_sha_pinning_off
    needs: [actions]
    when:
      - {ref: steps.actions.outputs.pinned, not_equals: "true"}
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions"]
    outputs:
      actual: {pointer: /sha_pinning_required, type: boolean}
  - id: selected_actions
    needs: [actions]
    when: [{ref: steps.actions.outputs.allowed, equals: selected}]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions/selected-actions"]
    outputs:
      github_owned: {pointer: /github_owned_allowed, type: boolean}
      verified: {pointer: /verified_allowed, type: boolean}
  - id: drift_actions_github_owned_blocked
    needs: [selected_actions]
    when:
      - {ref: steps.selected_actions.outputs.github_owned, not_equals: "true"}
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions/selected-actions"]
    outputs:
      actual: {pointer: /github_owned_allowed, type: boolean}
  - id: drift_actions_marketplace_verified_allowed
    needs: [selected_actions]
    when:
      - {ref: steps.selected_actions.outputs.verified, not_equals: "false"}
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions/selected-actions"]
    outputs:
      actual: {pointer: /verified_allowed, type: boolean}
  - id: token
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions/workflow"]
    outputs:
      permissions: {pointer: /default_workflow_permissions, type: string}
      approve: {pointer: /can_approve_pull_request_reviews, type: boolean}
  - id: drift_token_write_by_default
    needs: [token]
    when:
      - {ref: steps.token.outputs.permissions, not_equals: read}
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions/workflow"]
    outputs:
      actual: {pointer: /default_workflow_permissions, type: string}
  - id: drift_token_can_approve_prs
    needs: [token]
    when:
      - {ref: steps.token.outputs.approve, not_equals: "false"}
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions/workflow"]
    outputs:
      actual: {pointer: /can_approve_pull_request_reviews, type: boolean}

  # ==== Rulesets (standard: engrt-onboard-default-branch first, engrt-onboard-release-tags second) ====
  # GitHub lists a repository's rulesets sorted by name (observed 2026-11-06,
  # not creation order) and has no lookup by name, so the standard rulesets
  # are expected first and second; engrt-z-change-freeze sorts after them.
  # Rule checks run only on the standard ruleset itself.
  - id: rulesets
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      total: {pointer: /repository/rulesets/totalCount, type: integer}
      branch: {pointer: /repository/rulesets/nodes/0/name, type: string, optional: true}
      branch_node: {pointer: /repository/rulesets/nodes/0/id, type: string, optional: true}
      branch_enforcement: {pointer: /repository/rulesets/nodes/0/enforcement, type: string, optional: true}
      branch_bypass: {pointer: /repository/rulesets/nodes/0/bypassActors/totalCount, type: integer, optional: true}
      deletion: {pointer: /repository/rulesets/nodes/0/deletion/totalCount, type: integer, optional: true}
      force: {pointer: /repository/rulesets/nodes/0/force/totalCount, type: integer, optional: true}
      linear: {pointer: /repository/rulesets/nodes/0/linear/totalCount, type: integer, optional: true}
      checks: {pointer: /repository/rulesets/nodes/0/checks/totalCount, type: integer, optional: true}
      pr: {pointer: /repository/rulesets/nodes/0/pr/totalCount, type: integer, optional: true}
      tags: {pointer: /repository/rulesets/nodes/1/name, type: string, optional: true}
      tags_enforcement: {pointer: /repository/rulesets/nodes/1/enforcement, type: string, optional: true}
      tags_deletion: {pointer: /repository/rulesets/nodes/1/deletion/totalCount, type: integer, optional: true}
      tags_update: {pointer: /repository/rulesets/nodes/1/update/totalCount, type: integer, optional: true}
  - id: drift_branch_ruleset_missing
    needs: [rulesets]
    when:
      - {ref: steps.rulesets.outputs.branch, missing: true}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      total: {pointer: /repository/rulesets/totalCount, type: integer}
      first: {pointer: /repository/rulesets/nodes/0/name, type: string, optional: true}
      second: {pointer: /repository/rulesets/nodes/1/name, type: string, optional: true}
  - id: drift_branch_ruleset_not_standard
    needs: [rulesets]
    when:
      - {ref: steps.rulesets.outputs.branch, not_equals: engrt-onboard-default-branch}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      total: {pointer: /repository/rulesets/totalCount, type: integer}
      first: {pointer: /repository/rulesets/nodes/0/name, type: string, optional: true}
      second: {pointer: /repository/rulesets/nodes/1/name, type: string, optional: true}
  - id: drift_branch_ruleset_not_active
    needs: [rulesets]
    when:
      - {ref: steps.rulesets.outputs.branch, equals: engrt-onboard-default-branch}
      - {ref: steps.rulesets.outputs.branch_enforcement, not_equals: ACTIVE}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/0/enforcement, type: string, optional: true}
  - id: drift_branch_ruleset_has_bypass
    needs: [rulesets]
    when:
      - {ref: steps.rulesets.outputs.branch, equals: engrt-onboard-default-branch}
      - {ref: steps.rulesets.outputs.branch_bypass, not_equals: "0"}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/0/bypassActors/totalCount, type: integer, optional: true}
  - id: drift_branch_deletion_allowed
    needs: [rulesets]
    when:
      - {ref: steps.rulesets.outputs.branch, equals: engrt-onboard-default-branch}
      - {ref: steps.rulesets.outputs.deletion, not_equals: "1"}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/0/deletion/totalCount, type: integer, optional: true}
  - id: drift_branch_force_push_allowed
    needs: [rulesets]
    when:
      - {ref: steps.rulesets.outputs.branch, equals: engrt-onboard-default-branch}
      - {ref: steps.rulesets.outputs.force, not_equals: "1"}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/0/force/totalCount, type: integer, optional: true}
  - id: drift_branch_linear_history_off
    needs: [rulesets]
    when:
      - {ref: steps.rulesets.outputs.branch, equals: engrt-onboard-default-branch}
      - {ref: steps.rulesets.outputs.linear, not_equals: "1"}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/0/linear/totalCount, type: integer, optional: true}
  - id: drift_branch_status_checks_off
    needs: [rulesets]
    when:
      - {ref: steps.rulesets.outputs.branch, equals: engrt-onboard-default-branch}
      - {ref: steps.rulesets.outputs.checks, not_equals: "1"}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/0/checks/totalCount, type: integer, optional: true}
  - id: drift_branch_pull_request_off
    needs: [rulesets]
    when:
      - {ref: steps.rulesets.outputs.branch, equals: engrt-onboard-default-branch}
      - {ref: steps.rulesets.outputs.pr, not_equals: "1"}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/0/pr/totalCount, type: integer, optional: true}
  - id: ruleset_targets
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { nodes { name target conditions { refName { include exclude } } } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      branch: {pointer: /repository/rulesets/nodes/0/name, type: string, optional: true}
      branch_target: {pointer: /repository/rulesets/nodes/0/target, type: string, optional: true}
      branch_include: {pointer: /repository/rulesets/nodes/0/conditions/refName/include/0, type: string, optional: true}
      branch_include_more: {pointer: /repository/rulesets/nodes/0/conditions/refName/include/1, type: string, optional: true}
      branch_exclude: {pointer: /repository/rulesets/nodes/0/conditions/refName/exclude/0, type: string, optional: true}
      tags: {pointer: /repository/rulesets/nodes/1/name, type: string, optional: true}
      tags_target: {pointer: /repository/rulesets/nodes/1/target, type: string, optional: true}
      tags_include: {pointer: /repository/rulesets/nodes/1/conditions/refName/include/0, type: string, optional: true}
      tags_include_more: {pointer: /repository/rulesets/nodes/1/conditions/refName/include/1, type: string, optional: true}
      tags_exclude: {pointer: /repository/rulesets/nodes/1/conditions/refName/exclude/0, type: string, optional: true}
  - id: drift_branch_ruleset_wrong_target
    needs: [ruleset_targets]
    when:
      - {ref: steps.ruleset_targets.outputs.branch, equals: engrt-onboard-default-branch}
      - {ref: steps.ruleset_targets.outputs.branch_target, not_equals: BRANCH}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { nodes { name target conditions { refName { include exclude } } } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/0/target, type: string, optional: true}
  - id: drift_branch_ruleset_not_default_branch
    needs: [ruleset_targets]
    when:
      - {ref: steps.ruleset_targets.outputs.branch, equals: engrt-onboard-default-branch}
      - {ref: steps.ruleset_targets.outputs.branch_include, not_equals: "~DEFAULT_BRANCH"}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { nodes { name target conditions { refName { include exclude } } } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/0/conditions/refName/include/0, type: string, optional: true}
  - id: drift_branch_ruleset_targets_nothing
    needs: [ruleset_targets]
    when:
      - {ref: steps.ruleset_targets.outputs.branch, equals: engrt-onboard-default-branch}
      - {ref: steps.ruleset_targets.outputs.branch_include, missing: true}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { nodes { name target conditions { refName { include exclude } } } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/0/conditions/refName/include/0, type: string, optional: true}
  - id: drift_branch_ruleset_extra_branches
    needs: [ruleset_targets]
    when:
      - {ref: steps.ruleset_targets.outputs.branch, equals: engrt-onboard-default-branch}
      - {ref: steps.ruleset_targets.outputs.branch_include_more, exists: true}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { nodes { name target conditions { refName { include exclude } } } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/0/conditions/refName/include/1, type: string, optional: true}
  - id: drift_branch_ruleset_excludes_branches
    needs: [ruleset_targets]
    when:
      - {ref: steps.ruleset_targets.outputs.branch, equals: engrt-onboard-default-branch}
      - {ref: steps.ruleset_targets.outputs.branch_exclude, exists: true}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { nodes { name target conditions { refName { include exclude } } } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/0/conditions/refName/exclude/0, type: string, optional: true}
  - id: drift_tag_ruleset_wrong_target
    needs: [ruleset_targets]
    when:
      - {ref: steps.ruleset_targets.outputs.tags, equals: engrt-onboard-release-tags}
      - {ref: steps.ruleset_targets.outputs.tags_target, not_equals: TAG}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { nodes { name target conditions { refName { include exclude } } } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/1/target, type: string, optional: true}
  - id: drift_tag_ruleset_not_release_tags
    needs: [ruleset_targets]
    when:
      - {ref: steps.ruleset_targets.outputs.tags, equals: engrt-onboard-release-tags}
      - {ref: steps.ruleset_targets.outputs.tags_include, not_equals: "refs/tags/v*"}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { nodes { name target conditions { refName { include exclude } } } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/1/conditions/refName/include/0, type: string, optional: true}
  - id: drift_tag_ruleset_targets_nothing
    needs: [ruleset_targets]
    when:
      - {ref: steps.ruleset_targets.outputs.tags, equals: engrt-onboard-release-tags}
      - {ref: steps.ruleset_targets.outputs.tags_include, missing: true}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { nodes { name target conditions { refName { include exclude } } } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/1/conditions/refName/include/0, type: string, optional: true}
  - id: drift_tag_ruleset_extra_patterns
    needs: [ruleset_targets]
    when:
      - {ref: steps.ruleset_targets.outputs.tags, equals: engrt-onboard-release-tags}
      - {ref: steps.ruleset_targets.outputs.tags_include_more, exists: true}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { nodes { name target conditions { refName { include exclude } } } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/1/conditions/refName/include/1, type: string, optional: true}
  - id: drift_tag_ruleset_excludes_tags
    needs: [ruleset_targets]
    when:
      - {ref: steps.ruleset_targets.outputs.tags, equals: engrt-onboard-release-tags}
      - {ref: steps.ruleset_targets.outputs.tags_exclude, exists: true}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { nodes { name target conditions { refName { include exclude } } } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/1/conditions/refName/exclude/0, type: string, optional: true}
  - id: branch_rule_parameters
    needs: [rulesets]
    when: [{ref: steps.rulesets.outputs.branch, equals: engrt-onboard-default-branch}]
    provider: github
    args: [graphql, "query($node: ID!) { node(id: $node) { ... on RepositoryRuleset { pr: rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { dismissStaleReviewsOnPush requiredReviewThreadResolution requireLastPushApproval requiredApprovingReviewCount requireCodeOwnerReview allowedMergeMethods } } } } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { nodes { parameters { ... on RequiredStatusChecksParameters { strictRequiredStatusChecksPolicy requiredStatusChecks { context integrationId } } } } } } } }", "node=${steps.rulesets.outputs.branch_node}"]
    outputs:
      dismiss_stale: {pointer: /node/pr/nodes/0/parameters/dismissStaleReviewsOnPush, type: boolean, optional: true}
      resolve_threads: {pointer: /node/pr/nodes/0/parameters/requiredReviewThreadResolution, type: boolean, optional: true}
      last_push: {pointer: /node/pr/nodes/0/parameters/requireLastPushApproval, type: boolean, optional: true}
      approvals: {pointer: /node/pr/nodes/0/parameters/requiredApprovingReviewCount, type: integer, optional: true}
      code_owner_review: {pointer: /node/pr/nodes/0/parameters/requireCodeOwnerReview, type: boolean, optional: true}
      merge_method: {pointer: /node/pr/nodes/0/parameters/allowedMergeMethods/0, type: string, optional: true}
      merge_method_more: {pointer: /node/pr/nodes/0/parameters/allowedMergeMethods/1, type: string, optional: true}
      strict: {pointer: /node/checks/nodes/0/parameters/strictRequiredStatusChecksPolicy, type: boolean, optional: true}
      check: {pointer: /node/checks/nodes/0/parameters/requiredStatusChecks/0/context, type: string, optional: true}
      check_app: {pointer: /node/checks/nodes/0/parameters/requiredStatusChecks/0/integrationId, type: integer, optional: true}
      check_more: {pointer: /node/checks/nodes/0/parameters/requiredStatusChecks/1/context, type: string, optional: true}
  - id: drift_branch_stale_reviews_kept
    needs: [branch_rule_parameters, rulesets]
    when: [{ref: steps.branch_rule_parameters.outputs.dismiss_stale, not_equals: "true"}]
    provider: github
    args: [graphql, "query($node: ID!) { node(id: $node) { ... on RepositoryRuleset { pr: rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { dismissStaleReviewsOnPush requiredReviewThreadResolution requireLastPushApproval requiredApprovingReviewCount requireCodeOwnerReview allowedMergeMethods } } } } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { nodes { parameters { ... on RequiredStatusChecksParameters { strictRequiredStatusChecksPolicy requiredStatusChecks { context integrationId } } } } } } } }", "node=${steps.rulesets.outputs.branch_node}"]
    outputs:
      actual: {pointer: /node/pr/nodes/0/parameters/dismissStaleReviewsOnPush, type: boolean, optional: true}
  - id: drift_branch_threads_unresolved_allowed
    needs: [branch_rule_parameters, rulesets]
    when: [{ref: steps.branch_rule_parameters.outputs.resolve_threads, not_equals: "true"}]
    provider: github
    args: [graphql, "query($node: ID!) { node(id: $node) { ... on RepositoryRuleset { pr: rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { dismissStaleReviewsOnPush requiredReviewThreadResolution requireLastPushApproval requiredApprovingReviewCount requireCodeOwnerReview allowedMergeMethods } } } } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { nodes { parameters { ... on RequiredStatusChecksParameters { strictRequiredStatusChecksPolicy requiredStatusChecks { context integrationId } } } } } } } }", "node=${steps.rulesets.outputs.branch_node}"]
    outputs:
      actual: {pointer: /node/pr/nodes/0/parameters/requiredReviewThreadResolution, type: boolean, optional: true}
  - id: drift_branch_last_push_approval_required
    needs: [branch_rule_parameters, rulesets]
    when: [{ref: steps.branch_rule_parameters.outputs.last_push, not_equals: "false"}]
    provider: github
    args: [graphql, "query($node: ID!) { node(id: $node) { ... on RepositoryRuleset { pr: rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { dismissStaleReviewsOnPush requiredReviewThreadResolution requireLastPushApproval requiredApprovingReviewCount requireCodeOwnerReview allowedMergeMethods } } } } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { nodes { parameters { ... on RequiredStatusChecksParameters { strictRequiredStatusChecksPolicy requiredStatusChecks { context integrationId } } } } } } } }", "node=${steps.rulesets.outputs.branch_node}"]
    outputs:
      actual: {pointer: /node/pr/nodes/0/parameters/requireLastPushApproval, type: boolean, optional: true}
  - id: drift_branch_merge_not_squash
    needs: [branch_rule_parameters, rulesets]
    when: [{ref: steps.branch_rule_parameters.outputs.merge_method, not_equals: SQUASH}]
    provider: github
    args: [graphql, "query($node: ID!) { node(id: $node) { ... on RepositoryRuleset { pr: rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { dismissStaleReviewsOnPush requiredReviewThreadResolution requireLastPushApproval requiredApprovingReviewCount requireCodeOwnerReview allowedMergeMethods } } } } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { nodes { parameters { ... on RequiredStatusChecksParameters { strictRequiredStatusChecksPolicy requiredStatusChecks { context integrationId } } } } } } } }", "node=${steps.rulesets.outputs.branch_node}"]
    outputs:
      actual: {pointer: /node/pr/nodes/0/parameters/allowedMergeMethods/0, type: string, optional: true}
  - id: drift_branch_extra_merge_methods
    needs: [branch_rule_parameters, rulesets]
    when: [{ref: steps.branch_rule_parameters.outputs.merge_method_more, exists: true}]
    provider: github
    args: [graphql, "query($node: ID!) { node(id: $node) { ... on RepositoryRuleset { pr: rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { dismissStaleReviewsOnPush requiredReviewThreadResolution requireLastPushApproval requiredApprovingReviewCount requireCodeOwnerReview allowedMergeMethods } } } } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { nodes { parameters { ... on RequiredStatusChecksParameters { strictRequiredStatusChecksPolicy requiredStatusChecks { context integrationId } } } } } } } }", "node=${steps.rulesets.outputs.branch_node}"]
    outputs:
      actual: {pointer: /node/pr/nodes/0/parameters/allowedMergeMethods/1, type: string, optional: true}
  - id: drift_branch_status_checks_not_strict
    needs: [branch_rule_parameters, rulesets]
    when: [{ref: steps.branch_rule_parameters.outputs.strict, not_equals: "true"}]
    provider: github
    args: [graphql, "query($node: ID!) { node(id: $node) { ... on RepositoryRuleset { pr: rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { dismissStaleReviewsOnPush requiredReviewThreadResolution requireLastPushApproval requiredApprovingReviewCount requireCodeOwnerReview allowedMergeMethods } } } } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { nodes { parameters { ... on RequiredStatusChecksParameters { strictRequiredStatusChecksPolicy requiredStatusChecks { context integrationId } } } } } } } }", "node=${steps.rulesets.outputs.branch_node}"]
    outputs:
      actual: {pointer: /node/checks/nodes/0/parameters/strictRequiredStatusChecksPolicy, type: boolean, optional: true}
  - id: drift_branch_build_check_missing
    needs: [branch_rule_parameters, rulesets]
    when: [{ref: steps.branch_rule_parameters.outputs.check, not_equals: build}]
    provider: github
    args: [graphql, "query($node: ID!) { node(id: $node) { ... on RepositoryRuleset { pr: rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { dismissStaleReviewsOnPush requiredReviewThreadResolution requireLastPushApproval requiredApprovingReviewCount requireCodeOwnerReview allowedMergeMethods } } } } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { nodes { parameters { ... on RequiredStatusChecksParameters { strictRequiredStatusChecksPolicy requiredStatusChecks { context integrationId } } } } } } } }", "node=${steps.rulesets.outputs.branch_node}"]
    outputs:
      actual: {pointer: /node/checks/nodes/0/parameters/requiredStatusChecks/0/context, type: string, optional: true}
  - id: drift_branch_required_checks_empty
    needs: [branch_rule_parameters, rulesets]
    when:
      - {ref: steps.branch_rule_parameters.outputs.strict, exists: true}
      - {ref: steps.branch_rule_parameters.outputs.check, missing: true}
    provider: github
    args: [graphql, "query($node: ID!) { node(id: $node) { ... on RepositoryRuleset { pr: rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { dismissStaleReviewsOnPush requiredReviewThreadResolution requireLastPushApproval requiredApprovingReviewCount requireCodeOwnerReview allowedMergeMethods } } } } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { nodes { parameters { ... on RequiredStatusChecksParameters { strictRequiredStatusChecksPolicy requiredStatusChecks { context integrationId } } } } } } } }", "node=${steps.rulesets.outputs.branch_node}"]
    outputs:
      actual: {pointer: /node/checks/nodes/0/parameters/requiredStatusChecks/0/context, type: string, optional: true}
  - id: drift_branch_build_check_wrong_app
    needs: [branch_rule_parameters, rulesets]
    when: [{ref: steps.branch_rule_parameters.outputs.check_app, not_equals: "15368"}]
    provider: github
    args: [graphql, "query($node: ID!) { node(id: $node) { ... on RepositoryRuleset { pr: rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { dismissStaleReviewsOnPush requiredReviewThreadResolution requireLastPushApproval requiredApprovingReviewCount requireCodeOwnerReview allowedMergeMethods } } } } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { nodes { parameters { ... on RequiredStatusChecksParameters { strictRequiredStatusChecksPolicy requiredStatusChecks { context integrationId } } } } } } } }", "node=${steps.rulesets.outputs.branch_node}"]
    outputs:
      actual: {pointer: /node/checks/nodes/0/parameters/requiredStatusChecks/0/integrationId, type: integer, optional: true}
  # A required check with no app restriction can be satisfied by any app or
  # commit status named `build`.
  - id: drift_branch_build_check_any_app
    needs: [branch_rule_parameters, rulesets]
    when:
      - {ref: steps.branch_rule_parameters.outputs.check, equals: build}
      - {ref: steps.branch_rule_parameters.outputs.check_app, missing: true}
    provider: github
    args: [graphql, "query($node: ID!) { node(id: $node) { ... on RepositoryRuleset { pr: rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { dismissStaleReviewsOnPush requiredReviewThreadResolution requireLastPushApproval requiredApprovingReviewCount requireCodeOwnerReview allowedMergeMethods } } } } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { nodes { parameters { ... on RequiredStatusChecksParameters { strictRequiredStatusChecksPolicy requiredStatusChecks { context integrationId } } } } } } } }", "node=${steps.rulesets.outputs.branch_node}"]
    outputs:
      actual: {pointer: /node/checks/nodes/0/parameters/requiredStatusChecks/0/integrationId, type: integer, optional: true}
  - id: drift_branch_extra_required_checks
    needs: [branch_rule_parameters, rulesets]
    when: [{ref: steps.branch_rule_parameters.outputs.check_more, exists: true}]
    provider: github
    args: [graphql, "query($node: ID!) { node(id: $node) { ... on RepositoryRuleset { pr: rules(first: 1, type: PULL_REQUEST) { nodes { parameters { ... on PullRequestParameters { dismissStaleReviewsOnPush requiredReviewThreadResolution requireLastPushApproval requiredApprovingReviewCount requireCodeOwnerReview allowedMergeMethods } } } } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { nodes { parameters { ... on RequiredStatusChecksParameters { strictRequiredStatusChecksPolicy requiredStatusChecks { context integrationId } } } } } } } }", "node=${steps.rulesets.outputs.branch_node}"]
    outputs:
      actual: {pointer: /node/checks/nodes/0/parameters/requiredStatusChecks/1/context, type: string, optional: true}
  - id: drift_tag_ruleset_missing
    needs: [rulesets]
    when:
      - {ref: steps.rulesets.outputs.tags, missing: true}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      total: {pointer: /repository/rulesets/totalCount, type: integer}
      first: {pointer: /repository/rulesets/nodes/0/name, type: string, optional: true}
      second: {pointer: /repository/rulesets/nodes/1/name, type: string, optional: true}
  - id: drift_tag_ruleset_not_standard
    needs: [rulesets]
    when:
      - {ref: steps.rulesets.outputs.tags, not_equals: engrt-onboard-release-tags}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      total: {pointer: /repository/rulesets/totalCount, type: integer}
      first: {pointer: /repository/rulesets/nodes/0/name, type: string, optional: true}
      second: {pointer: /repository/rulesets/nodes/1/name, type: string, optional: true}
  - id: drift_tag_ruleset_not_active
    needs: [rulesets]
    when:
      - {ref: steps.rulesets.outputs.tags, equals: engrt-onboard-release-tags}
      - {ref: steps.rulesets.outputs.tags_enforcement, not_equals: ACTIVE}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/1/enforcement, type: string, optional: true}
  - id: drift_tag_deletion_allowed
    needs: [rulesets]
    when:
      - {ref: steps.rulesets.outputs.tags, equals: engrt-onboard-release-tags}
      - {ref: steps.rulesets.outputs.tags_deletion, not_equals: "1"}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/1/deletion/totalCount, type: integer, optional: true}
  - id: drift_tag_rewrite_allowed
    needs: [rulesets]
    when:
      - {ref: steps.rulesets.outputs.tags, equals: engrt-onboard-release-tags}
      - {ref: steps.rulesets.outputs.tags_update, not_equals: "1"}
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 2, includeParents: false) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } linear: rules(first: 1, type: REQUIRED_LINEAR_HISTORY) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } update: rules(first: 1, type: UPDATE) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } id } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      actual: {pointer: /repository/rulesets/nodes/1/update/totalCount, type: integer, optional: true}

  # ==== Governance files (standard: CODEOWNERS, SECURITY.md, Dependabot configuration) ====
  - id: file_codeowners
    provider: github
    args: [file, get, "${organization}/${repository}", ".github/CODEOWNERS"]
  - id: drift_codeowners_missing
    needs: [file_codeowners]
    when:
      - {ref: steps.file_codeowners.observation, equals: ABSENT}
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      repository: {pointer: /full_name, type: string}
  - id: file_security_policy
    provider: github
    args: [file, get, "${organization}/${repository}", "SECURITY.md"]
  - id: drift_security_policy_missing
    needs: [file_security_policy]
    when:
      - {ref: steps.file_security_policy.observation, equals: ABSENT}
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      repository: {pointer: /full_name, type: string}
  - id: file_dependabot_config
    provider: github
    args: [file, get, "${organization}/${repository}", ".github/dependabot.yml"]
  - id: drift_dependabot_config_missing
    needs: [file_dependabot_config]
    when:
      - {ref: steps.file_dependabot_config.observation, equals: ABSENT}
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      repository: {pointer: /full_name, type: string}
  - id: codeowners_errors
    needs: [file_codeowners]
    when: [{ref: steps.file_codeowners.observation, equals: PRESENT}]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/codeowners/errors"]
    outputs:
      first_error: {pointer: /errors/0/message, type: string, optional: true}
  - id: drift_codeowners_invalid
    needs: [codeowners_errors]
    when:
      - {ref: steps.codeowners_errors.outputs.first_error, exists: true}
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/codeowners/errors"]
    outputs:
      line: {pointer: /errors/0/line, type: integer, optional: true}
      actual: {pointer: /errors/0/kind, type: string, optional: true}
```
