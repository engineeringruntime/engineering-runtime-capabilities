# Access review — who can do what

Produce least-privilege evidence for an org/team/repo: org admins, outside
collaborators, pending invitations, one team's members and repos, a
repository's direct collaborators and teams, plus that user's effective
permission on the repo. Read-only — default policy denies `api DELETE`, so
revocation stays a separate, deliberate action.

`team list` is the curated op; everything else is the REST escape hatch
against endpoints no curated operation covers yet.

Org-scoped GETs use the `organization` input (do not hardcode an org).
Team/repo-scoped steps need their own inputs.

Requires `RUNTIME_GITHUB_TOKEN` with org admin / repo admin read on the
targets (outside collaborators and invitations especially).

Run with:

```
runtime capability validate capabilities/github/github-access-review.md

runtime capability execute capabilities/github/github-access-review.md \
  --input organization=acme \
  --input team_slug=platform \
  --input repository=acme/payments-api \
  --input username=alice
```

```runtime
version: v1

inputs:
  organization:
    description: GitHub organization to review
    required: true
  team_slug:
    description: Team slug whose members and repos to list
    required: true
  repository:
    description: Repository as <owner>/<repo> for collaborator evidence
    required: true
  username:
    description: Login whose effective permission on the repository to report
    required: true

workflow:
  - provider: github
    args: [team, list]

  - provider: github
    args: [api, GET, "/orgs/${organization}/members", "role=admin", "per_page=100"]

  - provider: github
    args: [api, GET, "/orgs/${organization}/outside_collaborators", "per_page=100"]

  - provider: github
    args: [api, GET, "/orgs/${organization}/invitations"]

  - provider: github
    args: [api, GET, "/orgs/${organization}/teams/${team_slug}/members"]

  - provider: github
    args: [api, GET, "/orgs/${organization}/teams/${team_slug}/repos"]

  - provider: github
    args: [api, GET, "/repos/${repository}/collaborators", "affiliation=direct"]

  - provider: github
    args: [api, GET, "/repos/${repository}/teams"]

  - provider: github
    args: [api, GET, "/repos/${repository}/collaborators/${username}/permission"]
```
