# Require approval and a wait before anything deploys to an environment

> **Mutating.** It sets an environment's required reviewers, wait timer and
> self-review rule, and allows release tags to deploy. It never removes an
> environment or a reviewer team. Run `plan` first.

Onboarding creates `dev`, `staging` and `production` and limits `staging` and
`production` to `main`. This adds the controls a production environment
needs before anyone can deploy:

| Control | Set to |
|---|---|
| Required reviewers | the `reviewer_team` (a team, never a person) |
| Prevent self-review | on: whoever started the deployment cannot approve it |
| Wait timer | `wait_timer` minutes after approval |
| Deployment branches and tags | `main` (from onboarding) and release tags `v*` |

`repo-deploy-promote` deploys a release from its tag, so the environment must
accept `v*` tags as well as `main`.

**Order-independent.** GitHub returns an environment's protection rules as a
list in an order it does not document. GitHub allows one rule of each type
(branch policy, wait timer, required reviewers), so the capability:

1. treats three rules as "each type exactly once";
2. checks each list position against the rule type found there;
3. verifies the count is 3, then checks whichever position holds the wait
   timer and the reviewers, each aspect as its own logical operation.

Rules in an unexpected shape fail verification; they never pass by accident.

| Run | Result |
|---|---|
| environment from onboarding | reviewers, timer and tag policy set and verified (`APPLIED`) |
| rerun | nothing written (`SATISFIED`) |
| reviewer team or timer changed by hand | set back (`RECONCILED`) |
| environment or reviewer team missing | stops at `env_lookup` or `reviewer_gate`; nothing written |

## What it needs

- Policy: the GitHub provider with `graphql`, `api GET` and `api POST`.
- Credential: repository Administration read/write; organization Members
  read (to resolve the team).
- **A public repository, or GitHub Enterprise.** On private repositories
  GitHub offers required reviewers and wait timers only with GitHub
  Enterprise; on GitHub Team the update is refused.
- An environment with its deployment branch policy, as
  [java-springboot-service-onboard](java-springboot-service-onboard.md)
  creates. Without one there are only two rules, and the run fails
  verification on every attempt.

## Known limits

- One update per drifted aspect (rule count, wait timer, reviewer team,
  self-review): each is its own logical operation, because Runtime allows one
  write per operation (a second is refused as `conflict`) and the grammar has
  no OR. Several aspects
  drifting at once means several identical updates; a rerun writes nothing.
- One reviewer team. Additional reviewers set by hand are replaced.
- Administrators can still bypass the rules (`can_admins_bypass`); turning that
  off needs the REST environment `PUT`, whose reviewer list takes a typed
  step reference that `plan` currently misreports.
- The tag policy is added only when the environment has exactly one policy,
  `main`. Other layouts are left alone and fail `tag_policy_verify`.

## Run it

```bash
engrt capability plan github/repo-environment-protect \
  --input organization=<organization> --input repository=<repository> \
  --input environment=production --input reviewer_team=platform-team \
  --input wait_timer=5
```

