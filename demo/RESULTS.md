# Demo results

| Field | Value |
|---|---|
| Date | 2026-11-07 (UTC) |
| Runtime | `engrt 0.13.0`, Homebrew, macOS arm64 |
| Config and policy | [`examples/config.yaml`](../examples/config.yaml), [`examples/policy.yaml`](../examples/policy.yaml), unchanged |
| GitHub authority | a classic user token in `ENGRT_GITHUB_TOKEN`, from an organization owner |
| Organization | `engineeringruntime` |
| Repositories | [`engrt-capabilities-demo`](https://github.com/engineeringruntime/engrt-capabilities-demo) (public, kept as the demo), `engrt-capabilities-demo-legacy` (public, archived by `repo-decommission`) |
| Script | [`run-demo.sh`](run-demo.sh), phases `setup`, `flow`, `read`, `legacy`, `local` |

**73 of 73 capabilities passed. 91 of 91 cases passed**, including 7 that must stop at a named step before any write.

## What the run proved

- Every mutating capability's rerun succeeded and wrote nothing. Onboarding is
  the documented exception: its three environment `PUT`s re-send unchanged
  values on every run (32 `SATISFIED`, 3 `APPLIED`).
- Every refusal stopped at its gate with nothing written: a merge at a SHA
  that is not the pull request head (`head_gate`), a release of an unknown
  commit (`commit_gate`), a deploy of an unreleased version (`release_gate`),
  a freeze on a repository without the onboarding rulesets (`layout_gate`),
  and decommission while a pull request is open (`open_work_gate`).
- The onboarded repository has **0** drift from the standard in
  `repo-standards-drift`; the legacy repository has 12.
- GitHub's state was read back independently afterwards: the demo
  repository is squash-only with the two onboarding rulesets active and the
  freeze ruleset disabled, release `v0.1.0` is on the merge commit of pull
  request #1, `v0.1.0` is deployed to `staging`, `production` has required
  reviewers and a wait timer, and the legacy repository is archived.

## Read before you rely on these

- **`github-repo-branches-and-protection` and `github-branch-protection-audit`**
  read classic branch protection. The demo repository is protected by
  rulesets, so GitHub answers `404` and both stop there, as their files say.
  The demo records this as the expected result. Use
  `github-repo-rulesets-export` or `repo-standards-drift` for a
  ruleset-protected repository.
- **`github-security-posture`** needs code scanning set up. The first read run
  stopped at the code-scanning step with `404`; the script now turns on
  CodeQL default setup for public demo repositories, and it then passed.
- `org-standards-drift` reported 5 drifted organization controls. That is a
  finding about the organization, not a failure: drift checks never fail on
  drift.
- Runtime appends every run to its evidence journal. A long-used Runtime home
  made each run several times slower here (23 s against 7 s for the same
  8-step read); the demo used a fresh `ENGRT_HOME`.

## Every case

| # | Phase | Case | Capability | Expected | Result | Stopped at | s |
|---|---|---|---|---|---|---|---|
| 1 | setup | onboard | `github/java-springboot-service-onboard` | success | **PASS** success |  | 88 |
| 2 | setup | onboard-rerun | `github/java-springboot-service-onboard` | success | **PASS** success |  | 52 |
| 3 | flow | security-features | `github/repo-security-features-enable` | success | **PASS** success |  | 13 |
| 4 | flow | labels | `github/repo-labels-standard-sync` | success | **PASS** success |  | 44 |
| 5 | flow | labels-rerun | `github/repo-labels-standard-sync` | success | **PASS** success |  | 33 |
| 6 | flow | team-access | `github/org-team-repo-access` | success | **PASS** success |  | 8 |
| 7 | flow | env-protect | `github/repo-environment-protect` | success | **PASS** success |  | 14 |
| 8 | flow | env-protect-rerun | `github/repo-environment-protect` | success | **PASS** success |  | 11 |
| 9 | flow | env-create | `github/repo-environment-create` | success | **PASS** success |  | 2 |
| 10 | flow | env-branch-policy | `github/repo-environment-branch-policy-add` | success | **PASS** success |  | 3 |
| 11 | flow | env-tag-policy | `github/repo-environment-branch-policy-add` | success | **PASS** success |  | 2 |
| 12 | flow | env-variable | `github/repo-environment-variable-set` | success | **PASS** success |  | 2 |
| 13 | flow | pr-review-readiness | `github/github-pr-review-readiness` | success | **PASS** success |  | 3 |
| 14 | flow | pr-review | `github/github-pr-review` | success | **PASS** success |  | 3 |
| 15 | flow | pr-status | `github/github-pr-status` | success | **PASS** success |  | 2 |
| 16 | flow | pr-changed-files | `github/github-pr-changed-files` | success | **PASS** success |  | 1 |
| 17 | flow | pr-commits | `github/github-pr-commits` | success | **PASS** success |  | 2 |
| 18 | flow | pr-labels-assignees | `github/github-pr-labels-and-assignees` | success | **PASS** success |  | 2 |
| 19 | flow | pr-reviews | `github/github-pr-reviews` | success | **PASS** success |  | 2 |
| 20 | flow | review-queue | `github/github-review-queue` | success | **PASS** success |  | 2 |
| 21 | flow | merge-wrong-sha | `github/repo-pr-merge-when-ready` | stop at `head_gate` | **PASS** failure | `head_gate` | 3 |
| 22 | flow | merge | `github/repo-pr-merge-when-ready` | success | **PASS** success |  | 8 |
| 23 | flow | merge-rerun | `github/repo-pr-merge-when-ready` | success | **PASS** success |  | 3 |
| 24 | flow | release-unknown-commit | `github/repo-release-cut` | stop at `commit_gate` | **PASS** failure | `commit_gate` | 1 |
| 25 | flow | release | `github/repo-release-cut` | success | **PASS** success |  | 9 |
| 26 | flow | release-rerun | `github/repo-release-cut` | success | **PASS** success |  | 8 |
| 27 | flow | deploy-unknown-version | `github/repo-deploy-promote` | stop at `release_gate` | **PASS** failure | `release_gate` | 2 |
| 28 | flow | deploy | `github/repo-deploy-promote` | success | **PASS** success |  | 14 |
| 29 | flow | deploy-rerun | `github/repo-deploy-promote` | success | **PASS** success |  | 12 |
| 30 | flow | standards-drift | `github/repo-standards-drift` | success | **PASS** success (drift 0) |  | 16 |
| 31 | flow | freeze | `github/repo-change-freeze` | success | **PASS** success |  | 12 |
| 32 | flow | freeze-rerun | `github/repo-change-freeze` | success | **PASS** success |  | 11 |
| 33 | flow | lift | `github/repo-change-freeze-lift` | success | **PASS** success |  | 10 |
| 34 | flow | lift-rerun | `github/repo-change-freeze-lift` | success | **PASS** success |  | 5 |
| 35 | read | user-get | `github/github-user-get` | success | **PASS** success |  | 2 |
| 36 | read | organizations-list | `github/github-organizations-list` | success | **PASS** success |  | 1 |
| 37 | read | repositories-list | `github/github-repositories-list` | success | **PASS** success |  | 2 |
| 38 | read | notifications-list | `github/github-notifications-list` | success | **PASS** success |  | 1 |
| 39 | read | repositories-list-for-org | `github/github-repositories-list-for-org` | success | **PASS** success |  | 2 |
| 40 | read | issues-list-for-org | `github/github-issues-list-for-org` | success | **PASS** success |  | 1 |
| 41 | read | teams-list | `github/github-teams-list` | success | **PASS** success |  | 1 |
| 42 | read | org-health-check | `github/github-org-health-check` | success | **PASS** success |  | 5 |
| 43 | read | org-standards-drift | `github/org-standards-drift` | success | **PASS** success (drift 5) |  | 9 |
| 44 | read | access-review | `github/github-access-review` | success | **PASS** success |  | 9 |
| 45 | read | daily-digest | `github/github-daily-digest` | success | **PASS** success |  | 4 |
| 46 | read | repo-view | `github/github-repo-view` | success | **PASS** success |  | 2 |
| 47 | read | repository-query | `github/github-repository-query` | success | **PASS** success |  | 2 |
| 48 | read | graphql-contributors | `github/github-graphql-contributors-query` | success | **PASS** success |  | 1 |
| 49 | read | repo-health | `github/github-repo-health` | success | **PASS** success |  | 4 |
| 50 | read | repo-settings-get | `github/github-repo-settings-get` | success | **PASS** success |  | 4 |
| 51 | read | repo-settings-snapshot | `github/repo-settings-snapshot` | success | **PASS** success |  | 9 |
| 52 | read | repo-standards-audit | `github/github-repo-standards-audit` | success | **PASS** success |  | 4 |
| 53 | read | repo-standards-drift-read | `github/repo-standards-drift` | success | **PASS** success (drift 0) |  | 20 |
| 54 | read | repo-root-files | `github/github-repo-root-files` | success | **PASS** success |  | 3 |
| 55 | read | repo-codeowners-errors | `github/github-repo-codeowners-errors` | success | **PASS** success |  | 1 |
| 56 | read | repo-community-profile | `github/github-repo-community-profile` | success | **PASS** success |  | 1 |
| 57 | read | repo-contributors-languages | `github/github-repo-contributors-and-languages` | success | **PASS** success |  | 3 |
| 58 | read | repo-collaborators | `github/github-repo-collaborators-list` | success | **PASS** success |  | 3 |
| 59 | read | repo-labels-list | `github/github-repo-labels-list` | success | **PASS** success |  | 1 |
| 60 | read | repo-tags | `github/github-repo-tags` | success | **PASS** success |  | 2 |
| 61 | read | repo-topics | `github/repo-topics-review` | success | **PASS** success |  | 1 |
| 62 | read | repo-forks | `github/repo-forks-review` | success | **PASS** success |  | 1 |
| 63 | read | repo-milestones | `github/repo-open-milestones` | success | **PASS** success |  | 2 |
| 64 | read | branches-and-protection | `github/github-repo-branches-and-protection` | stop at `step 2` | **PASS** failure | `step 2` | 2 |
| 65 | read | branch-protection-audit | `github/github-branch-protection-audit` | stop at `step 1` | **PASS** failure | `step 1` | 1 |
| 66 | read | rulesets-export | `github/github-repo-rulesets-export` | success | **PASS** success |  | 3 |
| 67 | read | security-posture | `github/github-security-posture` | success | **PASS** success |  | 4 |
| 68 | read | secrets-inventory | `github/github-secrets-inventory` | success | **PASS** success |  | 3 |
| 69 | read | actions-permissions | `github/github-actions-permissions` | success | **PASS** success |  | 3 |
| 70 | read | actions-workflows | `github/github-actions-workflows-inventory` | success | **PASS** success |  | 1 |
| 71 | read | actions-runners-cache | `github/github-actions-runners-and-cache` | success | **PASS** success |  | 3 |
| 72 | read | actions-failed-runs | `github/github-actions-failed-runs` | success | **PASS** success |  | 1 |
| 73 | read | actions-run-inspect | `github/github-actions-run-inspect` | success | **PASS** success |  | 4 |
| 74 | read | ci-failure-triage | `github/github-ci-failure-triage` | success | **PASS** success |  | 5 |
| 75 | read | deployments-environments | `github/github-deployments-and-environments` | success | **PASS** success |  | 2 |
| 76 | read | incident-what-changed | `github/github-incident-what-changed` | success | **PASS** success |  | 6 |
| 77 | read | release-latest-history | `github/github-release-latest-and-history` | success | **PASS** success |  | 2 |
| 78 | read | release-notes-preview | `github/github-release-notes-preview` | success | **PASS** success |  | 2 |
| 79 | read | release-readiness | `github/github-release-readiness` | success | **PASS** success |  | 5 |
| 80 | legacy | freeze-refused-layout | `github/repo-change-freeze` | stop at `layout_gate` | **PASS** failure | `layout_gate` | 1 |
| 81 | legacy | standards-pr | `github/repo-governance-standards-pr` | success | **PASS** success |  | 29 |
| 82 | legacy | standards-pr-rerun | `github/repo-governance-standards-pr` | success | **PASS** success |  | 17 |
| 83 | legacy | standards-drift-legacy | `github/repo-standards-drift` | success | **PASS** success (drift 12) |  | 28 |
| 84 | legacy | scaffold-and-ship | `platform/java-service-scaffold-and-ship` | success | **PASS** success |  | 17 |
| 85 | legacy | ruleset-default | `github/repo-ruleset-default` | success | **PASS** success |  | 2 |
| 86 | legacy | ruleset-reconcile | `github/repo-ruleset-default-reconcile` | success | **PASS** success |  | 21 |
| 87 | legacy | decommission-refused-open-pr | `github/repo-decommission` | stop at `open_work_gate` | **PASS** failure | `open_work_gate` | 2 |
| 88 | legacy | decommission | `github/repo-decommission` | success | **PASS** success |  | 11 |
| 89 | legacy | decommission-rerun | `github/repo-decommission` | success | **PASS** success |  | 9 |
| 90 | local | notes-roundtrip | `files/notes-roundtrip` | success | **PASS** success |  | 1 |
| 91 | local | delivery-readiness | `platform/repository-delivery-readiness` | success | **PASS** success |  | 5 |
