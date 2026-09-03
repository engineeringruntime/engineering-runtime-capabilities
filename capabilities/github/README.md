# GitHub capabilities

This directory contains reusable GitHub workflows executed by Engineering
Runtime. Each Markdown file has one fenced `runtime` block; Runtime executes
that block and treats the surrounding prose as guidance only.

## Runtime contract

Author against the contracts installed by the Runtime version you will use:

- [`specs/capability-spec.md`](../../../engineering-runtime/specs/capability-spec.md)
- [`specs/github/capability-spec-github.md`](../../../engineering-runtime/specs/github/capability-spec-github.md)

Runtime 0.9.3 exposes 20 GitHub Provider operations across REST, GraphQL, and
the pinned `gh` CLI transport. Every operation has at least one example in this
directory. Confirm the installed surface instead of copying this count:

```bash
runtime github --help
runtime --output json capability authoring-context
```

A capability names an operation, never its transport:

```yaml
workflow:
  - provider: github
    args: [repo, summary, "${repository}"]
```

Prefer `provider: github`. Use `binary: gh` only to demonstrate or reach a
command the provider does not expose. Raw `gh` is context-unsupported for
general Command Engine execution because it can infer both repository and host;
the curated GitHub Provider pins it when it selects the CLI transport.

## Requirements

- Set `RUNTIME_GITHUB_TOKEN`; verify it with `runtime auth status`.
- Grant only the GitHub permissions required by the capability being run.
- Install `gh` for provider operations backed by the CLI. Runtime passes the
  validated token as `GH_TOKEN`; `gh auth login` is not required.
- Supply every required repository, organization, branch, run, or PR input.
  Runtime owns no GitHub context document and never invents a target.
- Plan before execution. Validation checks grammar and operation names; it does
  not authenticate, contact GitHub, or prove the workflow will succeed.

## Catalog — 76 capabilities

### Identity and organization discovery

- [`github-user-get.md`](./github-user-get.md)
- [`github-organizations-list.md`](./github-organizations-list.md)
- [`github-notifications-list.md`](./github-notifications-list.md)
- [`github-teams-list.md`](./github-teams-list.md)
- [`github-issues-list-for-org.md`](./github-issues-list-for-org.md)
- [`github-repositories-list.md`](./github-repositories-list.md)
- [`github-repositories-list-for-org.md`](./github-repositories-list-for-org.md)
- [`github-repositories.md`](./github-repositories.md)
- [`github-org-health-check.md`](./github-org-health-check.md)
- [`github-org-repos-and-open-prs.md`](./github-org-repos-and-open-prs.md)
- [`github-daily-digest.md`](./github-daily-digest.md)

### Repository inventory and governance

- [`github-access-review.md`](./github-access-review.md)
- [`github-branch-protection-audit.md`](./github-branch-protection-audit.md)
- [`github-repo-branches-and-protection.md`](./github-repo-branches-and-protection.md)
- [`github-repo-codeowners-errors.md`](./github-repo-codeowners-errors.md)
- [`github-repo-collaborators-list.md`](./github-repo-collaborators-list.md)
- [`github-repo-community-profile.md`](./github-repo-community-profile.md)
- [`github-repo-contributors-and-languages.md`](./github-repo-contributors-and-languages.md)
- [`github-repo-health.md`](./github-repo-health.md)
- [`github-repo-labels-list.md`](./github-repo-labels-list.md)
- [`github-repo-root-files.md`](./github-repo-root-files.md)
- [`github-repo-rulesets-export.md`](./github-repo-rulesets-export.md)
- [`github-repo-settings-get.md`](./github-repo-settings-get.md)
- [`github-repo-standards-audit.md`](./github-repo-standards-audit.md)
- [`github-repo-tags.md`](./github-repo-tags.md)
- [`github-repo-view.md`](./github-repo-view.md)
- [`github-repository-visibility.md`](./github-repository-visibility.md)
- [`repo-forks-review.md`](./repo-forks-review.md)
- [`repo-open-milestones.md`](./repo-open-milestones.md)
- [`repo-topics-review.md`](./repo-topics-review.md)
- [`github-secrets-inventory.md`](./github-secrets-inventory.md)
- [`github-security-posture.md`](./github-security-posture.md)

### Repository changes and onboarding

These workflows mutate GitHub or push Git commits. Review their inputs and plan
output before separately authorizing execution.

