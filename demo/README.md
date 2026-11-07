# Try every capability on demo repositories

[`run-demo.sh`](run-demo.sh) runs every capability in this catalogue through
`engrt`, using [`configs/config.yaml`](../configs/config.yaml) and
[`configs/policy.yaml`](../configs/policy.yaml). A pass here means the
capability works with those two files as published.

> **Mutating.** The script creates two repositories and a team in the
> organization you name, pushes commits, opens and merges a pull request,
> publishes a release, runs GitHub Actions workflows and archives one of the
> repositories. Use an organization where that is acceptable. Nothing is
> deleted: the example policy denies `api DELETE`.

## What it builds

| Repository | Role |
|---|---|
| `engrt-capabilities-demo` | A Spring Boot service created by `java-springboot-service-onboard`, then taken through its lifecycle. It stays as the demo repository. |
| `engrt-capabilities-demo-legacy` | A plain repository standing in for an existing service. It receives a standards pull request, a scaffolded Java service and the default ruleset, then is retired with `repo-decommission` (archived). |

Plus the team `engrt-capabilities-demo-reviewers`, used as the production
environment's required reviewers. On a public demo repository the script also
turns on CodeQL default setup (free for public repositories), so
`github-security-posture` has code-scanning results to read.

## Phases

| Phase | What happens |
|---|---|
| `check` | `engrt`, `jq`, config, policy and GitHub authority; touches nothing |
| `setup` | onboard the demo service (and rerun it), create the legacy repository, wait for the first CI build |
| `flow` | security features, labels, team access, environment protection and branch policies, a feature pull request with its reads, merge when ready, release, deployment, drift check, change freeze and lift |
| `read` | every read-only capability against the demo repository and organization |
| `legacy` | standards pull request, scaffold-and-ship, default ruleset and its reconcile, decommission |
| `local` | the File Engine round trip and local-checkout delivery readiness |

Mutating capabilities are run twice where it matters: the rerun must succeed
and write nothing. Refusals are tested too. Each of these must stop at the
named gate, before any write:

| Case | Must stop at |
|---|---|
| merge with a SHA that is not the pull request head | `head_gate` |
| release of a commit that does not exist | `commit_gate` |
| deploy of a version that was never released | `release_gate` |
| change freeze on a repository without the onboarding rulesets | `layout_gate` |
| decommission while a pull request is open | `open_work_gate` |

## Run it

Prerequisites: `engrt` 0.13.0 or later, `jq`, `gh` and `git` on `PATH`, and a
GitHub token in `ENGRT_GITHUB_TOKEN` (the config's `source: env`) for a user
who can create repositories and teams in the organization.
A classic token needs `repo`, `workflow` and `admin:org`.

```bash
cd engineering-runtime-capabilities
mkdir -p ../demo-run && cd ../demo-run      # local phases write under ./engrt-demo-work
bash ../engineering-runtime-capabilities/demo/run-demo.sh <organization> check
bash ../engineering-runtime-capabilities/demo/run-demo.sh <organization>          # all phases
```

Every run is appended to Runtime's evidence journal, so a long-used Runtime
home slows each run down. For a quick demo, use a fresh one:
`export ENGRT_HOME="$HOME/.engrt-demo"`.

Or one phase at a time: `run-demo.sh <organization> setup`, then `flow`,
`read`, `legacy`, `local`. Phases after `setup` expect the repositories it
created. A full run takes about 15 to 25 minutes, most of it waiting for
GitHub Actions.

Results go to `demo/results/<organization>-<repository>/`: one JSON result per
capability run and `summary.tsv` with the verdict, the step a run stopped at,
step counts and timing. The script exits non-zero if any case fails.

Settings: `DEMO_REPO`, `DEMO_LEGACY_REPO`, `DEMO_TEAM`, `DEMO_PRIVATE=true`
(private repositories; on GitHub Free and Team that turns the
public-only security features and environment protection into expected plan
limits), `DEMO_CONFIG` and `DEMO_POLICY` to test your own documents instead of
the ones in `configs/`. The script header lists them all.

## Results

The latest recorded run is in [RESULTS.md](RESULTS.md).