```runtime
version: v1
capability_version: "1.0.0"
engrt_version: ">=0.13.0"

inputs:
  organization:
    description: GitHub organization that owns the repository
    required: true
  repository:
    description: Repository name without the owner
    required: true
  environment:
    description: Environment name, e.g. production
    required: true
  reviewer_team:
    description: Slug of the team that must approve deployments, e.g. platform-team
    required: true
  wait_timer:
    description: Minutes to wait after approval before the deployment proceeds (1-43200)
    required: true

workflow:
  # ==== Reviewer team ====
  - id: reviewer_gate
    provider: github
    args: [graphql, "query($org: String!, $slug: String!) { organization(login: $org) { team(slug: $slug) { slug } } }", "org=${organization}", "slug=${reviewer_team}"]
    outputs:
      slug: {pointer: /organization/team/slug, type: string, optional: true}
    expect:
      - {ref: steps.reviewer_gate.outputs.slug, equals: "${reviewer_team}"}

  - id: reviewer_lookup
    needs: [reviewer_gate]
    provider: github
    args: [graphql, "query($org: String!, $slug: String!) { organization(login: $org) { team(slug: $slug) { id } } }", "org=${organization}", "slug=${reviewer_team}"]
    outputs:
      id: {pointer: /organization/team/id, type: string}

  # ==== Environment (must exist; GitHub answers an error for a missing one) ====
  - id: env_lookup
    provider: github
    args: [graphql, "query($owner: String!, $name: String!, $env: String!) { repository(owner: $owner, name: $name) { environment(name: $env) { id } } }", "owner=${organization}", "name=${repository}", "env=${environment}"]
    outputs:
      id: {pointer: /repository/environment/id, type: string}

  - id: env_observe
    needs: [env_lookup]
    provider: github
    args: [graphql, "query($env: ID!) { node(id: $env) { ... on Environment { protectionRules(first: 5) { totalCount nodes { type timeout preventSelfReview reviewers(first: 1) { nodes { ... on Team { slug } } } } } } } }", "env=${steps.env_lookup.outputs.id}"]
    outputs:
      total: {pointer: /node/protectionRules/totalCount, type: integer}
      type_0: {pointer: /node/protectionRules/nodes/0/type, type: string, optional: true}
      timeout_0: {pointer: /node/protectionRules/nodes/0/timeout, type: integer, optional: true}
      team_0: {pointer: /node/protectionRules/nodes/0/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_0: {pointer: /node/protectionRules/nodes/0/preventSelfReview, type: boolean, optional: true}
      type_1: {pointer: /node/protectionRules/nodes/1/type, type: string, optional: true}
      timeout_1: {pointer: /node/protectionRules/nodes/1/timeout, type: integer, optional: true}
      team_1: {pointer: /node/protectionRules/nodes/1/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_1: {pointer: /node/protectionRules/nodes/1/preventSelfReview, type: boolean, optional: true}
      type_2: {pointer: /node/protectionRules/nodes/2/type, type: string, optional: true}
      timeout_2: {pointer: /node/protectionRules/nodes/2/timeout, type: integer, optional: true}
      team_2: {pointer: /node/protectionRules/nodes/2/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_2: {pointer: /node/protectionRules/nodes/2/preventSelfReview, type: boolean, optional: true}

  # ==== Apply: one identical, idempotent update, gated on each way the rules can differ ====
  # The grammar has no OR, so each condition is its own gated step; a rerun runs none.
  - id: apply_rules_incomplete
    needs: [env_lookup, reviewer_lookup, env_observe]
    when:
      - {ref: steps.env_observe.outputs.total, not_equals: "3"}
    provider: github
    args: [graphql, "mutation($env: ID!, $team: ID!, $wait: Int!) { updateEnvironment(input: {environmentId: $env, reviewers: [$team], waitTimer: $wait, preventSelfReview: true}) { environment { id } } }", "env=${steps.env_lookup.outputs.id}", "team=${steps.reviewer_lookup.outputs.id}", "wait:=${wait_timer}"]

  - id: apply_wait_timer_wrong_0
    needs: [env_lookup, reviewer_lookup, env_observe]
    when:
      - {ref: steps.env_observe.outputs.type_0, equals: WAIT_TIMER}
      - {ref: steps.env_observe.outputs.timeout_0, not_equals: "${wait_timer}"}
    provider: github
    args: [graphql, "mutation($env: ID!, $team: ID!, $wait: Int!) { updateEnvironment(input: {environmentId: $env, reviewers: [$team], waitTimer: $wait, preventSelfReview: true}) { environment { id } } }", "env=${steps.env_lookup.outputs.id}", "team=${steps.reviewer_lookup.outputs.id}", "wait:=${wait_timer}"]

  - id: apply_reviewer_wrong_0
    needs: [env_lookup, reviewer_lookup, env_observe]
    when:
      - {ref: steps.env_observe.outputs.type_0, equals: REQUIRED_REVIEWERS}
      - {ref: steps.env_observe.outputs.team_0, not_equals: "${reviewer_team}"}
    provider: github
    args: [graphql, "mutation($env: ID!, $team: ID!, $wait: Int!) { updateEnvironment(input: {environmentId: $env, reviewers: [$team], waitTimer: $wait, preventSelfReview: true}) { environment { id } } }", "env=${steps.env_lookup.outputs.id}", "team=${steps.reviewer_lookup.outputs.id}", "wait:=${wait_timer}"]

  - id: apply_reviewer_not_team_0
    needs: [env_lookup, reviewer_lookup, env_observe]
    when:
      - {ref: steps.env_observe.outputs.type_0, equals: REQUIRED_REVIEWERS}
      - {ref: steps.env_observe.outputs.team_0, missing: true}
    provider: github
    args: [graphql, "mutation($env: ID!, $team: ID!, $wait: Int!) { updateEnvironment(input: {environmentId: $env, reviewers: [$team], waitTimer: $wait, preventSelfReview: true}) { environment { id } } }", "env=${steps.env_lookup.outputs.id}", "team=${steps.reviewer_lookup.outputs.id}", "wait:=${wait_timer}"]

  - id: apply_self_review_allowed_0
    needs: [env_lookup, reviewer_lookup, env_observe]
    when:
      - {ref: steps.env_observe.outputs.type_0, equals: REQUIRED_REVIEWERS}
      - {ref: steps.env_observe.outputs.self_review_0, not_equals: "true"}
    provider: github
    args: [graphql, "mutation($env: ID!, $team: ID!, $wait: Int!) { updateEnvironment(input: {environmentId: $env, reviewers: [$team], waitTimer: $wait, preventSelfReview: true}) { environment { id } } }", "env=${steps.env_lookup.outputs.id}", "team=${steps.reviewer_lookup.outputs.id}", "wait:=${wait_timer}"]

  - id: apply_wait_timer_wrong_1
    needs: [env_lookup, reviewer_lookup, env_observe]
    when:
      - {ref: steps.env_observe.outputs.type_1, equals: WAIT_TIMER}
      - {ref: steps.env_observe.outputs.timeout_1, not_equals: "${wait_timer}"}
    provider: github
    args: [graphql, "mutation($env: ID!, $team: ID!, $wait: Int!) { updateEnvironment(input: {environmentId: $env, reviewers: [$team], waitTimer: $wait, preventSelfReview: true}) { environment { id } } }", "env=${steps.env_lookup.outputs.id}", "team=${steps.reviewer_lookup.outputs.id}", "wait:=${wait_timer}"]

  - id: apply_reviewer_wrong_1
    needs: [env_lookup, reviewer_lookup, env_observe]
    when:
      - {ref: steps.env_observe.outputs.type_1, equals: REQUIRED_REVIEWERS}
      - {ref: steps.env_observe.outputs.team_1, not_equals: "${reviewer_team}"}
    provider: github
    args: [graphql, "mutation($env: ID!, $team: ID!, $wait: Int!) { updateEnvironment(input: {environmentId: $env, reviewers: [$team], waitTimer: $wait, preventSelfReview: true}) { environment { id } } }", "env=${steps.env_lookup.outputs.id}", "team=${steps.reviewer_lookup.outputs.id}", "wait:=${wait_timer}"]

  - id: apply_reviewer_not_team_1
    needs: [env_lookup, reviewer_lookup, env_observe]
    when:
      - {ref: steps.env_observe.outputs.type_1, equals: REQUIRED_REVIEWERS}
      - {ref: steps.env_observe.outputs.team_1, missing: true}
    provider: github
    args: [graphql, "mutation($env: ID!, $team: ID!, $wait: Int!) { updateEnvironment(input: {environmentId: $env, reviewers: [$team], waitTimer: $wait, preventSelfReview: true}) { environment { id } } }", "env=${steps.env_lookup.outputs.id}", "team=${steps.reviewer_lookup.outputs.id}", "wait:=${wait_timer}"]

  - id: apply_self_review_allowed_1
    needs: [env_lookup, reviewer_lookup, env_observe]
    when:
      - {ref: steps.env_observe.outputs.type_1, equals: REQUIRED_REVIEWERS}
      - {ref: steps.env_observe.outputs.self_review_1, not_equals: "true"}
    provider: github
    args: [graphql, "mutation($env: ID!, $team: ID!, $wait: Int!) { updateEnvironment(input: {environmentId: $env, reviewers: [$team], waitTimer: $wait, preventSelfReview: true}) { environment { id } } }", "env=${steps.env_lookup.outputs.id}", "team=${steps.reviewer_lookup.outputs.id}", "wait:=${wait_timer}"]

  - id: apply_wait_timer_wrong_2
    needs: [env_lookup, reviewer_lookup, env_observe]
    when:
      - {ref: steps.env_observe.outputs.type_2, equals: WAIT_TIMER}
      - {ref: steps.env_observe.outputs.timeout_2, not_equals: "${wait_timer}"}
    provider: github
    args: [graphql, "mutation($env: ID!, $team: ID!, $wait: Int!) { updateEnvironment(input: {environmentId: $env, reviewers: [$team], waitTimer: $wait, preventSelfReview: true}) { environment { id } } }", "env=${steps.env_lookup.outputs.id}", "team=${steps.reviewer_lookup.outputs.id}", "wait:=${wait_timer}"]

  - id: apply_reviewer_wrong_2
    needs: [env_lookup, reviewer_lookup, env_observe]
    when:
      - {ref: steps.env_observe.outputs.type_2, equals: REQUIRED_REVIEWERS}
      - {ref: steps.env_observe.outputs.team_2, not_equals: "${reviewer_team}"}
    provider: github
    args: [graphql, "mutation($env: ID!, $team: ID!, $wait: Int!) { updateEnvironment(input: {environmentId: $env, reviewers: [$team], waitTimer: $wait, preventSelfReview: true}) { environment { id } } }", "env=${steps.env_lookup.outputs.id}", "team=${steps.reviewer_lookup.outputs.id}", "wait:=${wait_timer}"]

  - id: apply_reviewer_not_team_2
    needs: [env_lookup, reviewer_lookup, env_observe]
    when:
      - {ref: steps.env_observe.outputs.type_2, equals: REQUIRED_REVIEWERS}
      - {ref: steps.env_observe.outputs.team_2, missing: true}
    provider: github
    args: [graphql, "mutation($env: ID!, $team: ID!, $wait: Int!) { updateEnvironment(input: {environmentId: $env, reviewers: [$team], waitTimer: $wait, preventSelfReview: true}) { environment { id } } }", "env=${steps.env_lookup.outputs.id}", "team=${steps.reviewer_lookup.outputs.id}", "wait:=${wait_timer}"]

  - id: apply_self_review_allowed_2
    needs: [env_lookup, reviewer_lookup, env_observe]
    when:
      - {ref: steps.env_observe.outputs.type_2, equals: REQUIRED_REVIEWERS}
      - {ref: steps.env_observe.outputs.self_review_2, not_equals: "true"}
    provider: github
    args: [graphql, "mutation($env: ID!, $team: ID!, $wait: Int!) { updateEnvironment(input: {environmentId: $env, reviewers: [$team], waitTimer: $wait, preventSelfReview: true}) { environment { id } } }", "env=${steps.env_lookup.outputs.id}", "team=${steps.reviewer_lookup.outputs.id}", "wait:=${wait_timer}"]

  # ==== Verify, independent of the order GitHub lists the rules in ====
  # Runtime allows one write per logical operation (verify step), so each aspect
  # that can drift on its own is its own operation; within one, the gates are
  # mutually exclusive. GitHub allows one rule of each type, so three rules
  # means each type exactly once.
  - id: rules_after
    needs: [env_lookup, apply_rules_incomplete, apply_wait_timer_wrong_0, apply_reviewer_wrong_0, apply_reviewer_not_team_0, apply_self_review_allowed_0, apply_wait_timer_wrong_1, apply_reviewer_wrong_1, apply_reviewer_not_team_1, apply_self_review_allowed_1, apply_wait_timer_wrong_2, apply_reviewer_wrong_2, apply_reviewer_not_team_2, apply_self_review_allowed_2]
    provider: github
    args: [graphql, "query($env: ID!) { node(id: $env) { ... on Environment { protectionRules(first: 5) { totalCount nodes { type timeout preventSelfReview reviewers(first: 1) { nodes { ... on Team { slug } } } } } } } }", "env=${steps.env_lookup.outputs.id}"]
    outputs:
      total: {pointer: /node/protectionRules/totalCount, type: integer}
      type_0: {pointer: /node/protectionRules/nodes/0/type, type: string, optional: true}
      timeout_0: {pointer: /node/protectionRules/nodes/0/timeout, type: integer, optional: true}
      team_0: {pointer: /node/protectionRules/nodes/0/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_0: {pointer: /node/protectionRules/nodes/0/preventSelfReview, type: boolean, optional: true}
      type_1: {pointer: /node/protectionRules/nodes/1/type, type: string, optional: true}
      timeout_1: {pointer: /node/protectionRules/nodes/1/timeout, type: integer, optional: true}
      team_1: {pointer: /node/protectionRules/nodes/1/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_1: {pointer: /node/protectionRules/nodes/1/preventSelfReview, type: boolean, optional: true}
      type_2: {pointer: /node/protectionRules/nodes/2/type, type: string, optional: true}
      timeout_2: {pointer: /node/protectionRules/nodes/2/timeout, type: integer, optional: true}
      team_2: {pointer: /node/protectionRules/nodes/2/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_2: {pointer: /node/protectionRules/nodes/2/preventSelfReview, type: boolean, optional: true}

  - id: rules_count_verify
    needs: [env_lookup, apply_rules_incomplete]
    provider: github
    args: [graphql, "query($env: ID!) { node(id: $env) { ... on Environment { protectionRules(first: 5) { totalCount nodes { type timeout preventSelfReview reviewers(first: 1) { nodes { ... on Team { slug } } } } } } } }", "env=${steps.env_lookup.outputs.id}"]
    outputs:
      total: {pointer: /node/protectionRules/totalCount, type: integer}
      type_0: {pointer: /node/protectionRules/nodes/0/type, type: string, optional: true}
      timeout_0: {pointer: /node/protectionRules/nodes/0/timeout, type: integer, optional: true}
      team_0: {pointer: /node/protectionRules/nodes/0/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_0: {pointer: /node/protectionRules/nodes/0/preventSelfReview, type: boolean, optional: true}
      type_1: {pointer: /node/protectionRules/nodes/1/type, type: string, optional: true}
      timeout_1: {pointer: /node/protectionRules/nodes/1/timeout, type: integer, optional: true}
      team_1: {pointer: /node/protectionRules/nodes/1/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_1: {pointer: /node/protectionRules/nodes/1/preventSelfReview, type: boolean, optional: true}
      type_2: {pointer: /node/protectionRules/nodes/2/type, type: string, optional: true}
      timeout_2: {pointer: /node/protectionRules/nodes/2/timeout, type: integer, optional: true}
      team_2: {pointer: /node/protectionRules/nodes/2/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_2: {pointer: /node/protectionRules/nodes/2/preventSelfReview, type: boolean, optional: true}
    expect:
      - {ref: steps.rules_count_verify.outputs.total, equals: "3"}

  - id: wait_timer_verify_0
    needs: [env_lookup, rules_after, apply_wait_timer_wrong_0]
    when: [{ref: steps.rules_after.outputs.type_0, equals: WAIT_TIMER}]
    provider: github
    args: [graphql, "query($env: ID!) { node(id: $env) { ... on Environment { protectionRules(first: 5) { totalCount nodes { type timeout preventSelfReview reviewers(first: 1) { nodes { ... on Team { slug } } } } } } } }", "env=${steps.env_lookup.outputs.id}"]
    outputs:
      total: {pointer: /node/protectionRules/totalCount, type: integer}
      type_0: {pointer: /node/protectionRules/nodes/0/type, type: string, optional: true}
      timeout_0: {pointer: /node/protectionRules/nodes/0/timeout, type: integer, optional: true}
      team_0: {pointer: /node/protectionRules/nodes/0/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_0: {pointer: /node/protectionRules/nodes/0/preventSelfReview, type: boolean, optional: true}
      type_1: {pointer: /node/protectionRules/nodes/1/type, type: string, optional: true}
      timeout_1: {pointer: /node/protectionRules/nodes/1/timeout, type: integer, optional: true}
      team_1: {pointer: /node/protectionRules/nodes/1/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_1: {pointer: /node/protectionRules/nodes/1/preventSelfReview, type: boolean, optional: true}
      type_2: {pointer: /node/protectionRules/nodes/2/type, type: string, optional: true}
      timeout_2: {pointer: /node/protectionRules/nodes/2/timeout, type: integer, optional: true}
      team_2: {pointer: /node/protectionRules/nodes/2/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_2: {pointer: /node/protectionRules/nodes/2/preventSelfReview, type: boolean, optional: true}
    expect:
      - {ref: steps.wait_timer_verify_0.outputs.type_0, equals: WAIT_TIMER}
      - {ref: steps.wait_timer_verify_0.outputs.timeout_0, equals: "${wait_timer}"}

  - id: reviewer_verify_0
    needs: [env_lookup, rules_after, apply_reviewer_wrong_0, apply_reviewer_not_team_0]
    when: [{ref: steps.rules_after.outputs.type_0, equals: REQUIRED_REVIEWERS}]
    provider: github
    args: [graphql, "query($env: ID!) { node(id: $env) { ... on Environment { protectionRules(first: 5) { totalCount nodes { type timeout preventSelfReview reviewers(first: 1) { nodes { ... on Team { slug } } } } } } } }", "env=${steps.env_lookup.outputs.id}"]
    outputs:
      total: {pointer: /node/protectionRules/totalCount, type: integer}
      type_0: {pointer: /node/protectionRules/nodes/0/type, type: string, optional: true}
      timeout_0: {pointer: /node/protectionRules/nodes/0/timeout, type: integer, optional: true}
      team_0: {pointer: /node/protectionRules/nodes/0/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_0: {pointer: /node/protectionRules/nodes/0/preventSelfReview, type: boolean, optional: true}
      type_1: {pointer: /node/protectionRules/nodes/1/type, type: string, optional: true}
      timeout_1: {pointer: /node/protectionRules/nodes/1/timeout, type: integer, optional: true}
      team_1: {pointer: /node/protectionRules/nodes/1/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_1: {pointer: /node/protectionRules/nodes/1/preventSelfReview, type: boolean, optional: true}
      type_2: {pointer: /node/protectionRules/nodes/2/type, type: string, optional: true}
      timeout_2: {pointer: /node/protectionRules/nodes/2/timeout, type: integer, optional: true}
      team_2: {pointer: /node/protectionRules/nodes/2/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_2: {pointer: /node/protectionRules/nodes/2/preventSelfReview, type: boolean, optional: true}
    expect:
      - {ref: steps.reviewer_verify_0.outputs.type_0, equals: REQUIRED_REVIEWERS}
      - {ref: steps.reviewer_verify_0.outputs.team_0, equals: "${reviewer_team}"}

  - id: self_review_verify_0
    needs: [env_lookup, rules_after, apply_self_review_allowed_0]
    when: [{ref: steps.rules_after.outputs.type_0, equals: REQUIRED_REVIEWERS}]
    provider: github
    args: [graphql, "query($env: ID!) { node(id: $env) { ... on Environment { protectionRules(first: 5) { totalCount nodes { type timeout preventSelfReview reviewers(first: 1) { nodes { ... on Team { slug } } } } } } } }", "env=${steps.env_lookup.outputs.id}"]
    outputs:
      total: {pointer: /node/protectionRules/totalCount, type: integer}
      type_0: {pointer: /node/protectionRules/nodes/0/type, type: string, optional: true}
      timeout_0: {pointer: /node/protectionRules/nodes/0/timeout, type: integer, optional: true}
      team_0: {pointer: /node/protectionRules/nodes/0/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_0: {pointer: /node/protectionRules/nodes/0/preventSelfReview, type: boolean, optional: true}
      type_1: {pointer: /node/protectionRules/nodes/1/type, type: string, optional: true}
      timeout_1: {pointer: /node/protectionRules/nodes/1/timeout, type: integer, optional: true}
      team_1: {pointer: /node/protectionRules/nodes/1/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_1: {pointer: /node/protectionRules/nodes/1/preventSelfReview, type: boolean, optional: true}
      type_2: {pointer: /node/protectionRules/nodes/2/type, type: string, optional: true}
      timeout_2: {pointer: /node/protectionRules/nodes/2/timeout, type: integer, optional: true}
      team_2: {pointer: /node/protectionRules/nodes/2/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_2: {pointer: /node/protectionRules/nodes/2/preventSelfReview, type: boolean, optional: true}
    expect:
      - {ref: steps.self_review_verify_0.outputs.type_0, equals: REQUIRED_REVIEWERS}
      - {ref: steps.self_review_verify_0.outputs.self_review_0, equals: "true"}

  - id: wait_timer_verify_1
    needs: [env_lookup, rules_after, apply_wait_timer_wrong_1]
    when: [{ref: steps.rules_after.outputs.type_1, equals: WAIT_TIMER}]
    provider: github
    args: [graphql, "query($env: ID!) { node(id: $env) { ... on Environment { protectionRules(first: 5) { totalCount nodes { type timeout preventSelfReview reviewers(first: 1) { nodes { ... on Team { slug } } } } } } } }", "env=${steps.env_lookup.outputs.id}"]
    outputs:
      total: {pointer: /node/protectionRules/totalCount, type: integer}
      type_0: {pointer: /node/protectionRules/nodes/0/type, type: string, optional: true}
      timeout_0: {pointer: /node/protectionRules/nodes/0/timeout, type: integer, optional: true}
      team_0: {pointer: /node/protectionRules/nodes/0/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_0: {pointer: /node/protectionRules/nodes/0/preventSelfReview, type: boolean, optional: true}
      type_1: {pointer: /node/protectionRules/nodes/1/type, type: string, optional: true}
      timeout_1: {pointer: /node/protectionRules/nodes/1/timeout, type: integer, optional: true}
      team_1: {pointer: /node/protectionRules/nodes/1/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_1: {pointer: /node/protectionRules/nodes/1/preventSelfReview, type: boolean, optional: true}
      type_2: {pointer: /node/protectionRules/nodes/2/type, type: string, optional: true}
      timeout_2: {pointer: /node/protectionRules/nodes/2/timeout, type: integer, optional: true}
      team_2: {pointer: /node/protectionRules/nodes/2/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_2: {pointer: /node/protectionRules/nodes/2/preventSelfReview, type: boolean, optional: true}
    expect:
      - {ref: steps.wait_timer_verify_1.outputs.type_1, equals: WAIT_TIMER}
      - {ref: steps.wait_timer_verify_1.outputs.timeout_1, equals: "${wait_timer}"}

  - id: reviewer_verify_1
    needs: [env_lookup, rules_after, apply_reviewer_wrong_1, apply_reviewer_not_team_1]
    when: [{ref: steps.rules_after.outputs.type_1, equals: REQUIRED_REVIEWERS}]
    provider: github
    args: [graphql, "query($env: ID!) { node(id: $env) { ... on Environment { protectionRules(first: 5) { totalCount nodes { type timeout preventSelfReview reviewers(first: 1) { nodes { ... on Team { slug } } } } } } } }", "env=${steps.env_lookup.outputs.id}"]
    outputs:
      total: {pointer: /node/protectionRules/totalCount, type: integer}
      type_0: {pointer: /node/protectionRules/nodes/0/type, type: string, optional: true}
      timeout_0: {pointer: /node/protectionRules/nodes/0/timeout, type: integer, optional: true}
      team_0: {pointer: /node/protectionRules/nodes/0/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_0: {pointer: /node/protectionRules/nodes/0/preventSelfReview, type: boolean, optional: true}
      type_1: {pointer: /node/protectionRules/nodes/1/type, type: string, optional: true}
      timeout_1: {pointer: /node/protectionRules/nodes/1/timeout, type: integer, optional: true}
      team_1: {pointer: /node/protectionRules/nodes/1/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_1: {pointer: /node/protectionRules/nodes/1/preventSelfReview, type: boolean, optional: true}
      type_2: {pointer: /node/protectionRules/nodes/2/type, type: string, optional: true}
      timeout_2: {pointer: /node/protectionRules/nodes/2/timeout, type: integer, optional: true}
      team_2: {pointer: /node/protectionRules/nodes/2/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_2: {pointer: /node/protectionRules/nodes/2/preventSelfReview, type: boolean, optional: true}
    expect:
      - {ref: steps.reviewer_verify_1.outputs.type_1, equals: REQUIRED_REVIEWERS}
      - {ref: steps.reviewer_verify_1.outputs.team_1, equals: "${reviewer_team}"}

  - id: self_review_verify_1
    needs: [env_lookup, rules_after, apply_self_review_allowed_1]
    when: [{ref: steps.rules_after.outputs.type_1, equals: REQUIRED_REVIEWERS}]
    provider: github
    args: [graphql, "query($env: ID!) { node(id: $env) { ... on Environment { protectionRules(first: 5) { totalCount nodes { type timeout preventSelfReview reviewers(first: 1) { nodes { ... on Team { slug } } } } } } } }", "env=${steps.env_lookup.outputs.id}"]
    outputs:
      total: {pointer: /node/protectionRules/totalCount, type: integer}
      type_0: {pointer: /node/protectionRules/nodes/0/type, type: string, optional: true}
      timeout_0: {pointer: /node/protectionRules/nodes/0/timeout, type: integer, optional: true}
      team_0: {pointer: /node/protectionRules/nodes/0/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_0: {pointer: /node/protectionRules/nodes/0/preventSelfReview, type: boolean, optional: true}
      type_1: {pointer: /node/protectionRules/nodes/1/type, type: string, optional: true}
      timeout_1: {pointer: /node/protectionRules/nodes/1/timeout, type: integer, optional: true}
      team_1: {pointer: /node/protectionRules/nodes/1/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_1: {pointer: /node/protectionRules/nodes/1/preventSelfReview, type: boolean, optional: true}
      type_2: {pointer: /node/protectionRules/nodes/2/type, type: string, optional: true}
      timeout_2: {pointer: /node/protectionRules/nodes/2/timeout, type: integer, optional: true}
      team_2: {pointer: /node/protectionRules/nodes/2/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_2: {pointer: /node/protectionRules/nodes/2/preventSelfReview, type: boolean, optional: true}
    expect:
      - {ref: steps.self_review_verify_1.outputs.type_1, equals: REQUIRED_REVIEWERS}
      - {ref: steps.self_review_verify_1.outputs.self_review_1, equals: "true"}

  - id: wait_timer_verify_2
    needs: [env_lookup, rules_after, apply_wait_timer_wrong_2]
    when: [{ref: steps.rules_after.outputs.type_2, equals: WAIT_TIMER}]
    provider: github
    args: [graphql, "query($env: ID!) { node(id: $env) { ... on Environment { protectionRules(first: 5) { totalCount nodes { type timeout preventSelfReview reviewers(first: 1) { nodes { ... on Team { slug } } } } } } } }", "env=${steps.env_lookup.outputs.id}"]
    outputs:
      total: {pointer: /node/protectionRules/totalCount, type: integer}
      type_0: {pointer: /node/protectionRules/nodes/0/type, type: string, optional: true}
      timeout_0: {pointer: /node/protectionRules/nodes/0/timeout, type: integer, optional: true}
      team_0: {pointer: /node/protectionRules/nodes/0/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_0: {pointer: /node/protectionRules/nodes/0/preventSelfReview, type: boolean, optional: true}
      type_1: {pointer: /node/protectionRules/nodes/1/type, type: string, optional: true}
      timeout_1: {pointer: /node/protectionRules/nodes/1/timeout, type: integer, optional: true}
      team_1: {pointer: /node/protectionRules/nodes/1/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_1: {pointer: /node/protectionRules/nodes/1/preventSelfReview, type: boolean, optional: true}
      type_2: {pointer: /node/protectionRules/nodes/2/type, type: string, optional: true}
      timeout_2: {pointer: /node/protectionRules/nodes/2/timeout, type: integer, optional: true}
      team_2: {pointer: /node/protectionRules/nodes/2/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_2: {pointer: /node/protectionRules/nodes/2/preventSelfReview, type: boolean, optional: true}
    expect:
      - {ref: steps.wait_timer_verify_2.outputs.type_2, equals: WAIT_TIMER}
      - {ref: steps.wait_timer_verify_2.outputs.timeout_2, equals: "${wait_timer}"}

  - id: reviewer_verify_2
    needs: [env_lookup, rules_after, apply_reviewer_wrong_2, apply_reviewer_not_team_2]
    when: [{ref: steps.rules_after.outputs.type_2, equals: REQUIRED_REVIEWERS}]
    provider: github
    args: [graphql, "query($env: ID!) { node(id: $env) { ... on Environment { protectionRules(first: 5) { totalCount nodes { type timeout preventSelfReview reviewers(first: 1) { nodes { ... on Team { slug } } } } } } } }", "env=${steps.env_lookup.outputs.id}"]
    outputs:
      total: {pointer: /node/protectionRules/totalCount, type: integer}
      type_0: {pointer: /node/protectionRules/nodes/0/type, type: string, optional: true}
      timeout_0: {pointer: /node/protectionRules/nodes/0/timeout, type: integer, optional: true}
      team_0: {pointer: /node/protectionRules/nodes/0/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_0: {pointer: /node/protectionRules/nodes/0/preventSelfReview, type: boolean, optional: true}
      type_1: {pointer: /node/protectionRules/nodes/1/type, type: string, optional: true}
      timeout_1: {pointer: /node/protectionRules/nodes/1/timeout, type: integer, optional: true}
      team_1: {pointer: /node/protectionRules/nodes/1/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_1: {pointer: /node/protectionRules/nodes/1/preventSelfReview, type: boolean, optional: true}
      type_2: {pointer: /node/protectionRules/nodes/2/type, type: string, optional: true}
      timeout_2: {pointer: /node/protectionRules/nodes/2/timeout, type: integer, optional: true}
      team_2: {pointer: /node/protectionRules/nodes/2/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_2: {pointer: /node/protectionRules/nodes/2/preventSelfReview, type: boolean, optional: true}
    expect:
      - {ref: steps.reviewer_verify_2.outputs.type_2, equals: REQUIRED_REVIEWERS}
      - {ref: steps.reviewer_verify_2.outputs.team_2, equals: "${reviewer_team}"}

  - id: self_review_verify_2
    needs: [env_lookup, rules_after, apply_self_review_allowed_2]
    when: [{ref: steps.rules_after.outputs.type_2, equals: REQUIRED_REVIEWERS}]
    provider: github
    args: [graphql, "query($env: ID!) { node(id: $env) { ... on Environment { protectionRules(first: 5) { totalCount nodes { type timeout preventSelfReview reviewers(first: 1) { nodes { ... on Team { slug } } } } } } } }", "env=${steps.env_lookup.outputs.id}"]
    outputs:
      total: {pointer: /node/protectionRules/totalCount, type: integer}
      type_0: {pointer: /node/protectionRules/nodes/0/type, type: string, optional: true}
      timeout_0: {pointer: /node/protectionRules/nodes/0/timeout, type: integer, optional: true}
      team_0: {pointer: /node/protectionRules/nodes/0/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_0: {pointer: /node/protectionRules/nodes/0/preventSelfReview, type: boolean, optional: true}
      type_1: {pointer: /node/protectionRules/nodes/1/type, type: string, optional: true}
      timeout_1: {pointer: /node/protectionRules/nodes/1/timeout, type: integer, optional: true}
      team_1: {pointer: /node/protectionRules/nodes/1/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_1: {pointer: /node/protectionRules/nodes/1/preventSelfReview, type: boolean, optional: true}
      type_2: {pointer: /node/protectionRules/nodes/2/type, type: string, optional: true}
      timeout_2: {pointer: /node/protectionRules/nodes/2/timeout, type: integer, optional: true}
      team_2: {pointer: /node/protectionRules/nodes/2/reviewers/nodes/0/slug, type: string, optional: true}
      self_review_2: {pointer: /node/protectionRules/nodes/2/preventSelfReview, type: boolean, optional: true}
    expect:
      - {ref: steps.self_review_verify_2.outputs.type_2, equals: REQUIRED_REVIEWERS}
      - {ref: steps.self_review_verify_2.outputs.self_review_2, equals: "true"}

  # ==== Release tags may deploy (repo-deploy-promote deploys from the tag) ====
  # Onboarding leaves exactly one deployment branch policy, `main`; the tag
  # policy is added only in that state, and verified as the second entry.
  - id: tag_policy_observe
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/environments/${environment}/deployment-branch-policies"]
    outputs:
      total: {pointer: /total_count, type: integer}
      first: {pointer: /branch_policies/0/name, type: string, optional: true}

  - id: tag_policy_add
    needs: [tag_policy_observe]
    when:
      - {ref: steps.tag_policy_observe.outputs.total, equals: "1"}
      - {ref: steps.tag_policy_observe.outputs.first, equals: main}
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/environments/${environment}/deployment-branch-policies", "name=v*", "type=tag"]

  - id: tag_policy_verify
    needs: [tag_policy_add]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/environments/${environment}/deployment-branch-policies"]
    outputs:
      total: {pointer: /total_count, type: integer}
      first: {pointer: /branch_policies/0/name, type: string, optional: true}
      second: {pointer: /branch_policies/1/name, type: string, optional: true}
      second_type: {pointer: /branch_policies/1/type, type: string, optional: true}
    expect:
      - {ref: steps.tag_policy_verify.outputs.total, equals: "2"}
      - {ref: steps.tag_policy_verify.outputs.first, equals: main}
      - {ref: steps.tag_policy_verify.outputs.second, equals: "v*"}
      - {ref: steps.tag_policy_verify.outputs.second_type, equals: tag}
```
