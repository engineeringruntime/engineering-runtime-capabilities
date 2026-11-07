# Snapshot one repository's settings, access and Actions configuration

Read-only. Captures what a repository is configured to do, so two
repositories can be compared, or one repository can be compared before and
after a change. Useful before running any mutating capability against a
repository.

## What it reads

| Step | Endpoint | Shows |
|---|---|---|
| `repo` | `repo view` | merge methods, features, visibility, default branch |
| `branches` | `GET /repos/{o}/{r}/branches` | branches and whether each is protected |
| `actions` | `GET /repos/{o}/{r}/actions/permissions` | whether Actions is enabled and which actions are allowed |
| `workflow_token` | `GET /repos/{o}/{r}/actions/permissions/workflow` | default `GITHUB_TOKEN` permissions |
| `teams` | `GET /repos/{o}/{r}/teams` | team access |
| `collaborators` | `GET /repos/{o}/{r}/collaborators` | direct and outside collaborators |
| `labels` | `GET /repos/{o}/{r}/labels` | label set |
| `workflows` | `workflow list --repo` | Actions workflows (cli) |

Two reads are left out because they can stop a fail-fast run:

- **Rulesets** (`GET …/rulesets`) return `403` on private repositories on some GitHub plans.
- **Community profile** (`GET …/community/profile`) applies only to public repositories.

To check a repository against a standard rather than compare snapshots, use
[repo-standards-drift](repo-standards-drift.md).

## Run it

```bash
engrt capability execute capabilities/github/repo-settings-snapshot.md \
  --input organization=<organization> --input repository=<repository>
```

```runtime
version: v1
capability_version: "1.0.0"
engrt_version: ">=0.10.0"

inputs:
  organization:
    description: GitHub organization
    required: true
  repository:
    description: Repository name without the owner
    required: true

workflow:
  - id: repo
    provider: github
    args: [repo, view, "${organization}/${repository}"]

  - id: branches
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/branches", "per_page=100"]

  - id: actions
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions"]

  - id: workflow_token
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions/workflow"]

  - id: teams
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/teams"]

  - id: collaborators
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/collaborators", "affiliation=all", "per_page=100"]

  - id: labels
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/labels", "per_page=100"]

  - id: workflows
    provider: github
    args: [workflow, list, --repo, "${organization}/${repository}"]
```
