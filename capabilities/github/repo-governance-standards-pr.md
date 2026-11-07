# Bring an existing repository up to engineering standards through a pull request

> **Mutating.** It creates a branch, commits files to it and opens a pull
> request. It never writes to the default branch. Run `plan` first. Execute
> only when the owning team has asked for that exact repository.

Most repositories predate the organization's standards, and their default
branch is protected, so standards arrive the way any change does: as a pull
request the owning team reviews and merges.

1. Branch `branch` is cut from the current default branch head when absent.
   An existing branch is reused **only** when it carries this capability's
   own open pull request (title `chore: adopt engineering standards`);
   `branch_safety_gate` stops the run before any write otherwise.
2. Each standard file is committed to that branch **only if the repository
   does not already have it**. Existing files are never replaced:

   | File | Purpose |
   |---|---|
   | `SECURITY.md` | private vulnerability reporting |
   | `.github/CODEOWNERS` | default owner for review routing |
   | `.github/pull_request_template.md` | what, why, how tested, checklist |
   | `.github/dependabot.yml` | weekly updates for `dependabot_ecosystem` and for Actions |
   | `CONTRIBUTING.md` | branch, commit and review conventions |

3. One pull request into the default branch is opened, **only when the branch
   actually has commits to propose** and no pull request from it is open yet.

| Run | Result |
|---|---|
| repository missing standards | branch, commits and one pull request |
| `branch` exists without this capability's open pull request | stops at `branch_safety_gate`; nothing written |
| the pull request changes more than the five standard files | stops at `pr_scope_gate` (the pull request stays open for review) |
| rerun while the pull request is open | nothing written; the open pull request is reported |
| repository already has every file | branch created with no commits; no pull request (`pr_status` reports none) |

## What it needs

- Policy: the GitHub provider with `api GET` and `api POST`, `file get` and
  `file put`. No binaries, no file roots, nothing cloned.
- Credential: Contents and Pull requests read/write (classic token: `repo`).

## Known limits

- `pr_scope_gate` bounds the pull request at five changed files. It does not
  check each file name: a commit someone else pushed to the branch that
  replaces one standard file with another file passes the count. Reviewers
  see the file list in the pull request.
- The reuse check trusts the pull request title. Anyone who can open a pull
  request with that title on that branch can make the branch look reusable.
- The branch is not deleted when nothing was proposed (policy denies
  `api DELETE`); delete it with `engrt command run git -C <clone> push origin
  --delete <branch>` if your policy allows that, or in the UI.
- `dependabot.yml` names one package ecosystem (`maven`, `gradle`, `npm`,
  `pip`, `gomod`, `docker`, ...); add more in review.

## Run it

```bash
engrt capability plan github/repo-governance-standards-pr \
  --input organization=<organization> --input repository=<legacy-repo> \
  --input branch=chore/engineering-standards \
  --input code_owner=<github-user-or-org/team> --input dependabot_ecosystem=maven
```

