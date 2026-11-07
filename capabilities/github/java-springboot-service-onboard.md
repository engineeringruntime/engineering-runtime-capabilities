# Onboard a Spring Boot microservice repository with GitHub protections

> **Mutating.** It can create a repository and changes its settings, files,
> environments and rulesets. Run `plan` first. Execute only when a person has
> asked for that exact repository.

One governed run takes a repository from nothing (or from an existing,
unprotected repository) to a protected Spring Boot service with a working
pipeline:

| Stage | What it establishes |
|---|---|
| 1. Repository | created private (or as `private` says) when absent; squash merge only, head branches deleted after merge, wiki and projects off |
| 2. Dependency security | Dependabot alerts and Dependabot security updates on |
| 3. Actions | GitHub-owned actions only, every action pinned to a full commit SHA, `GITHUB_TOKEN` read-only by default and unable to approve pull requests |
| 4. Environments | `dev` deploys from any branch; `staging` and `production` from `main` only |
| 5. Service files | Maven `pom.xml`, `Application`, a validated sample REST endpoint, tests (including a rejected-input case), `application.yml` with health probes and graceful shutdown, a non-root multi-stage `Dockerfile`, `ci.yml`, `dependabot.yml`, `CODEOWNERS`, `SECURITY.md`, a pull-request template, `README.md`, `.gitignore`, `.dockerignore` |
| 6. Rulesets | default branch: no deletion, no force push, linear history, pull request required with the `build` check passing (strict), stale approvals dismissed, conversations resolved, squash only, **no bypass actors**; tags `v*`: no deletion, no rewrite |
| 7. Pipeline | lists the first `ci` runs, started by the `ci.yml` commit |

Every concern is **observe → change only when needed → read back and verify**,
so the run is safe to repeat and a failed run can be resumed by running it
again:

| Rerun on | Result |
|---|---|
| a repository this capability onboarded | every verification passes; every change step is `not_required` except the three environment `PUT`s, which re-send unchanged values on every run and report `APPLIED` (an absent environment cannot be observed without a failure) |
| an existing repository | missing files are added, existing files are **kept**, settings that differ from the baseline are corrected |
| a repository with other visibility than `private` | `repo_verify` fails; visibility is never changed |
| a repository with its own rulesets | the ruleset verifications fail; existing rulesets are never changed or replaced |

It uses only the GitHub provider (`rest` for the repository, settings and
files, `graphql` for observations, `cli` for the run list). Nothing is cloned
and nothing is written to the local disk, so it runs the same from a laptop or
from CI.

## What it needs

- **Policy:** nothing beyond a policy that allows the GitHub provider. It uses
  `api GET`, `POST`, `PUT` and `PATCH`; `api DELETE` is never used, so the
  usual `providers.github.denied: [api DELETE]` rule can stay. No
  `allowed_binaries`, no `file_policy` root.
- **Credential:** an identity that may create repositories in the organization
  and administer the new repository.
  - User token (`env`, `file`, `os_secure_store`): classic scopes `repo` and
    **`workflow`**. Without `workflow` GitHub refuses to create
    `.github/workflows/ci.yml`.
  - GitHub App (`github_app`): repository Administration, Contents, Workflows,
    Environments and Actions read/write, Metadata read, and organization
    Administration read/write to create the repository.
- **GitHub plan:** rulesets and environment branch policies on private
  repositories need GitHub Team or above.

## Inputs worth deciding

- `required_approvals` and `require_code_owner_review`: GitHub never lets an
  author approve their own pull request. With a single maintainer, use `0` and
  `false`, or every pull request is blocked. Raise them when a second
  maintainer joins (edit the ruleset, or onboard a new repository).
- `java_version` and `spring_boot_version`: written into the POM, the workflow
  and the container image. Tested with `21` and `4.1.2`.
- `java_package_path` must be `java_package` with dots replaced by slashes.

## Deliberately not done

| Not done | Why, and what to do instead |
|---|---|
| Environment secrets | GitHub requires each value to be encrypted on the client, and credential values never belong in a capability. Prefer OIDC federation; otherwise set them with `gh secret set --env <name>`. |
| Required reviewers or a wait timer on `production` | On private repositories GitHub offers them only with GitHub Enterprise. |
| Secret scanning, push protection, code scanning, dependency review | On private repositories these need paid GitHub Advanced Security products. They are a cost decision for the organization owner. |
| Team access | Grant it explicitly with `api PUT /orgs/<org>/teams/<team>/repos/<org>/<repo>` once the team exists; onboarding does not guess who should have access. |
| Maven wrapper | The contents API cannot set the executable bit, so CI uses the runner's Maven. |
| Changing existing files or rulesets | Onboarding only adds what is missing. Use `github/repo-ruleset-default-reconcile` style convergence for drift. |
| Organization-wide settings (2FA requirement, who may create repositories, defaults for new repositories) | They belong to an organization baseline, not to each repository. |

## How it was built

- Actions are pinned to commit SHAs resolved from the `v7.0.1`, `v6.2.0` and
  `v7.0.2` tag objects of `actions/checkout`, `actions/setup-java` and
  `actions/upload-artifact`. Dependabot keeps them current.
- `$$` emits a literal `$`, so the workflow's `$${{ github.ref }}` and Spring's
  `$${PORT:8080}` reach the repository as `${{ github.ref }}` and
  `${PORT:8080}`. Without the escape the capability fails validation.
