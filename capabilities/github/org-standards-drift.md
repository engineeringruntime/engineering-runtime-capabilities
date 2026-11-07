# Report how an organization has drifted from the onboarding GitHub standard

Read-only. Safe to execute any time.

The organization-level half of the standards check. Like
[repo-standards-drift](repo-standards-drift.md), **it never fails on drift**:
each control is a `drift_*` step that runs only when the organization differs
from the standard, and reads the actual value back. A matching control reports
`not required`.

## Organization settings

| Control | Standard | Why |
|---|---|---|
| `drift_two_factor_not_required` | members must use 2FA | an account without 2FA is the cheapest way into every repository |
| `drift_members_can_create_repositories` | off | repositories are created through governed onboarding, so they start protected |
| `drift_members_can_create_public_repositories` | off | nothing becomes public by accident |
| `drift_default_permission_not_read` | `read` | write access is granted per team and repository, never by default |
| `drift_new_repos_without_dependabot_alerts` | Dependabot alerts on for new repositories | a new repository sees its vulnerabilities from day one |
| `drift_org_settings_not_visible` | the settings above are readable | GitHub returns them only to organization owners; a non-owner token sees none of them, which must not read as "no drift" |

## Organization standard ruleset

An organization ruleset applies the baseline to every repository at once, so
no repository can be left out by forgetting to onboard it. The standard
ruleset is named by the `standard_ruleset` input and must be the
organization's **first** ruleset (GitHub lists rulesets sorted by name and has no lookup by name). Name the
standard ruleset so it sorts first.

| Control | Standard |
|---|---|
| `drift_org_standard_ruleset_missing` | the organization has at least one ruleset |
| `drift_org_standard_ruleset_not_first` | the first ruleset is `standard_ruleset` |
| `drift_org_standard_ruleset_not_active` | enforcement `ACTIVE` (not `EVALUATE` or `DISABLED`) |
| `drift_org_standard_ruleset_has_bypass` | no bypass actors |
| `drift_org_standard_ruleset_not_all_repositories` | repository condition includes `~ALL` |
| `drift_org_standard_ruleset_targets_no_repositories` | the repository condition includes something (an empty list targets nothing) |
| `drift_org_standard_ruleset_excludes_repositories` | no repository is excluded |
| `drift_org_standard_ruleset_not_default_branch` | branch condition includes `~DEFAULT_BRANCH` |
| `drift_org_standard_ruleset_targets_no_branches` | the branch condition includes something |
| `drift_org_standard_deletion_allowed`, `_force_push_allowed`, `_pull_request_off` | one rule each for deletion, force push and pull request |

An exclusion is reported with the first excluded repository name in
`outputs.actual`: that is the repository someone opted out of the standard.

## Known limits

- **Absence is drift too.** `not_equals` does not match a missing value, so
  owner-only settings read by a non-owner, and a standard ruleset with an empty
  condition list, each have their own `missing` marker (above).

- Only repository-name conditions are read. A ruleset that targets
  repositories by custom property or by id reports
  `drift_org_standard_ruleset_not_all_repositories`.
- Organization rulesets on private repositories need GitHub Team or above.
- GitHub is moving the new-repository security defaults to code security
  configurations; `dependabot_alerts_enabled_for_new_repositories` is the
  field the REST API still returns.

## Run it

```bash
engrt capability execute github/org-standards-drift \
  --input organization=<organization> --input standard_ruleset=engrt-org-standard
```