```runtime
version: v1
capability_version: "1.1.0"
engrt_version: ">=0.13.0"

inputs:
  organization:
    description: GitHub organization that owns the repository
    required: true
  repository:
    description: Existing repository name without the owner
    required: true
  branch:
    description: New branch for the change, e.g. chore/engineering-standards
    required: true
  code_owner:
    description: Default code owner without the @, a user (octocat) or a team (my-org/platform)
    required: true
  dependabot_ecosystem:
    description: Dependabot package ecosystem for the repository's main language, e.g. maven, npm, gomod, pip
    required: true

workflow:
  # ==== Branch from the current default branch head ====
  - id: base_observe
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $branch: String!) { repository(owner: $owner, name: $name) { defaultBranchRef { name target { oid } } branch: ref(qualifiedName: $branch) { name } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "branch=refs/heads/${branch}"
    outputs:
      base: {pointer: /repository/defaultBranchRef/name, type: string}
      base_commit: {pointer: /repository/defaultBranchRef/target/oid, type: string}
      branch: {pointer: /repository/branch/name, type: string, optional: true}

  # An existing branch is reused only when it carries this capability's own
  # open pull request. Any other branch with that name stops the run before a
  # file is written to it.
  - id: branch_safety_gate
    needs: [base_observe]
    when: [{ref: steps.base_observe.outputs.branch, exists: true}]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $head: String!) { repository(owner: $owner, name: $name) { pullRequests(headRefName: $head, states: OPEN, first: 1) { totalCount nodes { title } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "head=${branch}"
    outputs:
      open: {pointer: /repository/pullRequests/totalCount, type: integer}
      title: {pointer: /repository/pullRequests/nodes/0/title, type: string, optional: true}
    expect:
      - {ref: steps.branch_safety_gate.outputs.open, equals: "1"}
      - {ref: steps.branch_safety_gate.outputs.title, equals: "chore: adopt engineering standards"}

  - id: branch_create
    needs: [base_observe]
    when: [{ref: steps.base_observe.outputs.branch, missing: true}]
    provider: github
    args: [api, POST, "/repos/${organization}/${repository}/git/refs", "ref=refs/heads/${branch}", "sha=${steps.base_observe.outputs.base_commit}"]

  - id: branch_verify
    needs: [branch_create]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $branch: String!) { repository(owner: $owner, name: $name) { ref(qualifiedName: $branch) { name } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "branch=refs/heads/${branch}"
    outputs:
      branch: {pointer: /repository/ref/name, type: string}
    expect:
      - {ref: steps.branch_verify.outputs.branch, equals: "${branch}"}

  # ==== Standard files: committed to the branch only when absent ====
  - id: file_security_observe
    provider: github
    args: [file, get, "${organization}/${repository}", SECURITY.md, "ref=${branch}"]

  - id: file_security_put
    needs: [file_security_observe]
    when: [{ref: steps.file_security_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - SECURITY.md
      - "message=chore(standards): add SECURITY.md"
      - "branch=${branch}"
      - |
        content=# Security policy

        Report a suspected vulnerability privately to the code owners listed in
        `.github/CODEOWNERS`. Do not open a public issue or pull request for it.

        Include what is affected, how to reproduce it and the impact you expect.
        You will get an acknowledgement, and the fix ships through the normal
        reviewed pull-request flow of this repository.

  - id: file_security_verify
    needs: [file_security_put]
    provider: github
    args: [file, get, "${organization}/${repository}", SECURITY.md, "ref=${branch}"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_security_verify.outputs.name, equals: SECURITY.md}

  - id: file_codeowners_observe
    provider: github
    args: [file, get, "${organization}/${repository}", .github/CODEOWNERS, "ref=${branch}"]

  - id: file_codeowners_put
    needs: [file_codeowners_observe]
    when: [{ref: steps.file_codeowners_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - .github/CODEOWNERS
      - "message=chore(standards): add CODEOWNERS"
      - "branch=${branch}"
      - |
        content=# Default owner for every path. Add narrower rules below it.
        * @${code_owner}

  - id: file_codeowners_verify
    needs: [file_codeowners_put]
    provider: github
    args: [file, get, "${organization}/${repository}", .github/CODEOWNERS, "ref=${branch}"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_codeowners_verify.outputs.name, equals: CODEOWNERS}

  - id: file_prtemplate_observe
    provider: github
    args: [file, get, "${organization}/${repository}", .github/pull_request_template.md, "ref=${branch}"]

  - id: file_prtemplate_put
    needs: [file_prtemplate_observe]
    when: [{ref: steps.file_prtemplate_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - .github/pull_request_template.md
      - "message=chore(standards): add pull request template"
      - "branch=${branch}"
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
    args: [file, get, "${organization}/${repository}", .github/pull_request_template.md, "ref=${branch}"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_prtemplate_verify.outputs.name, equals: pull_request_template.md}

  - id: file_dependabot_observe
    provider: github
    args: [file, get, "${organization}/${repository}", .github/dependabot.yml, "ref=${branch}"]

  - id: file_dependabot_put
    needs: [file_dependabot_observe]
    when: [{ref: steps.file_dependabot_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - .github/dependabot.yml
      - "message=chore(standards): add Dependabot configuration"
      - "branch=${branch}"
      - |
        content=version: 2
        updates:
          - package-ecosystem: ${dependabot_ecosystem}
            directory: /
            schedule:
              interval: weekly
            open-pull-requests-limit: 5
          - package-ecosystem: github-actions
            directory: /
            schedule:
              interval: weekly
            open-pull-requests-limit: 5

  - id: file_dependabot_verify
    needs: [file_dependabot_put]
    provider: github
    args: [file, get, "${organization}/${repository}", .github/dependabot.yml, "ref=${branch}"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_dependabot_verify.outputs.name, equals: dependabot.yml}

  - id: file_contributing_observe
    provider: github
    args: [file, get, "${organization}/${repository}", CONTRIBUTING.md, "ref=${branch}"]

  - id: file_contributing_put
    needs: [file_contributing_observe]
    when: [{ref: steps.file_contributing_observe.observation, equals: ABSENT}]
    provider: github
    args:
      - file
      - put
      - "${organization}/${repository}"
      - CONTRIBUTING.md
      - "message=chore(standards): add CONTRIBUTING.md"
      - "branch=${branch}"
      - |
        content=# Contributing

        1. Branch from the latest default branch. Name it after the change,
           e.g. `fix/timeout-on-retry` or `feat/refund-endpoint`.
        2. Keep commits focused, with messages that say what changed and why
           (Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`).
        3. Open a pull request using the template. CI must pass and every
           review conversation must be resolved before merge.
        4. Merges are squash merges; the pull request title becomes the commit
           title.
        5. Never commit credentials, tokens or personal data. Report security
           problems as described in `SECURITY.md`.

  - id: file_contributing_verify
    needs: [file_contributing_put]
    provider: github
    args: [file, get, "${organization}/${repository}", CONTRIBUTING.md, "ref=${branch}"]
    outputs:
      name: {pointer: /name, type: string}
    expect:
      - {ref: steps.file_contributing_verify.outputs.name, equals: CONTRIBUTING.md}

  # ==== Pull request: only when the branch has commits and none is open ====
  - id: pr_observe
    needs: [base_observe]
    provider: github
    args:
      - graphql
      - "query($owner: String!, $name: String!, $base: String!, $head: String!, $headName: String!) { repository(owner: $owner, name: $name) { pullRequests(headRefName: $headName, states: OPEN) { totalCount } ref(qualifiedName: $base) { compare(headRef: $head) { aheadBy } } } }"
      - "owner=${organization}"
      - "name=${repository}"
      - "base=refs/heads/${steps.base_observe.outputs.base}"
      - "head=refs/heads/${branch}"
      - "headName=${branch}"
    outputs:
      open: {pointer: /repository/pullRequests/totalCount, type: integer}
      ahead: {pointer: /repository/ref/compare/aheadBy, type: integer}

  - id: pr_create
    needs: [pr_observe, base_observe]
    when:
      - {ref: steps.pr_observe.outputs.open, equals: "0"}
      - {ref: steps.pr_observe.outputs.ahead, not_equals: "0"}
    provider: github
    args:
      - api
      - POST
      - "/repos/${organization}/${repository}/pulls"
      - "title=chore: adopt engineering standards"
      - "head=${branch}"
      - "base=${steps.base_observe.outputs.base}"
      - |
        body=## What and why

        Adds the organization's engineering standards that this repository
        does not have yet: security reporting, code ownership, a pull-request
        template, Dependabot updates and contribution conventions. Files the
        repository already had are untouched.

        ## How it was made

        Opened by the Engineering Runtime capability
        `github/repo-governance-standards-pr`. Every commit and this pull
        request are in the operator's Runtime audit log.

        ## Review

        Check `.github/CODEOWNERS` names the right owner and
        `.github/dependabot.yml` the right ecosystem before merging.

  - id: pr_status
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/pulls", "head=${organization}:${branch}", "state=open", "per_page=1"]
    outputs:
      number: {pointer: /0/number, type: integer, optional: true}
      url: {pointer: /0/html_url, type: string, optional: true}
      title: {pointer: /0/title, type: string, optional: true}

  # The pull request may change only the five standard files. GitHub lists a
  # pull request's files; a sixth entry means something else is in it.
  - id: pr_scope_gate
    needs: [pr_status]
    when: [{ref: steps.pr_status.outputs.number, exists: true}]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/pulls/${steps.pr_status.outputs.number}/files", "per_page=6"]
    outputs:
      sixth_file: {pointer: /5/filename, type: string, optional: true}
    expect:
      - {ref: steps.pr_scope_gate.outputs.sixth_file, missing: true}
```
