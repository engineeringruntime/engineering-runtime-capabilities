# GitHub Capabilities

Every capability in this folder is a Markdown file with an embedded
` ```runtime ` workflow block, authored against the specs that ship with
the runtime binary (sibling repo `engineering-runtime/`, or
`runtime-home/specs/` after `runtime bootstrap`):

- [`specs/capability-spec.md`](../../../engineering-runtime/specs/capability-spec.md) — the generic grammar and rules
- [`specs/github/capability-spec-github.md`](../../../engineering-runtime/specs/github/capability-spec-github.md) — the GitHub Provider's operations

The runtime never executes the Markdown around the block — only the fenced
block itself; everything else exists for humans and AI to read.

## What a step looks like

A step names an **operation**, never a transport:

```yaml
workflow:
  - provider: github
    args: [repo, list, "${organization}"]

  - binary: gh                    # escape hatch, for what the provider doesn't expose
    args: [release, upload, "v1.0.0", "./dist/runtime"]
```

Whether `repo list` reaches GitHub over REST, GraphQL, or the `gh` CLI is
the **GitHub Provider's** decision, not the capability's. That is what lets
an operation change transport in a later runtime version without breaking
any file here. See
[`docs/04-design-decisions/adr-005-provider-layer.md`](../../../engineering-runtime/docs/04-design-decisions/adr-005-provider-layer.md).

Run `runtime github --help` for the live operation surface, including the
transport chosen for each operation.

## Requirements

All capabilities here authenticate as the `github` Auth Engine provider —
`RUNTIME_GITHUB_TOKEN` must be set and valid (`runtime auth status`).

Capabilities with a `binary: gh` step additionally need `gh` installed and
listed in `allowed_binaries` (`policy-config.yaml`). **`gh auth login` is
not required** — the Command Engine forwards the validated token as
`GH_TOKEN`.

## Index

| Capability | Operations used | Inputs |
|---|---|---|
| `github-user-get.md` | `user get` | — |
| `github-organizations-list.md` | `org list` | — |
| `github-notifications-list.md` | `notification list` | — |
| `github-teams-list.md` | `team list` | `organization` |
| `github-issues-list-for-org.md` | `issue list` | `organization` |
| `github-repositories-list.md` | `repo list` | — |
| `github-repositories-list-for-org.md` | `repo list` | `organization` |
| `github-repositories-create.md` | `repo create` | `name`, `private`, `description` |
| `github-repositories.md` | `repo list`, `pr list` | `organization` |
| `github-repo-health.md` | `repo summary`, `pr list`, `run list` | `repository` |
| `github-repo-bootstrap.md` | `repo create` + `gh repo list` | `name`, `private`, `description`, `limit` |
| `github-org-health-check.md` | `org list`, `repo list`, `team list`, `issue list` | `organization` |
| `github-org-repos-and-open-prs.md` | `api GET /orgs/{org}/repos` + `gh pr list` | `organization` |
| `github-daily-digest.md` | `notification list`, `issue list` + `gh pr list` | — |
| `github-request-list-org-repos.md` | `api GET /orgs/{org}/repos` | `organization` |
| `github-request-list-repo-issues.md` | `api GET /repos/{owner}/{repo}/issues` | `owner`, `repo`, `state` |
| `github-request-create-issue.md` | `api POST /repos/{owner}/{repo}/issues` | `owner`, `repo`, `title`, `body` |
| `github-request-update-repo.md` | `api PATCH /repos/{owner}/{repo}` | `owner`, `repo`, `description` |
| `github-file-push.md` | `api PUT /repos/{repo}/contents/{path}` | `repository`, `path`, `message`, `content_base64` |
| `github-file-update.md` | `api GET` + `api PUT /repos/{repo}/contents/{path}` | `repository`, `path`, `message`, `content_base64`, `sha` |
| `github-git-clone-commit-push.md` | `git clone/add/commit/push` (raw binary) + `files write` | `repository_url`, `workdir`, `path`, `content`, `message` |
| `github-repo-view.md` | `repo view` | `repository` |
| `github-issue-create-and-list.md` | `issue create`, `issue list` | `organization`, `title`, `body` |
| `github-pr-open-and-inspect.md` | `pr create`, `pr view` | `title`, `body`, `number` |
| `github-workflow-dispatch-and-list.md` | `workflow run`, `workflow list` | `workflow`, `ref` |
| `github-actions-run-inspect.md` | `run list`, `run view` | `run_id` |
| `github-graphql-contributors-query.md` | `graphql` (escape hatch) | `owner`, `name` |
| `github-cli-repo-list.md` | `gh repo list` (raw binary) | `limit` |
| `github-cli-pr-list.md` | `gh pr list` (raw binary) | — |
| `github-cli-issue-create.md` | `gh issue create` (raw binary) | `title`, `body` |

`github-repo-health.md` is the clearest illustration of the model: its three
steps are served by **two different transports** (GraphQL, then the `gh`
CLI twice) and the file names neither.

Every operation in `specs/github/capability-spec-github.md`'s table now has
at least one checked-in `provider: github` example somewhere in this
folder — `github-repo-view.md`, `github-issue-create-and-list.md`,
`github-pr-open-and-inspect.md`, `github-workflow-dispatch-and-list.md`,
`github-actions-run-inspect.md` and `github-graphql-contributors-query.md`
were added specifically to close the gap on `repo view`, `issue create`
(as a curated operation, not just the `github-cli-issue-create.md` raw
escape hatch), `pr view`, `pr create`, `workflow list`, `workflow run`,
`run view`, and the raw `graphql` escape hatch respectively.

Several of the `gh`-backed operations above (`pr create`, `workflow run`,
`workflow list`, `run list`, `run view`) resolve their repository from the
**working directory** `gh` runs in, the same way `github-cli-pr-list.md`
already does — they are not given a `repository` input, and running them
from the wrong directory fails at `gh`, not at the runtime. Each capability
file says so explicitly where it applies.

## Known overlap worth cleaning up

These files predate the Provider layer. They all validate and run, but the
set now has visible redundancy:

- **`github-repositories-list.md` and `github-repositories-list-for-org.md`
  are identical.** They came from two registry commands
  (`github.repositories.list` → `/user/repos`,
  `github.repositories.list_for_org` → `/orgs/{org}/repos`) that the provider
  collapsed into one operation: `repo list` uses the active Runtime Context's
  org when there is one and falls back to your own repos otherwise. One of
  the two can go.
- **`github-request-list-org-repos.md` duplicates `repo list <org>`** through
  the `api` escape hatch. Prefer the curated operation; the escape hatch is
  for endpoints no operation covers.
- **The `github-cli-*.md` files pin a transport** by using `binary: gh`
  directly. That cuts against the guidance above — `github-cli-pr-list.md`
  and a `pr list` operation step reach the same place, except the curated
  operation lets the provider decide. Useful as demonstrations of the raw
  escape hatch; not a pattern to copy for real work.

## Running them

```bash
runtime capability validate capabilities/github/github-repo-health.md
runtime capability execute  capabilities/github/github-repo-health.md --input repository=cli/cli

# machine-readable, every step
runtime --output json capability execute capabilities/github/github-repo-health.md --input repository=cli/cli
```

Validation resolves every `provider` step against the provider's real
operation surface, so a capability naming an operation this runtime version
doesn't have fails before anything executes.

Validate the whole folder at once:

```bash
for f in capabilities/github/*.md; do
  [ "$(basename "$f")" = README.md ] && continue
  runtime capability validate "$f"
done
```
