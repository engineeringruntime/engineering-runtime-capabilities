# GitHub capabilities

GitHub workflows. Most are read-only. Two sections write to GitHub:
[service lifecycle](#service-lifecycle-writes) and
[rulesets and environments](#rulesets-and-environments-writes). Each file has
one fenced `runtime` block, which Runtime executes; the prose around it is
guidance only.

A capability names a GitHub Provider **operation**, never its transport. The
provider decides whether a step goes over REST, GraphQL or the `gh` CLI:

```yaml
workflow:
  - provider: github
    args: [repo, summary, "${repository}"]
```

## Before you run one

- Configure GitHub authority and check it with `engrt auth status`.
  `ENGRT_GITHUB_TOKEN` is the simplest source; see the installed
  `specs/auth-contract.md` for the others.
- Grant only the permissions the capability needs. Each file says which.
- Install `gh` for operations backed by the CLI. Runtime passes the validated
  token, so `gh auth login` is not required.
- Supply every repository, organization, branch, run or PR input. Runtime
  never infers a target from your current directory.
- `engrt capability validate` checks grammar only. It does not authenticate
  or contact GitHub. Run `engrt capability plan` before `execute`.

`github-release-notes-preview` calls a `POST` endpoint, but that endpoint only
computes notes; it publishes nothing. Apart from the two write sections
below, everything in this directory uses `GET` reads, GraphQL queries or
read-only curated operations.

To try every capability end to end on disposable repositories, see
[`demo/`](../../demo/README.md).

## Repositories

| Capability | What it does |
|---|---|
| [`github-repo-view`](github-repo-view.md) | View a single repository's REST metadata |
| [`github-repo-health`](github-repo-health.md) | Report a repository's health |
| [`github-repo-settings-get`](github-repo-settings-get.md) | Repository settings — the configuration that governs a repo |
| [`github-repo-root-files`](github-repo-root-files.md) | What is at the root of a repository, and in .github |
| [`github-repo-tags`](github-repo-tags.md) | Tags, and what they point at |
| [`github-repo-labels-list`](github-repo-labels-list.md) | List a repository's issue labels |
| [`github-repo-community-profile`](github-repo-community-profile.md) | Which standard files a repository actually has |
| [`github-repo-contributors-and-languages`](github-repo-contributors-and-languages.md) | Who writes this repository, and in what |
| [`repo-topics-review`](repo-topics-review.md) | Report the topics a repository declares |
| [`repo-forks-review`](repo-forks-review.md) | List the forks of a repository |
| [`repo-open-milestones`](repo-open-milestones.md) | Report a repository's open milestones |
| [`github-repository-query`](github-repository-query.md) | GitHub repository query with literal variable binding |

## Discovery

| Capability | What it does |
|---|---|
| [`github-user-get`](github-user-get.md) | Get the authenticated GitHub user |
| [`github-organizations-list`](github-organizations-list.md) | List the authenticated user's organizations |
| [`github-repositories-list`](github-repositories-list.md) | List the authenticated user's repositories |
| [`github-repositories-list-for-org`](github-repositories-list-for-org.md) | List repositories for an organization |
| [`github-teams-list`](github-teams-list.md) | List teams in an organization |
| [`github-notifications-list`](github-notifications-list.md) | List the authenticated user's notifications |
| [`github-issues-list-for-org`](github-issues-list-for-org.md) | List issues across an organization |

## Pull requests

| Capability | What it does |
|---|---|
| [`github-pr-review`](github-pr-review.md) | GitHub pull request review snapshot |
| [`github-pr-status`](github-pr-status.md) | Pull request status — can this merge, and what is holding it |
| [`github-pr-changed-files`](github-pr-changed-files.md) | What a pull request actually changes |
| [`github-pr-commits`](github-pr-commits.md) | The commits behind a pull request |
| [`github-pr-reviews`](github-pr-reviews.md) | Reviews and review comments on a pull request |
| [`github-pr-labels-and-assignees`](github-pr-labels-and-assignees.md) | Labels and assignees on a pull request |
| [`github-pr-review-readiness`](github-pr-review-readiness.md) | Pull-request review readiness |
| [`github-review-queue`](github-review-queue.md) | Review queue — what needs my eyes, and what is going stale |

## GitHub Actions

| Capability | What it does |
|---|---|
| [`github-actions-workflows-inventory`](github-actions-workflows-inventory.md) | Every workflow in a repository, and its state |
| [`github-actions-failed-runs`](github-actions-failed-runs.md) | Recent failed GitHub Actions runs |
| [`github-actions-run-inspect`](github-actions-run-inspect.md) | List recent Actions runs, then inspect one by ID |
| [`github-actions-permissions`](github-actions-permissions.md) | What Actions is allowed to do in this repository |
| [`github-actions-runners-and-cache`](github-actions-runners-and-cache.md) | Runners and cache usage for a repository |
| [`github-ci-failure-triage`](github-ci-failure-triage.md) | CI failure triage — why is the build red? |
| [`github-deployments-and-environments`](github-deployments-and-environments.md) | Repository deployment and environment inventory |

## Governance and security

| Capability | What it does |
|---|---|
| [`github-branch-protection-audit`](github-branch-protection-audit.md) | Branch protection audit — prove main cannot be force-pushed |
| [`github-repo-branches-and-protection`](github-repo-branches-and-protection.md) | Branches and what protects the default one |
| [`github-repo-rulesets-export`](github-repo-rulesets-export.md) | Export a repository's rulesets |
| [`github-repo-codeowners-errors`](github-repo-codeowners-errors.md) | Is CODEOWNERS actually valid |
| [`github-repo-standards-audit`](github-repo-standards-audit.md) | Repository standards audit |
| [`github-security-posture`](github-security-posture.md) | Security posture — open vulnerability alerts for a repository |
| [`github-secrets-inventory`](github-secrets-inventory.md) | Secrets & variables inventory (metadata only) |
| [`github-access-review`](github-access-review.md) | Access review — who can do what |
| [`github-repo-collaborators-list`](github-repo-collaborators-list.md) | Who has access to this repository |

## Standards and drift

Read-only. They report differences; they never fail because a repository
drifted and never change anything.

| Capability | What it does |
|---|---|
| [`repo-standards-drift`](repo-standards-drift.md) | Every way one repository differs from the standard `java-springboot-service-onboard` applies: merge settings, Dependabot, Actions hardening, rulesets, governance files |
| [`org-standards-drift`](org-standards-drift.md) | The organization half: 2FA, repository creation, default permission, new-repository security defaults and an organization standard ruleset |
| [`repo-settings-snapshot`](repo-settings-snapshot.md) | One repository's settings, branches, Actions configuration, access and labels, to compare repositories or before and after a change |

## Releases and incidents

| Capability | What it does |
|---|---|
| [`github-release-latest-and-history`](github-release-latest-and-history.md) | The latest release, and the ones before it |
| [`github-release-readiness`](github-release-readiness.md) | Repository release readiness |
| [`github-release-notes-preview`](github-release-notes-preview.md) | Generate release notes without publishing anything |
| [`github-incident-what-changed`](github-incident-what-changed.md) | Incident forensics — what changed since T |

## Roll-ups

| Capability | What it does |
|---|---|
| [`github-org-health-check`](github-org-health-check.md) | Organization health check |
| [`github-daily-digest`](github-daily-digest.md) | Daily GitHub digest |
| [`github-graphql-contributors-query`](github-graphql-contributors-query.md) | A custom GraphQL query the `graphql` escape hatch covers, that no curated operation does |

## Service lifecycle (writes)

A service's life on GitHub, from creation to retirement, as governed runs.
Each one says what it writes at the top, declares `engrt_version:
">=0.13.0"`, follows **observe → change only when needed → verify**, and is
safe to rerun: a rerun of a completed run writes nothing. Gates stop a run
**before** anything is written. Run `engrt capability plan` first. None of
them deletes anything: the example policy denies `api DELETE`.

| Stage | Capability | What it does |
|---|---|---|
| Create | [`java-springboot-service-onboard`](java-springboot-service-onboard.md) | Creates (or completes) a protected Spring Boot service repository: settings, Dependabot, Actions hardening, `dev`/`staging`/`production` environments, service files and CI, default-branch and release-tag rulesets |
| Adopt | [`repo-governance-standards-pr`](repo-governance-standards-pr.md) | Brings an existing repository up to standard through a pull request with only the missing files; never writes to the default branch |
| Secure | [`repo-security-features-enable`](repo-security-features-enable.md) | Turns on Dependabot alerts and security updates, and on public repositories secret scanning, push protection and private vulnerability reporting; never turns one off |
| Organize | [`repo-labels-standard-sync`](repo-labels-standard-sync.md) | Creates the 12 standard labels and corrects colour and description drift; never deletes or renames |
| Access | [`org-team-repo-access`](org-team-repo-access.md) | Gives a team exactly one permission level on a repository, creating the team when needed |
| Protect | [`repo-environment-protect`](repo-environment-protect.md) | Required reviewer team, no self-review, a wait timer and release-tag deployments on an environment |
| Merge | [`repo-pr-merge-when-ready`](repo-pr-merge-when-ready.md) | Squash-merges one pull request at the reviewed commit, only when GitHub reports it `CLEAN` and the `build` check passed |
| Release | [`repo-release-cut`](repo-release-cut.md) | Publishes a release of one named commit after five gates: green, built by Actions, on the branch, no release blockers, no high or critical Dependabot alerts |
| Deploy | [`repo-deploy-promote`](repo-deploy-promote.md) | Dispatches the deploy workflow for a released version to an environment, only when that environment does not already have it |
| Incident | [`repo-change-freeze`](repo-change-freeze.md) | Freezes the default branch with a ruleset, labels and an incident issue |
| Incident | [`repo-change-freeze-lift`](repo-change-freeze-lift.md) | Disables the freeze ruleset and closes the incident issue with a resolution |
| Retire | [`repo-decommission`](repo-decommission.md) | Archives a repository, refusing while a pull request is open or a workflow is running; never deletes |

The lifecycle capabilities assume the layout onboarding creates: a required
`build` check from GitHub Actions, rulesets named `engrt-onboard-*`, and
environments `dev`, `staging` and `production`. Each file states what it
expects and what it refuses.

## Rulesets and environments (writes)

These change repository configuration. Each one declares `engrt_version:
">=0.13.0"`, says what it writes at the top, and reads back what it wrote. Run
`engrt capability plan` first and execute only against a repository you mean to
change. None of them can delete anything: default policy denies `api DELETE`.

| Capability | What it does | Writes |
|---|---|---|
| [`repo-ruleset-default`](repo-ruleset-default.md) | Adds the `engrt-ruleset-default` branch ruleset on the default branch: no deletion, no force push, changes through a pull request (0 approvals), no bypass actors | `POST` one ruleset; fails cleanly if one with that name exists |
| [`repo-ruleset-default-reconcile`](repo-ruleset-default-reconcile.md) | Converges an existing `engrt-ruleset-default` to that baseline: observe, gated fix, verify per concern | Partial `PUT` only for concerns that drifted; no write when it already matches |
| [`repo-environment-create`](repo-environment-create.md) | Creates or updates a GitHub Actions environment and its deployment branch policy | `PUT` (create-or-update) one environment |
| [`repo-environment-branch-policy-add`](repo-environment-branch-policy-add.md) | Adds one allowed branch or tag pattern to an environment that uses custom branch policies | `POST` one pattern |
| [`repo-environment-variable-set`](repo-environment-variable-set.md) | Creates one environment variable, then reads it back and checks the value | `POST` one variable; create-only |

Typical order for a new deployment environment: `repo-environment-create` with
`custom_branch_policies` on, then `repo-environment-branch-policy-add` for each
pattern, then `repo-environment-variable-set` for each variable. Use
`repo-environment-protect` for required reviewers and a wait timer. Environment
secrets are out of reach: GitHub requires each value to be encrypted on the
client.