- [`github-repositories-create.md`](./github-repositories-create.md)
- [`github-repo-archive.md`](./github-repo-archive.md)
- [`github-repo-bootstrap.md`](./github-repo-bootstrap.md)
- [`github-repo-default-branch-set.md`](./github-repo-default-branch-set.md)
- [`github-repo-description-set.md`](./github-repo-description-set.md)
- [`github-repo-features-enforce.md`](./github-repo-features-enforce.md)
- [`github-repo-merge-policy-enforce.md`](./github-repo-merge-policy-enforce.md)
- [`github-service-onboarding.md`](./github-service-onboarding.md)
- [`github-file-push.md`](./github-file-push.md)
- [`github-file-update.md`](./github-file-update.md)
- [`github-git-clone-commit-push.md`](./github-git-clone-commit-push.md)

### Pull requests, issues, and review

- [`github-ci-failure-triage.md`](./github-ci-failure-triage.md)
- [`github-incident-what-changed.md`](./github-incident-what-changed.md)
- [`github-issue-create-and-list.md`](./github-issue-create-and-list.md)
- [`github-pr-changed-files.md`](./github-pr-changed-files.md)
- [`github-pr-commits.md`](./github-pr-commits.md)
- [`github-pr-labels-and-assignees.md`](./github-pr-labels-and-assignees.md)
- [`github-pr-open-and-inspect.md`](./github-pr-open-and-inspect.md)
- [`github-pr-review-readiness.md`](./github-pr-review-readiness.md)
- [`github-pr-reviews.md`](./github-pr-reviews.md)
- [`github-pr-status.md`](./github-pr-status.md)
- [`github-review-queue.md`](./github-review-queue.md)

### Actions and deployments

- [`github-actions-failed-runs.md`](./github-actions-failed-runs.md)
- [`github-actions-permissions.md`](./github-actions-permissions.md)
- [`github-actions-run-artifacts.md`](./github-actions-run-artifacts.md)
- [`github-actions-run-inspect.md`](./github-actions-run-inspect.md)
- [`github-actions-run-rerun-failed.md`](./github-actions-run-rerun-failed.md)
- [`github-actions-runners-and-cache.md`](./github-actions-runners-and-cache.md)
- [`github-actions-workflow-toggle.md`](./github-actions-workflow-toggle.md)
- [`github-actions-workflows-inventory.md`](./github-actions-workflows-inventory.md)
- [`github-deployments-and-environments.md`](./github-deployments-and-environments.md)
- [`github-workflow-dispatch-and-list.md`](./github-workflow-dispatch-and-list.md)

### Releases

- [`github-release-assets.md`](./github-release-assets.md)
- [`github-release-cut.md`](./github-release-cut.md)
- [`github-release-latest-and-history.md`](./github-release-latest-and-history.md)
- [`github-release-notes-preview.md`](./github-release-notes-preview.md)
- [`github-release-readiness.md`](./github-release-readiness.md)

### REST, GraphQL, and raw-CLI reference examples

These files deliberately demonstrate escape hatches or older equivalent paths.
Prefer a curated operation when it covers the same outcome.

- [`github-graphql-contributors-query.md`](./github-graphql-contributors-query.md)
- [`github-request-create-issue.md`](./github-request-create-issue.md)
- [`github-request-list-org-repos.md`](./github-request-list-org-repos.md)
- [`github-request-list-repo-issues.md`](./github-request-list-repo-issues.md)
- [`github-request-update-repo.md`](./github-request-update-repo.md)
- [`github-cli-issue-create.md`](./github-cli-issue-create.md)
- [`github-cli-pr-list.md`](./github-cli-pr-list.md)
- [`github-cli-repo-list.md`](./github-cli-repo-list.md)

`github-cli-repo-list.md` is the first admitted raw `gh` semantic mode. The
other raw-CLI examples remain design/reference material and are denied through
`runtime command run gh` until their auth/context/cwd modes are registered;
their equivalent curated Provider operations remain supported.

## Run and verify

Use an exact path or a name resolved from the configured capability source:

```bash
runtime capability validate capabilities/github/github-repo-health.md
runtime capability plan capabilities/github/github-repo-health.md \
  --input repository=cli/cli
runtime --output json capability execute \
  capabilities/github/github-repo-health.md \
  --input repository=cli/cli
```

Validate the entire GitHub catalog:

```bash
for file in capabilities/github/*.md; do
  [ "$(basename "$file")" = README.md ] && continue
  runtime capability validate "$file"
done
```

Some CLI-backed operations can resolve a repository from the current working
directory, but new capabilities should pass `--repo <owner>/<repo>` whenever
the upstream `gh` command supports it. Explicit targets make plans and audit
records portable and reviewable.