```runtime
version: v1
capability_version: "1.1.0"
engrt_version: ">=0.13.0"

inputs:
  organization:
    description: GitHub organization to check
    required: true
  standard_ruleset:
    description: Name of the organization ruleset that carries the standard, e.g. engrt-org-standard
    required: true

workflow:
  # ==== Organization settings ====
  - id: org_settings
    provider: github
    args: [api, GET, "/orgs/${organization}"]
    outputs:
      two_factor: {pointer: /two_factor_requirement_enabled, type: boolean, optional: true}
      create_repos: {pointer: /members_can_create_repositories, type: boolean, optional: true}
      create_public: {pointer: /members_can_create_public_repositories, type: boolean, optional: true}
      default_permission: {pointer: /default_repository_permission, type: string, optional: true}
      new_repo_alerts: {pointer: /dependabot_alerts_enabled_for_new_repositories, type: boolean, optional: true}

  - id: drift_two_factor_not_required
    needs: [org_settings]
    when: [{ref: steps.org_settings.outputs.two_factor, not_equals: "true"}]
    provider: github
    args: [api, GET, "/orgs/${organization}"]
    outputs:
      actual: {pointer: /two_factor_requirement_enabled, type: boolean}

  - id: drift_members_can_create_repositories
    needs: [org_settings]
    when: [{ref: steps.org_settings.outputs.create_repos, not_equals: "false"}]
    provider: github
    args: [api, GET, "/orgs/${organization}"]
    outputs:
      actual: {pointer: /members_can_create_repositories, type: boolean}

  - id: drift_members_can_create_public_repositories
    needs: [org_settings]
    when: [{ref: steps.org_settings.outputs.create_public, not_equals: "false"}]
    provider: github
    args: [api, GET, "/orgs/${organization}"]
    outputs:
      actual: {pointer: /members_can_create_public_repositories, type: boolean}

  - id: drift_default_permission_not_read
    needs: [org_settings]
    when: [{ref: steps.org_settings.outputs.default_permission, not_equals: read}]
    provider: github
    args: [api, GET, "/orgs/${organization}"]
    outputs:
      actual: {pointer: /default_repository_permission, type: string}

  - id: drift_new_repos_without_dependabot_alerts
    needs: [org_settings]
    when: [{ref: steps.org_settings.outputs.new_repo_alerts, not_equals: "true"}]
    provider: github
    args: [api, GET, "/orgs/${organization}"]
    outputs:
      actual: {pointer: /dependabot_alerts_enabled_for_new_repositories, type: boolean}

  # ==== Organization standard ruleset ====
  # `not_equals` never matches a missing value. These fields are returned only
  # to organization owners: a non-owner sees none of them, which must not read
  # as "no drift".
  - id: drift_org_settings_not_visible
    needs: [org_settings]
    when: [{ref: steps.org_settings.outputs.two_factor, missing: true}]
    provider: github
    args: [api, GET, "/orgs/${organization}"]
    outputs:
      actual: {pointer: /two_factor_requirement_enabled, type: boolean, optional: true}
  - id: org_rulesets
    provider: github
    args:
      - graphql
      - "query($org: String!) { organization(login: $org) { rulesets(first: 1) { totalCount nodes { name target enforcement bypassActors(first: 1) { totalCount } conditions { repositoryName { include exclude } refName { include } } deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } } } } }"
      - "org=${organization}"
    outputs:
      total: {pointer: /organization/rulesets/totalCount, type: integer}
      name: {pointer: /organization/rulesets/nodes/0/name, type: string, optional: true}
      enforcement: {pointer: /organization/rulesets/nodes/0/enforcement, type: string, optional: true}
      bypass: {pointer: /organization/rulesets/nodes/0/bypassActors/totalCount, type: integer, optional: true}
      repos_include: {pointer: /organization/rulesets/nodes/0/conditions/repositoryName/include/0, type: string, optional: true}
      repos_exclude: {pointer: /organization/rulesets/nodes/0/conditions/repositoryName/exclude/0, type: string, optional: true}
      ref_include: {pointer: /organization/rulesets/nodes/0/conditions/refName/include/0, type: string, optional: true}
      deletion: {pointer: /organization/rulesets/nodes/0/deletion/totalCount, type: integer, optional: true}
      force: {pointer: /organization/rulesets/nodes/0/force/totalCount, type: integer, optional: true}
      pr: {pointer: /organization/rulesets/nodes/0/pr/totalCount, type: integer, optional: true}

  - id: drift_org_standard_ruleset_missing
    needs: [org_rulesets]
    when: [{ref: steps.org_rulesets.outputs.total, equals: "0"}]
    provider: github
    args: [api, GET, "/orgs/${organization}/rulesets"]
    outputs:
      first: {pointer: /0/name, type: string, optional: true}

  - id: drift_org_standard_ruleset_not_first
    needs: [org_rulesets]
    when: [{ref: steps.org_rulesets.outputs.name, not_equals: "${standard_ruleset}"}]
    provider: github
    args: [api, GET, "/orgs/${organization}/rulesets"]
    outputs:
      actual: {pointer: /0/name, type: string}

  - id: drift_org_standard_ruleset_not_active
    needs: [org_rulesets]
    when:
      - {ref: steps.org_rulesets.outputs.name, equals: "${standard_ruleset}"}
      - {ref: steps.org_rulesets.outputs.enforcement, not_equals: ACTIVE}
    provider: github
    args: [api, GET, "/orgs/${organization}/rulesets"]
    outputs:
      actual: {pointer: /0/enforcement, type: string}

  - id: drift_org_standard_ruleset_has_bypass
    needs: [org_rulesets]
    when:
      - {ref: steps.org_rulesets.outputs.name, equals: "${standard_ruleset}"}
      - {ref: steps.org_rulesets.outputs.bypass, not_equals: "0"}
    provider: github
    args: [graphql, "query($org: String!) { organization(login: $org) { rulesets(first: 1) { nodes { bypassActors(first: 1) { totalCount } } } } }", "org=${organization}"]
    outputs:
      actual: {pointer: /organization/rulesets/nodes/0/bypassActors/totalCount, type: integer}

  - id: drift_org_standard_ruleset_not_all_repositories
    needs: [org_rulesets]
    when:
      - {ref: steps.org_rulesets.outputs.name, equals: "${standard_ruleset}"}
      - {ref: steps.org_rulesets.outputs.repos_include, not_equals: "~ALL"}
    provider: github
    args: [graphql, "query($org: String!) { organization(login: $org) { rulesets(first: 1) { nodes { conditions { repositoryName { include } } } } } }", "org=${organization}"]
    outputs:
      actual: {pointer: /organization/rulesets/nodes/0/conditions/repositoryName/include/0, type: string, optional: true}

  - id: drift_org_standard_ruleset_targets_no_repositories
    needs: [org_rulesets]
    when:
      - {ref: steps.org_rulesets.outputs.name, equals: "${standard_ruleset}"}
      - {ref: steps.org_rulesets.outputs.repos_include, missing: true}
    provider: github
    args: [graphql, "query($org: String!) { organization(login: $org) { rulesets(first: 1) { nodes { conditions { repositoryName { include } refName { include } } } } } }", "org=${organization}"]
    outputs:
      actual: {pointer: /organization/rulesets/nodes/0/conditions/repositoryName/include/0, type: string, optional: true}
  - id: drift_org_standard_ruleset_excludes_repositories
    needs: [org_rulesets]
    when:
      - {ref: steps.org_rulesets.outputs.name, equals: "${standard_ruleset}"}
      - {ref: steps.org_rulesets.outputs.repos_exclude, exists: true}
    provider: github
    args: [graphql, "query($org: String!) { organization(login: $org) { rulesets(first: 1) { nodes { conditions { repositoryName { exclude } } } } } }", "org=${organization}"]
    outputs:
      actual: {pointer: /organization/rulesets/nodes/0/conditions/repositoryName/exclude/0, type: string}

  - id: drift_org_standard_ruleset_not_default_branch
    needs: [org_rulesets]
    when:
      - {ref: steps.org_rulesets.outputs.name, equals: "${standard_ruleset}"}
      - {ref: steps.org_rulesets.outputs.ref_include, not_equals: "~DEFAULT_BRANCH"}
    provider: github
    args: [graphql, "query($org: String!) { organization(login: $org) { rulesets(first: 1) { nodes { conditions { refName { include } } } } } }", "org=${organization}"]
    outputs:
      actual: {pointer: /organization/rulesets/nodes/0/conditions/refName/include/0, type: string, optional: true}

  - id: drift_org_standard_ruleset_targets_no_branches
    needs: [org_rulesets]
    when:
      - {ref: steps.org_rulesets.outputs.name, equals: "${standard_ruleset}"}
      - {ref: steps.org_rulesets.outputs.ref_include, missing: true}
    provider: github
    args: [graphql, "query($org: String!) { organization(login: $org) { rulesets(first: 1) { nodes { conditions { repositoryName { include } refName { include } } } } } }", "org=${organization}"]
    outputs:
      actual: {pointer: /organization/rulesets/nodes/0/conditions/refName/include/0, type: string, optional: true}
  - id: drift_org_standard_deletion_allowed
    needs: [org_rulesets]
    when:
      - {ref: steps.org_rulesets.outputs.name, equals: "${standard_ruleset}"}
      - {ref: steps.org_rulesets.outputs.deletion, not_equals: "1"}
    provider: github
    args: [graphql, "query($org: String!) { organization(login: $org) { rulesets(first: 1) { nodes { rules(first: 1, type: DELETION) { totalCount } } } } }", "org=${organization}"]
    outputs:
      actual: {pointer: /organization/rulesets/nodes/0/rules/totalCount, type: integer}

  - id: drift_org_standard_force_push_allowed
    needs: [org_rulesets]
    when:
      - {ref: steps.org_rulesets.outputs.name, equals: "${standard_ruleset}"}
      - {ref: steps.org_rulesets.outputs.force, not_equals: "1"}
    provider: github
    args: [graphql, "query($org: String!) { organization(login: $org) { rulesets(first: 1) { nodes { rules(first: 1, type: NON_FAST_FORWARD) { totalCount } } } } }", "org=${organization}"]
    outputs:
      actual: {pointer: /organization/rulesets/nodes/0/rules/totalCount, type: integer}

  - id: drift_org_standard_pull_request_off
    needs: [org_rulesets]
    when:
      - {ref: steps.org_rulesets.outputs.name, equals: "${standard_ruleset}"}
      - {ref: steps.org_rulesets.outputs.pr, not_equals: "1"}
    provider: github
    args: [graphql, "query($org: String!) { organization(login: $org) { rulesets(first: 1) { nodes { rules(first: 1, type: PULL_REQUEST) { totalCount } } } } }", "org=${organization}"]
    outputs:
      actual: {pointer: /organization/rulesets/nodes/0/rules/totalCount, type: integer}
```
