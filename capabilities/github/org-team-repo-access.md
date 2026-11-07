# Give a team a permission level on a repository, creating the team if needed

> **Mutating.** It can create an organization team and set a team's
> permission on a repository. It never removes a team, a member or a
> repository's access. Run `plan` first.

Access is granted to teams, never to individuals, so it can be reviewed in
one place. This sets one team's permission on one repository to exactly the
level asked for, raising **or lowering** it, and proves the result.

| Step | Does |
|---|---|
| `team_observe` | looks the team up by slug (a missing team reads as `null`, not an error) |
| `team_create` | only when absent: creates it as a visible (`closed`) team |
| `team_verify` | the team exists, with that slug, visible |
| `team_lookup` | reads the team's id for the access steps |
| `access_observe` | reads the team's permission on the repository |
| `access_grant` / `access_change` | only when the team has no access, or a different level |
| `access_verify` | the team's permission on the repository is exactly `permission` |

Permission levels use GitHub's GraphQL names, the same on read and write:

| `permission` | GitHub UI | Allows |
|---|---|---|
| `READ` | Read | clone, open issues |
| `TRIAGE` | Triage | manage issues and pull requests, no code |
| `WRITE` | Write | push branches (protected branches still follow the rulesets) |
| `MAINTAIN` | Maintain | manage the repository without settings or security access |
| `ADMIN` | Admin | everything, including settings |

| Run | Result |
|---|---|
| new team | team created, access granted, both verified (`APPLIED`) |
| rerun | nothing written (`SATISFIED`) |
| team's level changed by hand | set back to `permission` (`RECONCILED`) |

## What it needs

- Policy: the GitHub provider with `graphql` and `api POST`.
- Credential: organization Members read/write and repository Administration
  read/write (an organization owner, or a token with `admin:org` and `repo`).

## Known limits

- **No undo through Runtime.** Removing a team's access or deleting a team
  needs `DELETE`, which the example policy denies. To take
  access away, lower it to `READ`.
- `team` must be a lowercase slug (`platform-team`). GitHub derives the slug
  from the name, and `team_verify` compares them.
- **Team members are not managed here.** GitHub makes the creator a
  maintainer of a new team; add people in the organization's own process.
- `access_observe` finds the repository by GitHub's name search within the
  team's repositories, sorted by name. If another repository whose name
  contains `repository` sorts first (`a-payments` before `payments`),
  `access_verify` fails rather than report the wrong repository.

## Run it

```bash
engrt capability plan github/org-team-repo-access \
  --input organization=<organization> --input team=platform-team \
  --input description="Platform engineering" \
  --input repository=<repository> --input permission=MAINTAIN
```

```runtime
version: v1
capability_version: "1.0.0"
engrt_version: ">=0.13.0"

inputs:
  organization:
    description: GitHub organization
    required: true
  team:
    description: Team slug, lowercase with hyphens, e.g. platform-team
    required: true
  description:
    description: Team description, used only when the team is created
    required: true
  repository:
    description: Repository name without the owner
    required: true
  permission:
    description: "READ, TRIAGE, WRITE, MAINTAIN or ADMIN"
    required: true

workflow:
  # ==== Team ====
  - id: team_observe
    provider: github
    args: [graphql, "query($org: String!, $slug: String!) { organization(login: $org) { team(slug: $slug) { slug } } }", "org=${organization}", "slug=${team}"]
    outputs:
      slug: {pointer: /organization/team/slug, type: string, optional: true}

  - id: team_create
    needs: [team_observe]
    when: [{ref: steps.team_observe.outputs.slug, missing: true}]
    provider: github
    args: [api, POST, "/orgs/${organization}/teams", "name=${team}", "description=${description}", "privacy=closed"]

  - id: team_verify
    needs: [team_create]
    provider: github
    args: [graphql, "query($org: String!, $slug: String!) { organization(login: $org) { team(slug: $slug) { slug privacy } } }", "org=${organization}", "slug=${team}"]
    outputs:
      slug: {pointer: /organization/team/slug, type: string, optional: true}
      privacy: {pointer: /organization/team/privacy, type: string, optional: true}
    expect:
      - {ref: steps.team_verify.outputs.slug, equals: "${team}"}
      - {ref: steps.team_verify.outputs.privacy, equals: VISIBLE}

  # A verification step cannot be the dependency of another verification step,
  # so the team's node id is read once more by a plain step for the steps below.
  - id: team_lookup
    needs: [team_verify]
    provider: github
    args: [graphql, "query($org: String!, $slug: String!) { organization(login: $org) { team(slug: $slug) { id } } }", "org=${organization}", "slug=${team}"]
    outputs:
      id: {pointer: /organization/team/id, type: string}

  # ==== Team access to the repository ====
  - id: access_observe
    needs: [team_lookup]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $team: ID!) { repository(owner: $owner, name: $name) { id } node(id: $team) { ... on Team { repositories(query: $name, first: 1, orderBy: {field: NAME, direction: ASC}) { edges { permission node { name } } } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "team=${steps.team_lookup.outputs.id}"
    outputs:
      repository_id: {pointer: /repository/id, type: string}
      name: {pointer: /node/repositories/edges/0/node/name, type: string, optional: true}
      permission: {pointer: /node/repositories/edges/0/permission, type: string, optional: true}

  - id: access_grant
    needs: [team_lookup, access_observe]
    when: [{ref: steps.access_observe.outputs.name, missing: true}]
    provider: github
    args:
      - graphql
      - "mutation($repo: ID!, $team: ID!, $permission: RepositoryPermission!) { updateTeamsRepository(input: {repositoryId: $repo, teamIds: [$team], permission: $permission}) { repository { name } } }"
      - "repo=${steps.access_observe.outputs.repository_id}"
      - "team=${steps.team_lookup.outputs.id}"
      - "permission=${permission}"

  - id: access_change
    needs: [team_lookup, access_observe]
    when:
      - {ref: steps.access_observe.outputs.name, equals: "${repository}"}
      - {ref: steps.access_observe.outputs.permission, not_equals: "${permission}"}
    provider: github
    args:
      - graphql
      - "mutation($repo: ID!, $team: ID!, $permission: RepositoryPermission!) { updateTeamsRepository(input: {repositoryId: $repo, teamIds: [$team], permission: $permission}) { repository { name } } }"
      - "repo=${steps.access_observe.outputs.repository_id}"
      - "team=${steps.team_lookup.outputs.id}"
      - "permission=${permission}"

  - id: access_verify
    needs: [team_lookup, access_grant, access_change]
    provider: github
    args:
      - graphql
      - "query($name: String!, $team: ID!) { node(id: $team) { ... on Team { repositories(query: $name, first: 1, orderBy: {field: NAME, direction: ASC}) { edges { permission node { name } } } } } }"
      - "name=${repository}"
      - "team=${steps.team_lookup.outputs.id}"
    outputs:
      name: {pointer: /node/repositories/edges/0/node/name, type: string, optional: true}
      permission: {pointer: /node/repositories/edges/0/permission, type: string, optional: true}
    expect:
      - {ref: steps.access_verify.outputs.name, equals: "${repository}"}
      - {ref: steps.access_verify.outputs.permission, equals: "${permission}"}
```
