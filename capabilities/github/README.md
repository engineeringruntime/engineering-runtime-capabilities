# GitHub capabilities

Read-only GitHub workflows. Each file has one fenced `runtime` block, which
Runtime executes; the prose around it is guidance only.

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
computes notes; it publishes nothing. Everything else in this directory uses
`GET` reads or read-only curated operations.

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
