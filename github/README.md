# GitHub Capabilities

Every capability in this folder is a Markdown file with an embedded
` ```runtime ` workflow block, authored against:

- `specs/capability-spec.md` (generic grammar/rules), and
- `specs/github/capability-spec-github.md` (what's actually registered
  for GitHub)

from `engineering-runtime-samples` / `engineering-runtime`. The runtime
never executes the Markdown around the block — only the fenced block
itself; everything else exists for humans and AI to read.

All commands here require the `github` Auth Engine provider
(`RUNTIME_GITHUB_TOKEN` set and valid). Anything using `command.run`
with `binary: gh` additionally requires `gh` installed, authenticated,
and present in `allowed_binaries` (see `policy-config.yaml`).

## One Runtime Command per capability

Every `github.*` Runtime Command in the registry (`internal/commands`)
has a matching single-step capability here:

| Capability file | Runtime Command | Inputs |
|---|---|---|
| `github-user-get.md` | `github.user.get` | none |
| `github-organizations-list.md` | `github.organizations.list` | none |
| `github-notifications-list.md` | `github.notifications.list` | none |
| `github-repositories-list.md` | `github.repositories.list` | none |
| `github-repositories-list-for-org.md` | `github.repositories.list_for_org` | none (org from Runtime Context) |
| `github-repositories-create.md` | `github.repositories.create` | `name`, `private`, `description` |
| `github-issues-list-for-org.md` | `github.issues.list_for_org` | none (org from Runtime Context) |
| `github-teams-list.md` | `github.teams.list` | none (org from Runtime Context) |

## Generic `github.request` pass-through

Parameterized workflows for when the fixed convenience commands above
aren't enough (e.g. targeting an org other than the active context's,
or operating on a specific repo):

| Capability file | Request | Inputs |
|---|---|---|
| `github-request-list-org-repos.md` | `GET /orgs/{org}/repos` | `organization` |
| `github-request-list-repo-issues.md` | `GET /repos/{owner}/{repo}/issues` | `owner`, `repo`, `state` |
| `github-request-create-issue.md` | `POST /repos/{owner}/{repo}/issues` | `owner`, `repo`, `title`, `body` |
| `github-request-update-repo.md` | `PATCH /repos/{owner}/{repo}` | `owner`, `repo`, `description` |

## GitHub CLI (`gh`) via the Command Engine

Raw Command Engine invocations — validated against `allowed_binaries`
and `command_policy`, not the Runtime Command registry:

| Capability file | `gh` subcommand | Inputs |
|---|---|---|
| `github-cli-repo-list.md` | `repo list --limit <n>` | `limit` |
| `github-cli-pr-list.md` | `pr list` | none |
| `github-cli-issue-create.md` | `issue create --title <t> --body <b>` | `title`, `body` |

## Composite workflows

Multi-step capabilities mixing Runtime Commands and/or `command.run`:

| Capability file | Steps |
|---|---|
| `github-org-health-check.md` | `organizations.list` -> `repositories.list_for_org` -> `teams.list` -> `issues.list_for_org` |
| `github-org-repos-and-open-prs.md` | `github.request GET /orgs/${organization}/repos` -> `gh pr list` |
| `github-repo-bootstrap.md` | `github.repositories.create` -> `gh repo list --limit ${limit}` |
| `github-daily-digest.md` | `notifications.list` -> `issues.list_for_org` -> `gh pr list` |

## Validating everything in this folder

```bash
for f in github/*.md; do
  runtime capability validate "$f"
done
```

Validation only guarantees a capability is well-formed and references
things this runtime version can actually run — it does not guarantee a
step will succeed at execution (missing credentials, a denied
`command_policy` rule, or a network error can still fail a step).