- The ruleset is created last. Once the pull-request rule is active no step can
  commit to `main`, and the earlier file commits would be refused.
- `ci.yml` is the last file, so onboarding starts exactly one pipeline run.
- An absent environment cannot be observed (the GraphQL lookup reports an
  error), so environments use `PUT`, which creates or updates and is safe to
  repeat.

## Run it

```bash
engrt capability plan github/java-springboot-service-onboard \
  --input organization=<organization> \
  --input repository=<repository> \
  --input "description=Payment gateway service" \
  --input private=true \
  --input service_name=payment-gateway \
  --input java_package=com.example.payments \
  --input java_package_path=com/example/payments \
  --input java_version=21 \
  --input spring_boot_version=4.1.2 \
  --input code_owner=<github-user-or-org/team> \
  --input required_approvals=0 \
  --input require_code_owner_review=false
```

Execute with the same inputs after reviewing the plan. `--output json` lists
each operation's outcome (`APPLIED`, `RECONCILED`, `SATISFIED`, `FAILED`) under
`operations`.

```runtime
version: v1
capability_version: "1.0.0"
engrt_version: ">=0.13.0"

inputs:
  organization:
    description: GitHub organization that owns (or will own) the repository
    required: true
  repository:
    description: Repository name without the owner. Created when absent; an existing repository is brought to the baseline.
    required: true
  description:
    description: One-line repository and service description (used only when the repository is created, and in the README)
    required: true
  private:
    description: "true or false. Repository visibility, checked on every run; an existing repository with other visibility fails the run and is not changed."
    required: true
  service_name:
    description: Service name, used as the Maven artifactId and spring.application.name, e.g. payment-gateway
    required: true
  java_package:
    description: Base Java package in dotted form, e.g. com.example.payments (also the Maven groupId)
    required: true
  java_package_path:
    description: The same package in path form, e.g. com/example/payments
    required: true
  java_version:
    description: Java LTS feature release, e.g. 21 (used by Maven, CI and the container image)
    required: true
  spring_boot_version:
    description: Spring Boot release for the parent POM, e.g. 4.1.2
    required: true
  code_owner:
    description: Default code owner without the @, a user (octocat) or a team (my-org/payments)
    required: true
  required_approvals:
    description: Approving reviews a pull request needs (integer). 0 while the repository has a single maintainer; nobody can approve their own pull request.
    required: true
  require_code_owner_review:
    description: "true or false. Require a code owner's approval. Keep false while the code owner is the only maintainer."
    required: true

workflow:
  # ==== 1. Repository: create when absent, otherwise bring merge settings to baseline ====
  - id: repo_observe
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      allow_merge_commit: {pointer: /allow_merge_commit, type: boolean, optional: true}
      allow_rebase_merge: {pointer: /allow_rebase_merge, type: boolean, optional: true}
      allow_squash_merge: {pointer: /allow_squash_merge, type: boolean, optional: true}
      delete_branch_on_merge: {pointer: /delete_branch_on_merge, type: boolean, optional: true}

  - id: repo_create
    needs: [repo_observe]
    when: [{ref: steps.repo_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - api
      - POST
      - "/orgs/${organization}/repos"
      - "name=${repository}"
      - "description=${description}"
      - "private:=${private}"
      - "auto_init:=false"
      - "has_issues:=true"
      - "has_wiki:=false"
      - "has_projects:=false"
      - "allow_squash_merge:=true"
      - "allow_merge_commit:=false"
      - "allow_rebase_merge:=false"
      - "delete_branch_on_merge:=true"
      - "squash_merge_commit_title=PR_TITLE"
      - "squash_merge_commit_message=PR_BODY"

  - id: repo_verify
    needs: [repo_create]
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      private: {pointer: /private, type: boolean}
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.repo_verify.outputs.name, equals: "${repository}"}
      - {ref: steps.repo_verify.outputs.private, equals: "${private}"}

  - id: fix_allow_merge_commit
    needs: [repo_observe]
    when:
      - {ref: steps.repo_observe.observation, equals: PRESENT}
      - {ref: steps.repo_observe.outputs.allow_merge_commit, not_equals: "false"}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}", "allow_merge_commit:=false"]

  - id: verify_allow_merge_commit
    needs: [fix_allow_merge_commit]
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      v: {pointer: /allow_merge_commit, type: boolean}
    expect:
      - {ref: steps.verify_allow_merge_commit.outputs.v, equals: "false"}

  - id: fix_allow_rebase_merge
    needs: [repo_observe]
    when:
      - {ref: steps.repo_observe.observation, equals: PRESENT}
      - {ref: steps.repo_observe.outputs.allow_rebase_merge, not_equals: "false"}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}", "allow_rebase_merge:=false"]

  - id: verify_allow_rebase_merge
    needs: [fix_allow_rebase_merge]
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      v: {pointer: /allow_rebase_merge, type: boolean}
    expect:
      - {ref: steps.verify_allow_rebase_merge.outputs.v, equals: "false"}

  - id: fix_allow_squash_merge
    needs: [repo_observe]
    when:
      - {ref: steps.repo_observe.observation, equals: PRESENT}
      - {ref: steps.repo_observe.outputs.allow_squash_merge, not_equals: "true"}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}", "allow_squash_merge:=true"]

  - id: verify_allow_squash_merge
    needs: [fix_allow_squash_merge]
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      v: {pointer: /allow_squash_merge, type: boolean}
    expect:
      - {ref: steps.verify_allow_squash_merge.outputs.v, equals: "true"}

  - id: fix_delete_branch_on_merge
    needs: [repo_observe]
    when:
      - {ref: steps.repo_observe.observation, equals: PRESENT}
      - {ref: steps.repo_observe.outputs.delete_branch_on_merge, not_equals: "true"}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}", "delete_branch_on_merge:=true"]

  - id: verify_delete_branch_on_merge
    needs: [fix_delete_branch_on_merge]
    provider: github
    args: [repo, view, "${organization}/${repository}"]
    outputs:
      v: {pointer: /delete_branch_on_merge, type: boolean}
    expect:
      - {ref: steps.verify_delete_branch_on_merge.outputs.v, equals: "true"}

  # ==== 2. Dependency security: Dependabot alerts, then security updates ====
  - id: alerts_observe
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { hasVulnerabilityAlertsEnabled } }", "owner=${organization}", "name=${repository}"]
    outputs:
      on: {pointer: /repository/hasVulnerabilityAlertsEnabled, type: boolean}

  - id: alerts_enable
    needs: [alerts_observe]
    when: [{ref: steps.alerts_observe.outputs.on, equals: "false"}]
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/vulnerability-alerts"]

  - id: alerts_verify
    needs: [alerts_enable]
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { hasVulnerabilityAlertsEnabled } }", "owner=${organization}", "name=${repository}"]
    outputs:
      on: {pointer: /repository/hasVulnerabilityAlertsEnabled, type: boolean}
    expect:
      - {ref: steps.alerts_verify.outputs.on, equals: "true"}

  - id: security_updates_observe
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/automated-security-fixes"]
    outputs:
      on: {pointer: /enabled, type: boolean}

  - id: security_updates_enable
    needs: [security_updates_observe]
    when: [{ref: steps.security_updates_observe.outputs.on, equals: "false"}]
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/automated-security-fixes"]

  - id: security_updates_verify
    needs: [security_updates_enable]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/automated-security-fixes"]
    outputs:
      on: {pointer: /enabled, type: boolean}
    expect:
      - {ref: steps.security_updates_verify.outputs.on, equals: "true"}

  # ==== 3. Actions: GitHub-owned actions only, SHA-pinned, read-only GITHUB_TOKEN ====
  - id: actions_observe
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions"]
    outputs:
      allowed: {pointer: /allowed_actions, type: string, optional: true}
      pinned: {pointer: /sha_pinning_required, type: boolean, optional: true}

  - id: actions_fix_allowed
    needs: [actions_observe]
    when: [{ref: steps.actions_observe.outputs.allowed, not_equals: selected}]
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/actions/permissions", "enabled:=true", "allowed_actions=selected", "sha_pinning_required:=true"]

  - id: actions_verify_allowed
    needs: [actions_fix_allowed]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions"]
    outputs:
      enabled: {pointer: /enabled, type: boolean}
      allowed: {pointer: /allowed_actions, type: string}
    expect:
      - {ref: steps.actions_verify_allowed.outputs.enabled, equals: "true"}
      - {ref: steps.actions_verify_allowed.outputs.allowed, equals: selected}

  - id: actions_fix_pinning
    needs: [actions_observe]
    when: [{ref: steps.actions_observe.outputs.pinned, not_equals: "true"}]
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/actions/permissions", "enabled:=true", "allowed_actions=selected", "sha_pinning_required:=true"]

  - id: actions_verify_pinning
    needs: [actions_fix_pinning]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions"]
    outputs:
      pinned: {pointer: /sha_pinning_required, type: boolean}
    expect:
      - {ref: steps.actions_verify_pinning.outputs.pinned, equals: "true"}

  - id: selected_actions_observe
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions/selected-actions"]
    outputs:
      github_owned: {pointer: /github_owned_allowed, type: boolean}
      verified: {pointer: /verified_allowed, type: boolean}

  - id: selected_actions_fix_github_owned
    needs: [selected_actions_observe]
    when: [{ref: steps.selected_actions_observe.outputs.github_owned, not_equals: "true"}]
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/actions/permissions/selected-actions", "github_owned_allowed:=true", "verified_allowed:=false", "patterns_allowed:=[]"]

  - id: selected_actions_verify_github_owned
    needs: [selected_actions_fix_github_owned]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions/selected-actions"]
    outputs:
      github_owned: {pointer: /github_owned_allowed, type: boolean}
    expect:
      - {ref: steps.selected_actions_verify_github_owned.outputs.github_owned, equals: "true"}

  - id: selected_actions_fix_verified
    needs: [selected_actions_observe]
    when: [{ref: steps.selected_actions_observe.outputs.verified, not_equals: "false"}]
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/actions/permissions/selected-actions", "github_owned_allowed:=true", "verified_allowed:=false", "patterns_allowed:=[]"]

  - id: selected_actions_verify_verified
    needs: [selected_actions_fix_verified]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions/selected-actions"]
    outputs:
      verified: {pointer: /verified_allowed, type: boolean}
    expect:
      - {ref: steps.selected_actions_verify_verified.outputs.verified, equals: "false"}

  - id: token_observe
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions/workflow"]
    outputs:
      permissions: {pointer: /default_workflow_permissions, type: string}
      approve: {pointer: /can_approve_pull_request_reviews, type: boolean}

  - id: token_fix_permissions
    needs: [token_observe]
    when: [{ref: steps.token_observe.outputs.permissions, not_equals: read}]
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/actions/permissions/workflow", "default_workflow_permissions=read", "can_approve_pull_request_reviews:=false"]

  - id: token_verify_permissions
    needs: [token_fix_permissions]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions/workflow"]
    outputs:
      permissions: {pointer: /default_workflow_permissions, type: string}
    expect:
      - {ref: steps.token_verify_permissions.outputs.permissions, equals: read}

  - id: token_fix_approve
    needs: [token_observe]
    when: [{ref: steps.token_observe.outputs.approve, not_equals: "false"}]
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/actions/permissions/workflow", "default_workflow_permissions=read", "can_approve_pull_request_reviews:=false"]

  - id: token_verify_approve
    needs: [token_fix_approve]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/actions/permissions/workflow"]
    outputs:
      approve: {pointer: /can_approve_pull_request_reviews, type: boolean}
    expect:
      - {ref: steps.token_verify_approve.outputs.approve, equals: "false"}

  # ==== 4. Environments: dev from any branch; staging and production from main only ====
  # PUT creates or updates, so it is safe on every run; there is no curated read
  # that observes an absent environment.
  - id: env_dev_put
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/environments/dev", "deployment_branch_policy:=null"]

  - id: env_dev_verify
    needs: [env_dev_put]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/environments/dev"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.env_dev_verify.outputs.name, equals: dev}

  - id: env_staging_put
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/environments/staging", 'deployment_branch_policy:={"protected_branches":false,"custom_branch_policies":true}']

  - id: env_staging_verify
    needs: [env_staging_put]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/environments/staging"]
    outputs:
      name: {pointer: /name, type: string}
      custom: {pointer: /deployment_branch_policy/custom_branch_policies, type: boolean}
    expect:
      - {ref: steps.env_staging_verify.outputs.name, equals: staging}
      - {ref: steps.env_staging_verify.outputs.custom, equals: "true"}

  - id: env_staging_main_observe
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/environments/staging/deployment-branch-policies"]
    outputs:
      total: {pointer: /total_count, type: integer}

  - id: env_staging_main_add
    needs: [env_staging_main_observe]
    when: [{ref: steps.env_staging_main_observe.outputs.total, equals: "0"}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/environments/staging/deployment-branch-policies", "name=main", "type=branch"]

  - id: env_staging_main_verify
    needs: [env_staging_main_add]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/environments/staging/deployment-branch-policies"]
    outputs:
      total: {pointer: /total_count, type: integer}
      first: {pointer: /branch_policies/0/name, type: string}
    expect:
      - {ref: steps.env_staging_main_verify.outputs.total, equals: "1"}
      - {ref: steps.env_staging_main_verify.outputs.first, equals: main}

  - id: env_production_put
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/environments/production", 'deployment_branch_policy:={"protected_branches":false,"custom_branch_policies":true}']

  - id: env_production_verify
    needs: [env_production_put]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/environments/production"]
    outputs:
      name: {pointer: /name, type: string}
      custom: {pointer: /deployment_branch_policy/custom_branch_policies, type: boolean}
    expect:
      - {ref: steps.env_production_verify.outputs.name, equals: production}
      - {ref: steps.env_production_verify.outputs.custom, equals: "true"}

  - id: env_production_main_observe
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/environments/production/deployment-branch-policies"]
    outputs:
      total: {pointer: /total_count, type: integer}

  - id: env_production_main_add
    needs: [env_production_main_observe]
    when: [{ref: steps.env_production_main_observe.outputs.total, equals: "0"}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/environments/production/deployment-branch-policies", "name=main", "type=branch"]

  - id: env_production_main_verify
    needs: [env_production_main_add]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/environments/production/deployment-branch-policies"]
    outputs:
      total: {pointer: /total_count, type: integer}
      first: {pointer: /branch_policies/0/name, type: string}
    expect:
      - {ref: steps.env_production_main_verify.outputs.total, equals: "1"}
      - {ref: steps.env_production_main_verify.outputs.first, equals: main}

  # ==== 5. Service files: each is written only when absent; existing files are kept ====
  - id: file_gitignore_observe
    provider: github
    args: [file, get, "${organization}/${repository}", ".gitignore"]

  - id: file_gitignore_put
    needs: [file_gitignore_observe]
    when: [{ref: steps.file_gitignore_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - ".gitignore"
      - "message=chore(onboard): add .gitignore"
      - |
        content=target/
        *.class
        *.log
        .idea/
        *.iml
        .vscode/
        .DS_Store
        .env

  - id: file_gitignore_verify
    needs: [file_gitignore_put]
    provider: github
    args: [file, get, "${organization}/${repository}", ".gitignore"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_gitignore_verify.outputs.name, equals: ".gitignore"}

  - id: file_dockerignore_observe
    provider: github
    args: [file, get, "${organization}/${repository}", ".dockerignore"]

  - id: file_dockerignore_put
    needs: [file_dockerignore_observe]
    when: [{ref: steps.file_dockerignore_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - ".dockerignore"
      - "message=chore(onboard): add .dockerignore"
      - |
        content=.git
        .github
        target
        .idea
        .vscode
        *.md

  - id: file_dockerignore_verify
    needs: [file_dockerignore_put]
    provider: github
    args: [file, get, "${organization}/${repository}", ".dockerignore"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_dockerignore_verify.outputs.name, equals: ".dockerignore"}

  - id: file_readme_observe
    provider: github
    args: [file, get, "${organization}/${repository}", "README.md"]

  - id: file_readme_put
    needs: [file_readme_observe]
    when: [{ref: steps.file_readme_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - "README.md"
      - "message=chore(onboard): add README.md"
      - |
        content=# ${service_name}

        ${description}

        A Spring Boot ${spring_boot_version} service on Java ${java_version}, onboarded
        by the Engineering Runtime capability `github/java-springboot-service-onboard`.
        Every file, setting and protection below was created through `engrt`, and each
        step is in the Runtime audit log of the person who ran it.

        ## Run it

        With JDK ${java_version} and Maven 3.9+:

            mvn spring-boot:run

        Or as a container:

            docker build -t ${service_name} .
            docker run --rm -p 8080:8080 ${service_name}

        | Endpoint | Purpose |
        |---|---|
        | `GET /api/v1/greeting?name=you` | sample API; `name` is 1 to 64 characters |
        | `GET /actuator/health` | health, with `/liveness` and `/readiness` probes |
        | `GET /actuator/info` | build information |

        The port comes from `PORT` (default 8080).

        ## Delivery

        - `ci` (`.github/workflows/ci.yml`) builds and tests every pull request and
          every push to `main`. Its `build` job is a required status check.
        - Dependabot opens weekly update pull requests for Maven and for Actions.

        ## Protections on this repository

        | Area | Setting |
        |---|---|
        | Default branch | ruleset `engrt-onboard-default-branch`: no deletion, no force push, linear history, pull request with `build` passing, stale approvals dismissed, conversations resolved, squash merge only, no bypass |
        | Release tags `v*` | ruleset `engrt-onboard-release-tags`: no deletion, no rewrite |
        | Merging | squash only; head branches deleted after merge |
        | Actions | GitHub-owned actions only, pinned to a full commit SHA; `GITHUB_TOKEN` read-only and cannot approve pull requests |
        | Dependencies | Dependabot alerts and security updates on |
        | Environments | `dev` (any branch), `staging` and `production` (deploy from `main` only) |
        | Ownership | `.github/CODEOWNERS` |

  - id: file_readme_verify
    needs: [file_readme_put]
    provider: github
    args: [file, get, "${organization}/${repository}", "README.md"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_readme_verify.outputs.name, equals: "README.md"}

  - id: file_security_observe
    provider: github
    args: [file, get, "${organization}/${repository}", "SECURITY.md"]

  - id: file_security_put
    needs: [file_security_observe]
    when: [{ref: steps.file_security_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - "SECURITY.md"
      - "message=chore(onboard): add SECURITY.md"
      - |
        content=# Security policy

        Report a suspected vulnerability privately to the code owners listed in
        `.github/CODEOWNERS`. Do not open a public issue or pull request for it.

        Include what is affected, how to reproduce it and the impact you expect. You
        will get an acknowledgement, and the fix ships through the normal reviewed
        pull-request flow of this repository.

  - id: file_security_verify
    needs: [file_security_put]
    provider: github
    args: [file, get, "${organization}/${repository}", "SECURITY.md"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_security_verify.outputs.name, equals: "SECURITY.md"}

  - id: file_codeowners_observe
    provider: github
    args: [file, get, "${organization}/${repository}", ".github/CODEOWNERS"]

  - id: file_codeowners_put
    needs: [file_codeowners_observe]
    when: [{ref: steps.file_codeowners_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - ".github/CODEOWNERS"
      - "message=chore(onboard): add CODEOWNERS"
      - |
        content=# Default owner for every path in ${service_name}.
        * @${code_owner}

  - id: file_codeowners_verify
    needs: [file_codeowners_put]
    provider: github
    args: [file, get, "${organization}/${repository}", ".github/CODEOWNERS"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_codeowners_verify.outputs.name, equals: "CODEOWNERS"}

  - id: file_prtemplate_observe
    provider: github
    args: [file, get, "${organization}/${repository}", ".github/pull_request_template.md"]

  - id: file_prtemplate_put
    needs: [file_prtemplate_observe]
    when: [{ref: steps.file_prtemplate_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - ".github/pull_request_template.md"
      - "message=chore(onboard): add pull_request_template.md"
      - |
        content=## What and why

        <!-- What changes, and why it is needed. Link the issue. -->

        ## How it was tested

        <!-- Commands run and their results. -->

        ## Checklist

        - [ ] Tests cover the change, including a failure case
        - [ ] No credentials, tokens or personal data in code, logs or tests
        - [ ] Docs and configuration updated where behaviour changed

  - id: file_prtemplate_verify
    needs: [file_prtemplate_put]
    provider: github
    args: [file, get, "${organization}/${repository}", ".github/pull_request_template.md"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_prtemplate_verify.outputs.name, equals: "pull_request_template.md"}

  - id: file_dependabot_observe
    provider: github
    args: [file, get, "${organization}/${repository}", ".github/dependabot.yml"]

  - id: file_dependabot_put
    needs: [file_dependabot_observe]
    when: [{ref: steps.file_dependabot_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - ".github/dependabot.yml"
      - "message=chore(onboard): add dependabot.yml"
      - |
        content=version: 2
        updates:
          - package-ecosystem: maven
            directory: /
            schedule:
              interval: weekly
            open-pull-requests-limit: 5
            groups:
              spring-boot:
                patterns:
                  - "org.springframework.boot*"
          - package-ecosystem: github-actions
            directory: /
            schedule:
              interval: weekly
            open-pull-requests-limit: 5

  - id: file_dependabot_verify
    needs: [file_dependabot_put]
    provider: github
    args: [file, get, "${organization}/${repository}", ".github/dependabot.yml"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_dependabot_verify.outputs.name, equals: "dependabot.yml"}

  - id: file_pom_observe
    provider: github
    args: [file, get, "${organization}/${repository}", "pom.xml"]

  - id: file_pom_put
    needs: [file_pom_observe]
    when: [{ref: steps.file_pom_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - "pom.xml"
      - "message=chore(onboard): add pom.xml"
      - |
        content=<?xml version="1.0" encoding="UTF-8"?>
        <project xmlns="http://maven.apache.org/POM/4.0.0"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
          <modelVersion>4.0.0</modelVersion>

          <parent>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-parent</artifactId>
            <version>${spring_boot_version}</version>
            <relativePath/>
          </parent>

          <groupId>${java_package}</groupId>
          <artifactId>${service_name}</artifactId>
          <version>0.1.0-SNAPSHOT</version>
          <name>${service_name}</name>

          <properties>
            <java.version>${java_version}</java.version>
          </properties>

          <dependencies>
            <dependency>
              <groupId>org.springframework.boot</groupId>
              <artifactId>spring-boot-starter-webmvc</artifactId>
            </dependency>
            <dependency>
              <groupId>org.springframework.boot</groupId>
              <artifactId>spring-boot-starter-actuator</artifactId>
            </dependency>
            <dependency>
              <groupId>org.springframework.boot</groupId>
              <artifactId>spring-boot-starter-validation</artifactId>
            </dependency>
            <dependency>
              <groupId>org.springframework.boot</groupId>
              <artifactId>spring-boot-starter-webmvc-test</artifactId>
              <scope>test</scope>
            </dependency>
          </dependencies>

          <build>
            <plugins>
              <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <executions>
                  <execution>
                    <goals>
                      <goal>build-info</goal>
                    </goals>
                  </execution>
                </executions>
              </plugin>
            </plugins>
          </build>
        </project>

  - id: file_pom_verify
    needs: [file_pom_put]
    provider: github
    args: [file, get, "${organization}/${repository}", "pom.xml"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_pom_verify.outputs.name, equals: "pom.xml"}

  - id: file_appyml_observe
    provider: github
    args: [file, get, "${organization}/${repository}", "src/main/resources/application.yml"]

  - id: file_appyml_put
    needs: [file_appyml_observe]
    when: [{ref: steps.file_appyml_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - "src/main/resources/application.yml"
      - "message=chore(onboard): add application.yml"
      - |
        content=spring:
          application:
            name: ${service_name}
          lifecycle:
            timeout-per-shutdown-phase: 20s

        server:
          port: $${PORT:8080}
          shutdown: graceful

        management:
          endpoints:
            web:
              exposure:
                include: health,info
          endpoint:
            health:
              probes:
                enabled: true

  - id: file_appyml_verify
    needs: [file_appyml_put]
    provider: github
    args: [file, get, "${organization}/${repository}", "src/main/resources/application.yml"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_appyml_verify.outputs.name, equals: "application.yml"}

  - id: file_app_observe
    provider: github
    args: [file, get, "${organization}/${repository}", "src/main/java/${java_package_path}/Application.java"]

  - id: file_app_put
    needs: [file_app_observe]
    when: [{ref: steps.file_app_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - "src/main/java/${java_package_path}/Application.java"
      - "message=chore(onboard): add Application.java"
      - |
        content=package ${java_package};

        import org.springframework.boot.SpringApplication;
        import org.springframework.boot.autoconfigure.SpringBootApplication;

        @SpringBootApplication
        public class Application {

            public static void main(String[] args) {
                SpringApplication.run(Application.class, args);
            }
        }

  - id: file_app_verify
    needs: [file_app_put]
    provider: github
    args: [file, get, "${organization}/${repository}", "src/main/java/${java_package_path}/Application.java"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_app_verify.outputs.name, equals: "Application.java"}

  - id: file_controller_observe
    provider: github
    args: [file, get, "${organization}/${repository}", "src/main/java/${java_package_path}/api/GreetingController.java"]

  - id: file_controller_put
    needs: [file_controller_observe]
    when: [{ref: steps.file_controller_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - "src/main/java/${java_package_path}/api/GreetingController.java"
      - "message=chore(onboard): add GreetingController.java"
      - |
        content=package ${java_package}.api;

        import jakarta.validation.constraints.NotBlank;
        import jakarta.validation.constraints.Size;
        import org.springframework.beans.factory.annotation.Value;
        import org.springframework.web.bind.annotation.GetMapping;
        import org.springframework.web.bind.annotation.RequestMapping;
        import org.springframework.web.bind.annotation.RequestParam;
        import org.springframework.web.bind.annotation.RestController;

        @RestController
        @RequestMapping("/api/v1")
        public class GreetingController {

            private final String serviceName;

            public GreetingController(@Value("$${spring.application.name}") String serviceName) {
                this.serviceName = serviceName;
            }

            @GetMapping("/greeting")
            public Greeting greet(@RequestParam(defaultValue = "world") @NotBlank @Size(max = 64) String name) {
                return new Greeting(serviceName, "Hello, " + name);
            }

            public record Greeting(String service, String message) {
            }
        }

  - id: file_controller_verify
    needs: [file_controller_put]
    provider: github
    args: [file, get, "${organization}/${repository}", "src/main/java/${java_package_path}/api/GreetingController.java"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_controller_verify.outputs.name, equals: "GreetingController.java"}

  - id: file_tests_observe
    provider: github
    args: [file, get, "${organization}/${repository}", "src/test/java/${java_package_path}/ApplicationTests.java"]

  - id: file_tests_put
    needs: [file_tests_observe]
    when: [{ref: steps.file_tests_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - "src/test/java/${java_package_path}/ApplicationTests.java"
      - "message=chore(onboard): add ApplicationTests.java"
      - |
        content=package ${java_package};

        import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
        import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
        import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

        import org.junit.jupiter.api.Test;
        import org.springframework.beans.factory.annotation.Autowired;
        import org.springframework.boot.test.context.SpringBootTest;
        import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
        import org.springframework.test.web.servlet.MockMvc;

        @SpringBootTest
        @AutoConfigureMockMvc
        class ApplicationTests {

            @Autowired
            private MockMvc mvc;

            @Test
            void greetingNamesTheService() throws Exception {
                mvc.perform(get("/api/v1/greeting").param("name", "ci"))
                        .andExpect(status().isOk())
                        .andExpect(jsonPath("$.service").value("${service_name}"))
                        .andExpect(jsonPath("$.message").value("Hello, ci"));
            }

            @Test
            void overlongNameIsRejected() throws Exception {
                mvc.perform(get("/api/v1/greeting").param("name", "x".repeat(65)))
                        .andExpect(status().isBadRequest());
            }

            @Test
            void healthIsUp() throws Exception {
                mvc.perform(get("/actuator/health"))
                        .andExpect(status().isOk())
                        .andExpect(jsonPath("$.status").value("UP"));
            }
        }

  - id: file_tests_verify
    needs: [file_tests_put]
    provider: github
    args: [file, get, "${organization}/${repository}", "src/test/java/${java_package_path}/ApplicationTests.java"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_tests_verify.outputs.name, equals: "ApplicationTests.java"}

  - id: file_dockerfile_observe
    provider: github
    args: [file, get, "${organization}/${repository}", "Dockerfile"]

  - id: file_dockerfile_put
    needs: [file_dockerfile_observe]
    when: [{ref: steps.file_dockerfile_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - "Dockerfile"
      - "message=chore(onboard): add Dockerfile"
      - |
        content=FROM maven:3.9-eclipse-temurin-${java_version} AS build
        WORKDIR /workspace
        COPY pom.xml .
        RUN mvn -B -ntp -q dependency:go-offline
        COPY src ./src
        RUN mvn -B -ntp -q package -DskipTests

        FROM eclipse-temurin:${java_version}-jre
        RUN groupadd --system app && useradd --system --gid app --no-create-home app
        WORKDIR /app
        COPY --from=build /workspace/target/*.jar /app/app.jar
        USER app
        EXPOSE 8080
        ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/app.jar"]

  - id: file_dockerfile_verify
    needs: [file_dockerfile_put]
    provider: github
    args: [file, get, "${organization}/${repository}", "Dockerfile"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_dockerfile_verify.outputs.name, equals: "Dockerfile"}

  - id: file_ci_observe
    provider: github
    args: [file, get, "${organization}/${repository}", ".github/workflows/ci.yml"]

  - id: file_ci_put
    needs: [file_ci_observe]
    when: [{ref: steps.file_ci_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - ".github/workflows/ci.yml"
      - "message=chore(onboard): add ci.yml"
      - |
        content=name: ci

        on:
          pull_request:
          push:
            branches: [main]
          workflow_dispatch:

        permissions:
          contents: read

        concurrency:
          group: ci-$${{ github.ref }}
          cancel-in-progress: $${{ github.event_name == 'pull_request' }}

        jobs:
          build:
            name: build
            runs-on: ubuntu-latest
            timeout-minutes: 15
            steps:
              - name: Check out
                uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
                with:
                  persist-credentials: false

              - name: Set up JDK ${java_version}
                uses: actions/setup-java@77dd5b2ce225ea11469928ac317850245a74ae78 # v6.2.0
                with:
                  distribution: temurin
                  java-version: "${java_version}"
                  cache: maven

              - name: Build and test
                run: mvn -B -ntp verify

              - name: Upload test reports
                if: always()
                uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
                with:
                  name: test-reports
                  path: target/surefire-reports/
                  retention-days: 7
                  if-no-files-found: ignore

  - id: file_ci_verify
    needs: [file_ci_put]
    provider: github
    args: [file, get, "${organization}/${repository}", ".github/workflows/ci.yml"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_ci_verify.outputs.name, equals: "ci.yml"}

  # ==== 6. Rulesets, last: once the pull-request rule is on, nothing can commit to main directly ====
  # GitHub lists a repository's rulesets sorted by name (observed 2026-11-06),
  # and the two onboarding names sort in creation order. Onboarding expects
  # none or exactly its own two; any other repository ruleset fails the
  # verification and nothing is overwritten.
  - id: ruleset_branch_observe
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 3, includeParents: false) { totalCount nodes { name target enforcement } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      total: {pointer: /repository/rulesets/totalCount, type: integer}

  - id: ruleset_branch_create
    needs: [ruleset_branch_observe]
    when: [{ref: steps.ruleset_branch_observe.outputs.total, equals: "0"}]
    provider: github
    args:
      - api
      - POST
      - "/repos/${organization}/${repository}/rulesets"
      - "name=engrt-onboard-default-branch"
      - "target=branch"
      - "enforcement=active"
      - "bypass_actors:=[]"
      - 'conditions:={"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}}'
      - 'rules:=[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"required_linear_history"},{"type":"pull_request","parameters":{"required_approving_review_count":${required_approvals},"dismiss_stale_reviews_on_push":true,"require_code_owner_review":${require_code_owner_review},"require_last_push_approval":false,"required_review_thread_resolution":true,"allowed_merge_methods":["squash"]}},{"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":true,"do_not_enforce_on_create":false,"required_status_checks":[{"context":"build","integration_id":15368}]}}]'

  - id: ruleset_branch_verify
    needs: [ruleset_branch_create]
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 3, includeParents: false) { totalCount nodes { name target enforcement } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      name: {pointer: /repository/rulesets/nodes/0/name, type: string}
      target: {pointer: /repository/rulesets/nodes/0/target, type: string}
      enforcement: {pointer: /repository/rulesets/nodes/0/enforcement, type: string}
    expect:
      - {ref: steps.ruleset_branch_verify.outputs.name, equals: engrt-onboard-default-branch}
      - {ref: steps.ruleset_branch_verify.outputs.target, equals: BRANCH}
      - {ref: steps.ruleset_branch_verify.outputs.enforcement, equals: ACTIVE}

  - id: ruleset_branch_rules_verify
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 1, includeParents: false) { nodes { deletion: rules(first: 1, type: DELETION) { totalCount } force: rules(first: 1, type: NON_FAST_FORWARD) { totalCount } pr: rules(first: 1, type: PULL_REQUEST) { totalCount } checks: rules(first: 1, type: REQUIRED_STATUS_CHECKS) { totalCount } } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      deletion: {pointer: /repository/rulesets/nodes/0/deletion/totalCount, type: integer}
      force: {pointer: /repository/rulesets/nodes/0/force/totalCount, type: integer}
      pr: {pointer: /repository/rulesets/nodes/0/pr/totalCount, type: integer}
      checks: {pointer: /repository/rulesets/nodes/0/checks/totalCount, type: integer}
    expect:
      - {ref: steps.ruleset_branch_rules_verify.outputs.deletion, equals: "1"}
      - {ref: steps.ruleset_branch_rules_verify.outputs.force, equals: "1"}
      - {ref: steps.ruleset_branch_rules_verify.outputs.pr, equals: "1"}
      - {ref: steps.ruleset_branch_rules_verify.outputs.checks, equals: "1"}

  - id: ruleset_tags_observe
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 3, includeParents: false) { totalCount nodes { name target enforcement } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      total: {pointer: /repository/rulesets/totalCount, type: integer}
      first: {pointer: /repository/rulesets/nodes/0/name, type: string, optional: true}

  - id: ruleset_tags_create
    needs: [ruleset_tags_observe]
    when:
      - {ref: steps.ruleset_tags_observe.outputs.total, equals: "1"}
      - {ref: steps.ruleset_tags_observe.outputs.first, equals: engrt-onboard-default-branch}
    provider: github
    args:
      - api
      - POST
      - "/repos/${organization}/${repository}/rulesets"
      - "name=engrt-onboard-release-tags"
      - "target=tag"
      - "enforcement=active"
      - "bypass_actors:=[]"
      - 'conditions:={"ref_name":{"include":["refs/tags/v*"],"exclude":[]}}'
      - 'rules:=[{"type":"deletion"},{"type":"update"}]'

  - id: ruleset_tags_verify
    needs: [ruleset_tags_create]
    provider: github
    args: [graphql, "query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { rulesets(first: 3, includeParents: false) { totalCount nodes { name target enforcement } } } }", "owner=${organization}", "name=${repository}"]
    outputs:
      total: {pointer: /repository/rulesets/totalCount, type: integer}
      name: {pointer: /repository/rulesets/nodes/1/name, type: string}
      target: {pointer: /repository/rulesets/nodes/1/target, type: string}
      enforcement: {pointer: /repository/rulesets/nodes/1/enforcement, type: string}
    expect:
      - {ref: steps.ruleset_tags_verify.outputs.total, equals: "2"}
      - {ref: steps.ruleset_tags_verify.outputs.name, equals: engrt-onboard-release-tags}
      - {ref: steps.ruleset_tags_verify.outputs.target, equals: TAG}
      - {ref: steps.ruleset_tags_verify.outputs.enforcement, equals: ACTIVE}

  # ==== 7. The pipeline: the ci.yml commit started the first run ====
  - id: pipeline_runs
    provider: github
    args: [run, list, --repo, "${organization}/${repository}", --limit, "5"]
```
