# Switch on a repository's GitHub security features and prove they are on

> **Mutating.** It enables security features on a repository. It never turns
> one off. Run `plan` first.

Audits say what is off; this turns it on. Each feature is read, enabled only
when off, and read back.

| Feature | Why | Repositories |
|---|---|---|
| Dependabot alerts | known-vulnerable dependencies are reported | all |
| Dependabot security updates | Dependabot opens the fixing pull request | all |
| Secret scanning | committed credentials are detected | public |
| Push protection | a push containing a credential is blocked before it lands | public |
| Private vulnerability reporting | outsiders can report a vulnerability privately instead of in a public issue | public |

On a **private** repository the last three are not changed: GitHub offers
secret scanning on private repositories only with GitHub Secret Protection,
and private vulnerability reporting only on public repositories (its endpoint
answers 404 on a private one). The run still reports
them: `private_secret_scanning_status` runs on a private repository and reads
the current secret-scanning status back, so the result shows it rather than
hiding it.

| Run | Result |
|---|---|
| public repository, features off | all five enabled and verified (`APPLIED`) |
| private repository | the two Dependabot features enabled; secret-scanning status reported |
| rerun | everything read and verified, nothing written (`SATISFIED`) |

## What it needs

- Policy: the GitHub provider with `graphql`, `api GET`, `api PUT` and
  `api PATCH`.
- Credential: repository Administration read/write (security settings), plus
  Dependabot alerts read.

## Known limits

- Secret scanning on private repositories (GitHub Secret Protection) is not
  attempted. An organization that has it can extend this capability.
- Push protection is enabled after secret scanning, which GitHub requires.
- CodeQL code scanning is not included: its default setup starts workflow
  runs, which cost Actions minutes, so it belongs in its own capability.

## Run it

```bash
engrt capability plan github/repo-security-features-enable \
  --input organization=<organization> --input repository=<repository>
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

workflow:
  # ==== Dependabot alerts (all repositories) ====
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

  # ==== Dependabot security updates (all repositories; needs alerts) ====
  - id: security_updates_observe
    needs: [alerts_verify]
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

  # ==== Visibility decides what else GitHub offers ====
  - id: settings_observe
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}"]
    outputs:
      visibility: {pointer: /visibility, type: string}
      secret_scanning: {pointer: /security_and_analysis/secret_scanning/status, type: string, optional: true}
      push_protection: {pointer: /security_and_analysis/secret_scanning_push_protection/status, type: string, optional: true}

  # ==== Secret scanning (public repositories) ====
  - id: secret_scanning_enable
    needs: [settings_observe]
    when:
      - {ref: steps.settings_observe.outputs.visibility, equals: public}
      - {ref: steps.settings_observe.outputs.secret_scanning, not_equals: enabled}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}", 'security_and_analysis:={"secret_scanning":{"status":"enabled"}}']

  - id: secret_scanning_verify
    needs: [settings_observe, secret_scanning_enable]
    when: [{ref: steps.settings_observe.outputs.visibility, equals: public}]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}"]
    outputs:
      status: {pointer: /security_and_analysis/secret_scanning/status, type: string, optional: true}
    expect:
      - {ref: steps.secret_scanning_verify.outputs.status, equals: enabled}

  # ==== Push protection (public repositories; needs secret scanning) ====
  - id: push_protection_enable
    needs: [settings_observe, secret_scanning_verify]
    when:
      - {ref: steps.settings_observe.outputs.visibility, equals: public}
      - {ref: steps.settings_observe.outputs.push_protection, not_equals: enabled}
    provider: github
    args: [api, PATCH, "/repos/${organization}/${repository}", 'security_and_analysis:={"secret_scanning_push_protection":{"status":"enabled"}}']

  - id: push_protection_verify
    needs: [settings_observe, push_protection_enable]
    when: [{ref: steps.settings_observe.outputs.visibility, equals: public}]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}"]
    outputs:
      status: {pointer: /security_and_analysis/secret_scanning_push_protection/status, type: string, optional: true}
    expect:
      - {ref: steps.push_protection_verify.outputs.status, equals: enabled}

  # ==== Private vulnerability reporting (public repositories only) ====
  - id: vulnerability_reporting_observe
    needs: [settings_observe]
    when: [{ref: steps.settings_observe.outputs.visibility, equals: public}]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/private-vulnerability-reporting"]
    outputs:
      on: {pointer: /enabled, type: boolean}

  - id: vulnerability_reporting_enable
    needs: [vulnerability_reporting_observe]
    when: [{ref: steps.vulnerability_reporting_observe.outputs.on, equals: "false"}]
    provider: github
    args: [api, PUT, "/repos/${organization}/${repository}/private-vulnerability-reporting"]

  - id: vulnerability_reporting_verify
    needs: [settings_observe, vulnerability_reporting_enable]
    when: [{ref: steps.settings_observe.outputs.visibility, equals: public}]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/private-vulnerability-reporting"]
    outputs:
      on: {pointer: /enabled, type: boolean}
    expect:
      - {ref: steps.vulnerability_reporting_verify.outputs.on, equals: "true"}

  # ==== Private repository: report, do not change ====
  - id: private_secret_scanning_status
    needs: [settings_observe]
    when: [{ref: steps.settings_observe.outputs.visibility, not_equals: public}]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}"]
    outputs:
      visibility: {pointer: /visibility, type: string}
      secret_scanning: {pointer: /security_and_analysis/secret_scanning/status, type: string, optional: true}
```
