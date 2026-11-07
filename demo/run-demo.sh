#!/usr/bin/env bash
# Run every capability in this catalogue against disposable demo repositories.
#
# Usage:
#   bash demo/run-demo.sh <organization> [phase]
#
# Phases (default: all, in this order):
#   check   engrt, jq, config, policy and GitHub authority
#   setup   onboard the demo service repository and create the legacy repository
#   flow    the service lifecycle on the demo repository: security, labels, team,
#           environments, a pull request merged when ready, release, deployment,
#           change freeze and lift (with refusal cases)
#   read    every read-only capability against the demo repository
#   legacy  standards pull request, scaffold-and-ship, default ruleset and
#           decommission on the legacy repository (with refusal cases)
#   local   File Engine and local-checkout capabilities
#
# MUTATING. `setup`, `flow` and `legacy` create two repositories and a team in
# <organization>, push commits, open and merge a pull request, publish a
# release, run GitHub Actions workflows and archive the legacy repository.
# Use an organization where that is acceptable. Nothing is ever deleted:
# the example policy denies `api DELETE`.
#
# Everything goes through engrt with examples/config.yaml and
# examples/policy.yaml, so a pass here is a pass for those documents.
#
# Settings (environment):
#   DEMO_REPO          demo service repository   (default engrt-capabilities-demo)
#   DEMO_LEGACY_REPO   legacy repository         (default <DEMO_REPO>-legacy)
#   DEMO_TEAM          reviewer team slug        (default <DEMO_REPO>-reviewers)
#   DEMO_PRIVATE       true to create private repositories (default false;
#                      several features need a public repository on the
#                      GitHub Free and Team plans)
#   DEMO_RESULTS       results directory         (default demo/results/<org>-<repo>)
#   DEMO_CONFIG        config to test instead of examples/config.yaml
#   DEMO_POLICY        policy to test instead of examples/policy.yaml
#   ENGRT              engrt binary              (default: engrt on PATH)
#
# Run it from a directory you are happy for engrt to read and write: the
# local phases create ./engrt-demo-work under it, inside the example policy's
# "." file root.
set -u

ORG=${1:-}
PHASE=${2:-all}
if [ -z "$ORG" ]; then
  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENGRT=${ENGRT:-engrt}
REPO=${DEMO_REPO:-engrt-capabilities-demo}
LEGACY=${DEMO_LEGACY_REPO:-$REPO-legacy}
TEAM=${DEMO_TEAM:-$REPO-reviewers}
PRIVATE=${DEMO_PRIVATE:-false}
RES=${DEMO_RESULTS:-$ROOT/demo/results/$ORG-$REPO}
WORK=$PWD/engrt-demo-work
FEATURE_BRANCH=demo/add-deploy-workflow
STANDARDS_BRANCH=chore/engineering-standards

# The examples are always used unless DEMO_CONFIG / DEMO_POLICY name others,
# so a config already exported in your shell does not change what is tested.
export ENGRT_CONFIG_FILE=${DEMO_CONFIG:-$ROOT/examples/config.yaml}
export ENGRT_POLICY_FILE=${DEMO_POLICY:-$ROOT/examples/policy.yaml}
export ENGRT_CAPABILITIES_DIR=$ROOT/capabilities

mkdir -p "$RES"
SUMMARY=$RES/summary.tsv
[ -f "$SUMMARY" ] || printf 'n\tverdict\tphase\tcase\tcapability\texpected\tstatus\tstopped_at\tcompleted\tnot_required\tfailed\tnot_executed\tseconds\tnote\n' > "$SUMMARY"
N=$(($(wc -l < "$SUMMARY") - 1))

log() { printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }
die() { log "STOP: $*"; exit 1; }

# ---- engrt helpers --------------------------------------------------------

# api METHOD PATH [key=value ...] -> response body on stdout; non-zero on failure
api() {
  local out
  out=$("$ENGRT" --output json github api "$@" 2>/dev/null) || true
  if [ "$(printf '%s' "$out" | jq -r '.status // "failure"' 2>/dev/null)" != success ]; then
    log "api $1 $2 failed: $(printf '%s' "$out" | jq -r '.message // .error // "no output"' 2>/dev/null | head -c 300)"
    return 1
  fi
  printf '%s' "$out" | jq -c '.data'
}

repo_exists() { api GET "/repos/$ORG/$1" >/dev/null 2>&1; }

# cap <expect> <case> <capability> [--input k=v ...]
#   expect: success | fail:<step id>
cap() {
  local expect=$1 case=$2 name=$3; shift 3
  N=$((N + 1))
  local out
  out=$RES/$(printf '%03d' "$N")-$case.json
  local t0 t1
  t0=$(date +%s)
  "$ENGRT" --output json capability execute "$name" "$@" > "$out" 2> "$out.stderr"
  t1=$(date +%s)
  local status stopped c nr f ne
  status=$(jq -r '.status // "unparsed"' "$out" 2>/dev/null || echo unparsed)
  stopped=$(jq -r '.failed_step as $f | if $f then ([.steps[] | select(.index == $f) | (.id // ("step " + ($f | tostring)))][0] // ("step " + ($f | tostring))) else "" end' "$out" 2>/dev/null)
  c=$(jq -r '.counts.completed // 0' "$out" 2>/dev/null)
  nr=$(jq -r '.counts.not_required // 0' "$out" 2>/dev/null)
  f=$(jq -r '.counts.failed // 0' "$out" 2>/dev/null)
  ne=$(jq -r '.counts.not_executed // 0' "$out" 2>/dev/null)
  local verdict=FAIL note=""
  case $expect in
    success) [ "$status" = success ] && verdict=PASS ;;
    fail:*) [ "$status" != success ] && [ "$stopped" = "${expect#fail:}" ] && verdict=PASS ;;
  esac
  case $name in
    *standards-drift) note="drift=$(jq -r '[.steps[] | select((.id // "") | startswith("drift_")) | select(.step_status == "success")] | length' "$out" 2>/dev/null)" ;;
  esac
  if [ "$verdict" = FAIL ]; then
    local msg
    msg=$(jq -r '.error // .message // ""' "$out" 2>/dev/null | tr '\t\n' '  ' | cut -c1-200)
    note="${note:+$note; }$msg"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$N" "$verdict" "$PHASE_NOW" "$case" "$name" "$expect" "$status" "$stopped" "$c" "$nr" "$f" "$ne" "$((t1 - t0))" "$note" >> "$SUMMARY"
  log "$verdict $case ($name) status=$status${stopped:+ stopped_at=$stopped} ${note}"
  [ "$verdict" = PASS ]
}

# A step that must succeed before later cases make sense.
must() { "$@" || die "$2 did not pass; later cases depend on it"; }

# The latest commit on a branch.
head_of() { api GET "/repos/$ORG/$1/commits/$2" | jq -r '.sha'; }

# Wait until <sha> has a completed `build` check from GitHub Actions.
wait_build() {
  local repo=$1 sha=$2 i=0 concl
  log "waiting for the build check on $repo@${sha:0:7}"
  while [ $i -lt 90 ]; do
    concl=$(api GET "/repos/$ORG/$repo/commits/$sha/check-runs" check_name=build \
      | jq -r '[.check_runs[] | select(.app.slug == "github-actions")][0] | if . == null then "none" elif .status != "completed" then "pending" else .conclusion end')
    case $concl in
      success) log "build passed"; return 0 ;;
      failure|cancelled|timed_out|action_required) log "build $concl"; return 1 ;;
    esac
    sleep 10; i=$((i + 1))
  done
  log "build check did not complete in 15 minutes"; return 1
}

# Wait until no workflow run in <repo> is queued or in progress.
wait_idle() {
  local repo=$1 i=0 busy
  while [ $i -lt 90 ]; do
    busy=0
    for s in queued in_progress waiting requested pending; do
      busy=$((busy + $(api GET "/repos/$ORG/$repo/actions/runs" status=$s per_page=1 | jq -r '.total_count')))
    done
    [ "$busy" -eq 0 ] && return 0
    sleep 10; i=$((i + 1))
  done
  log "workflow runs still active after 15 minutes"; return 1
}

# ---- phases -------------------------------------------------------------

phase_check() {
  command -v jq >/dev/null || die "jq is required"
  command -v "$ENGRT" >/dev/null || die "engrt not found"
  log "$("$ENGRT" version)"
  if [ -n "${ENGRT_GITHUB_TOKEN_FILE:-}" ] && [ -n "${ENGRT_GITHUB_TOKEN:-}" ]; then
    die "both ENGRT_GITHUB_TOKEN and ENGRT_GITHUB_TOKEN_FILE are set; Runtime refuses an ambiguous source. Unset one."
  fi
  "$ENGRT" --output json auth status 2>/dev/null | jq -e 'any(.[]; .provider == "github" and .status == "ok")' >/dev/null \
    || die "GitHub authority is not available (engrt auth status)"
  LOGIN=$(api GET /user | jq -r '.login')
  [ -n "$LOGIN" ] && [ "$LOGIN" != null ] || die "cannot read the authenticated user"
  log "authenticated as $LOGIN; organization $ORG; demo $REPO, legacy $LEGACY, team $TEAM"
}

phase_setup() {
  must cap success onboard github/java-springboot-service-onboard \
    --input organization="$ORG" --input repository="$REPO" \
    --input "description=Engineering Runtime capability catalogue demo service" \
    --input private="$PRIVATE" --input service_name=demo-service \
    --input java_package=com.example.demo --input java_package_path=com/example/demo \
    --input java_version=21 --input spring_boot_version=4.1.2 \
    --input code_owner="$LOGIN" --input required_approvals=0 \
    --input require_code_owner_review=false
  cap success onboard-rerun github/java-springboot-service-onboard \
    --input organization="$ORG" --input repository="$REPO" \
    --input "description=Engineering Runtime capability catalogue demo service" \
    --input private="$PRIVATE" --input service_name=demo-service \
    --input java_package=com.example.demo --input java_package_path=com/example/demo \
    --input java_version=21 --input spring_boot_version=4.1.2 \
    --input code_owner="$LOGIN" --input required_approvals=0 \
    --input require_code_owner_review=false

  if repo_exists "$LEGACY"; then
    log "legacy repository $ORG/$LEGACY exists"
  else
    api POST "/orgs/$ORG/repos" name="$LEGACY" \
      "description=Legacy repository for the Engineering Runtime catalogue demo" \
      auto_init:=true private:="$PRIVATE" >/dev/null || die "cannot create $ORG/$LEGACY"
    log "created $ORG/$LEGACY"
  fi
  wait_build "$REPO" "$(head_of "$REPO" main)" || die "the onboarded pipeline did not pass"
}

DEPLOY_YML='name: deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        required: true
        type: string

permissions:
  contents: read

concurrency:
  group: deploy-${{ inputs.environment }}
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - run: echo "deploy ${{ github.ref_name }} to ${{ inputs.environment }}"
'

phase_flow() {
  local A="$ORG/$REPO"
  cap success security-features github/repo-security-features-enable \
    --input organization="$ORG" --input repository="$REPO"
  # CodeQL default setup is free on public repositories. Without it GitHub
  # answers 404 on code-scanning alerts and github-security-posture stops.
  if [ "$PRIVATE" != true ]; then
    api PATCH "/repos/$A/code-scanning/default-setup" state=configured >/dev/null \
      && log "code scanning default setup requested"
  fi
  cap success labels github/repo-labels-standard-sync \
    --input organization="$ORG" --input repository="$REPO"
  cap success labels-rerun github/repo-labels-standard-sync \
    --input organization="$ORG" --input repository="$REPO"
  cap success team-access github/org-team-repo-access \
    --input organization="$ORG" --input team="$TEAM" \
    --input "description=Reviewers for the capability catalogue demo" \
    --input repository="$REPO" --input permission=WRITE
  cap success env-protect github/repo-environment-protect \
    --input organization="$ORG" --input repository="$REPO" \
    --input environment=production --input reviewer_team="$TEAM" --input wait_timer=1
  cap success env-protect-rerun github/repo-environment-protect \
    --input organization="$ORG" --input repository="$REPO" \
    --input environment=production --input reviewer_team="$TEAM" --input wait_timer=1
  cap success env-create github/repo-environment-create \
    --input organization="$ORG" --input repository="$REPO" --input environment=qa \
    --input 'deployment_branch_policy={"protected_branches":false,"custom_branch_policies":true}'
  cap success env-branch-policy github/repo-environment-branch-policy-add \
    --input organization="$ORG" --input repository="$REPO" --input environment=qa \
    --input pattern='release/*' --input type=branch
  # staging deploys release tags: repo-deploy-promote dispatches at the tag.
  cap success env-tag-policy github/repo-environment-branch-policy-add \
    --input organization="$ORG" --input repository="$REPO" --input environment=staging \
    --input 'pattern=v*' --input type=tag
  cap success env-variable github/repo-environment-variable-set \
    --input organization="$ORG" --input repository="$REPO" --input environment=qa \
    --input name=DEMO_REGION --input value=demo-region-1

  # A feature pull request that adds the deploy workflow. main is protected by
  # the onboarding ruleset, so changes arrive this way.
  local main_sha pr pr_sha
  main_sha=$(head_of "$REPO" main)
  if ! api GET "/repos/$A/branches/$FEATURE_BRANCH" >/dev/null 2>&1; then
    api POST "/repos/$A/git/refs" ref="refs/heads/$FEATURE_BRANCH" sha="$main_sha" >/dev/null \
      || die "cannot create $FEATURE_BRANCH"
    "$ENGRT" github file put "$A" .github/workflows/deploy.yml \
      "message=ci: add the deploy workflow" "content=$DEPLOY_YML" branch="$FEATURE_BRANCH" >/dev/null \
      || die "cannot commit deploy.yml"
  fi
  pr=$(api GET "/repos/$A/pulls" state=all head="$ORG:$FEATURE_BRANCH" | jq -r '.[0].number // empty')
  if [ -z "$pr" ]; then
    "$ENGRT" github pr create --repo "$A" --base main --head "$FEATURE_BRANCH" \
      --title "Add the deploy workflow" \
      --body "Adds a workflow_dispatch deploy workflow used by github/repo-deploy-promote." >/dev/null \
      || die "cannot open the pull request"
    pr=$(api GET "/repos/$A/pulls" state=all head="$ORG:$FEATURE_BRANCH" | jq -r '.[0].number')
  fi
  pr_sha=$(api GET "/repos/$A/pulls/$pr" | jq -r '.head.sha')
  log "pull request #$pr at ${pr_sha:0:7}"
  wait_build "$REPO" "$pr_sha" || die "the pull request build did not pass"

  # Pull-request reads while it is open.
  cap success pr-review-readiness github/github-pr-review-readiness --input repository="$A" --input number="$pr"
  cap success pr-review github/github-pr-review --input repository="$A" --input pull_request="$pr"
  cap success pr-status github/github-pr-status --input repository="$A" --input number="$pr" --input head_sha="$pr_sha"
  cap success pr-changed-files github/github-pr-changed-files --input repository="$A" --input number="$pr"
  cap success pr-commits github/github-pr-commits --input repository="$A" --input number="$pr"
  cap success pr-labels-assignees github/github-pr-labels-and-assignees --input repository="$A" --input number="$pr"
  cap success pr-reviews github/github-pr-reviews --input repository="$A" --input number="$pr"
  cap success review-queue github/github-review-queue --input repository="$A" --input stale_before="$(date -u +%Y-%m-%d)"

  cap fail:head_gate merge-wrong-sha github/repo-pr-merge-when-ready \
    --input organization="$ORG" --input repository="$REPO" --input pull_request="$pr" \
    --input head_sha=0000000000000000000000000000000000000000
  # GitHub computes mergeability in the background; give it a moment.
  sleep 5
  must cap success merge github/repo-pr-merge-when-ready \
    --input organization="$ORG" --input repository="$REPO" --input pull_request="$pr" --input head_sha="$pr_sha"
  cap success merge-rerun github/repo-pr-merge-when-ready \
    --input organization="$ORG" --input repository="$REPO" --input pull_request="$pr" --input head_sha="$pr_sha"

  local merge_sha
  merge_sha=$(api GET "/repos/$A/pulls/$pr" | jq -r '.merge_commit_sha')
  wait_build "$REPO" "$merge_sha" || die "the build of the merge commit did not pass"

  cap fail:commit_gate release-unknown-commit github/repo-release-cut \
    --input organization="$ORG" --input repository="$REPO" --input branch=main \
    --input commit=0000000000000000000000000000000000000000 --input version=v0.0.1
  must cap success release github/repo-release-cut \
    --input organization="$ORG" --input repository="$REPO" --input branch=main \
    --input commit="$merge_sha" --input version=v0.1.0
  cap success release-rerun github/repo-release-cut \
    --input organization="$ORG" --input repository="$REPO" --input branch=main \
    --input commit="$merge_sha" --input version=v0.1.0

  cap fail:release_gate deploy-unknown-version github/repo-deploy-promote \
    --input organization="$ORG" --input repository="$REPO" \
    --input version=v9.9.9 --input environment=staging --input workflow=deploy.yml
  must cap success deploy github/repo-deploy-promote \
    --input organization="$ORG" --input repository="$REPO" \
    --input version=v0.1.0 --input environment=staging --input workflow=deploy.yml
  sleep 10
  wait_idle "$REPO"
  cap success deploy-rerun github/repo-deploy-promote \
    --input organization="$ORG" --input repository="$REPO" \
    --input version=v0.1.0 --input environment=staging --input workflow=deploy.yml

  cap success standards-drift github/repo-standards-drift \
    --input organization="$ORG" --input repository="$REPO"

  cap success freeze github/repo-change-freeze \
    --input organization="$ORG" --input repository="$REPO" \
    --input "incident_title=Demo incident: payments latency" \
    --input "incident_summary=Freeze merges while the demo incident is investigated."
  cap success freeze-rerun github/repo-change-freeze \
    --input organization="$ORG" --input repository="$REPO" \
    --input "incident_title=Demo incident: payments latency" \
    --input "incident_summary=Freeze merges while the demo incident is investigated."
  cap success lift github/repo-change-freeze-lift \
    --input organization="$ORG" --input repository="$REPO" \
    --input "resolution=Resolved in the demo; merges reopened."
  cap success lift-rerun github/repo-change-freeze-lift \
    --input organization="$ORG" --input repository="$REPO" \
    --input "resolution=Resolved in the demo; merges reopened."
}

phase_read() {
  local A="$ORG/$REPO" run_id pr pr_sha ruleset_id since
  run_id=$(api GET "/repos/$A/actions/runs" per_page=1 | jq -r '.workflow_runs[0].id')
  pr=$(api GET "/repos/$A/pulls" state=all head="$ORG:$FEATURE_BRANCH" | jq -r '.[0].number')
  ruleset_id=$(api GET "/repos/$A/rulesets" | jq -r '.[0].id')
  since=$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)

  cap success user-get github/github-user-get
  cap success organizations-list github/github-organizations-list
  cap success repositories-list github/github-repositories-list
  cap success notifications-list github/github-notifications-list
  cap success repositories-list-for-org github/github-repositories-list-for-org --input organization="$ORG"
  cap success issues-list-for-org github/github-issues-list-for-org --input organization="$ORG"
  cap success teams-list github/github-teams-list --input organization="$ORG"
  cap success org-health-check github/github-org-health-check --input organization="$ORG"
  cap success org-standards-drift github/org-standards-drift --input organization="$ORG" --input standard_ruleset=engrt-org-standard
  cap success access-review github/github-access-review --input organization="$ORG" --input team_slug="$TEAM" --input repository="$A" --input username="$LOGIN"
  cap success daily-digest github/github-daily-digest --input organization="$ORG" --input repository="$A"

  cap success repo-view github/github-repo-view --input repository="$A"
  cap success repository-query github/github-repository-query --input owner="$ORG" --input repository="$REPO"
  cap success graphql-contributors github/github-graphql-contributors-query --input owner="$ORG" --input name="$REPO"
  cap success repo-health github/github-repo-health --input repository="$A"
  cap success repo-settings-get github/github-repo-settings-get --input repository="$A"
  cap success repo-settings-snapshot github/repo-settings-snapshot --input organization="$ORG" --input repository="$REPO"
  cap success repo-standards-audit github/github-repo-standards-audit --input repository="$A"
  cap success repo-standards-drift-read github/repo-standards-drift --input organization="$ORG" --input repository="$REPO"
  cap success repo-root-files github/github-repo-root-files --input repository="$A"
  cap success repo-codeowners-errors github/github-repo-codeowners-errors --input repository="$A"
  cap success repo-community-profile github/github-repo-community-profile --input repository="$A"
  cap success repo-contributors-languages github/github-repo-contributors-and-languages --input repository="$A"
  cap success repo-collaborators github/github-repo-collaborators-list --input repository="$A"
  cap success repo-labels-list github/github-repo-labels-list --input repository="$A"
  cap success repo-tags github/github-repo-tags --input repository="$A"
  cap success repo-topics github/repo-topics-review --input repository="$A"
  cap success repo-forks github/repo-forks-review --input repository="$A"
  cap success repo-milestones github/repo-open-milestones --input repository="$A"
  # The demo repository is protected by rulesets, not classic branch
  # protection, so GitHub answers 404 on .../branches/main/protection and both
  # capabilities stop there, as their files document. rulesets-export below
  # reads the protection actually in force.
  cap "fail:step 2" branches-and-protection github/github-repo-branches-and-protection --input repository="$A" --input branch=main
  cap "fail:step 1" branch-protection-audit github/github-branch-protection-audit --input repository="$A" --input branch=main
  cap success rulesets-export github/github-repo-rulesets-export --input repository="$A" --input ruleset_id="$ruleset_id"
  wait_idle "$REPO"   # the first CodeQL analysis must finish before code-scanning alerts exist
  cap success security-posture github/github-security-posture --input repository="$A"
  cap success secrets-inventory github/github-secrets-inventory --input repository="$A"
  cap success actions-permissions github/github-actions-permissions --input repository="$A"
  cap success actions-workflows github/github-actions-workflows-inventory --input repository="$A"
  cap success actions-runners-cache github/github-actions-runners-and-cache --input repository="$A"
  cap success actions-failed-runs github/github-actions-failed-runs --input repository="$A" --input branch=main
  cap success actions-run-inspect github/github-actions-run-inspect --input repository="$A" --input run_id="$run_id"
  cap success ci-failure-triage github/github-ci-failure-triage --input repository="$A" --input run_id="$run_id"
  cap success deployments-environments github/github-deployments-and-environments --input repository="$A"
  cap success incident-what-changed github/github-incident-what-changed --input repository="$A" --input since="$since" --input environment=staging
  cap success release-latest-history github/github-release-latest-and-history --input repository="$A"
  cap success release-notes-preview github/github-release-notes-preview --input repository="$A" --input tag_name=v0.2.0
  cap success release-readiness github/github-release-readiness --input repository="$A"
}

phase_legacy() {
  local B="$ORG/$LEGACY" pr ruleset_id
  # The freeze needs the onboarding rulesets; a plain repository is refused
  # before anything is written.
  cap fail:layout_gate freeze-refused-layout github/repo-change-freeze \
    --input organization="$ORG" --input repository="$LEGACY" \
    --input "incident_title=Demo incident" --input "incident_summary=Should be refused."

  cap success standards-pr github/repo-governance-standards-pr \
    --input organization="$ORG" --input repository="$LEGACY" --input branch="$STANDARDS_BRANCH" \
    --input code_owner="$LOGIN" --input dependabot_ecosystem=maven
  cap success standards-pr-rerun github/repo-governance-standards-pr \
    --input organization="$ORG" --input repository="$LEGACY" --input branch="$STANDARDS_BRANCH" \
    --input code_owner="$LOGIN" --input dependabot_ecosystem=maven
  cap success standards-drift-legacy github/repo-standards-drift \
    --input organization="$ORG" --input repository="$LEGACY"

  mkdir -p "$WORK"
  if [ -e "$WORK/scaffold" ]; then log "$WORK/scaffold exists; scaffold-and-ship needs a fresh directory"; fi
  cap success scaffold-and-ship platform/java-service-scaffold-and-ship \
    --input repository="$B" --input workdir="$WORK/scaffold" --input service_name=legacy-service \
    --input java_package=com.example.legacy --input java_package_path=com/example/legacy

  cap success ruleset-default github/repo-ruleset-default \
    --input organization="$ORG" --input repository="$LEGACY"
  ruleset_id=$(api GET "/repos/$B/rulesets" | jq -r '[.[] | select(.name == "engrt-ruleset-default")][0].id')
  cap success ruleset-reconcile github/repo-ruleset-default-reconcile \
    --input organization="$ORG" --input repository="$LEGACY" --input ruleset_id="$ruleset_id"

  wait_idle "$LEGACY"
  cap fail:open_work_gate decommission-refused-open-pr github/repo-decommission \
    --input organization="$ORG" --input repository="$LEGACY" \
    --input "reason=Retired after the capability catalogue demo"
  pr=$(api GET "/repos/$B/pulls" state=open head="$ORG:$STANDARDS_BRANCH" | jq -r '.[0].number // empty')
  if [ -n "$pr" ]; then
    api PATCH "/repos/$B/pulls/$pr" state=closed >/dev/null && log "closed #$pr on $B"
  fi
  cap success decommission github/repo-decommission \
    --input organization="$ORG" --input repository="$LEGACY" \
    --input "reason=Retired after the capability catalogue demo"
  cap success decommission-rerun github/repo-decommission \
    --input organization="$ORG" --input repository="$LEGACY" \
    --input "reason=Retired after the capability catalogue demo"
}

phase_local() {
  mkdir -p "$WORK"
  cap success notes-roundtrip files/notes-roundtrip \
    --input path="$WORK/notes.txt" --input "message=Engineering Runtime catalogue demo"
  if [ ! -d "$WORK/$REPO/.git" ]; then
    "$ENGRT" command run git clone "https://github.com/$ORG/$REPO.git" "$WORK/$REPO" >/dev/null \
      || log "clone of $ORG/$REPO failed"
  fi
  cap success delivery-readiness platform/repository-delivery-readiness \
    --input repository="$ORG/$REPO" --input workdir="$WORK/$REPO" --input delivery_document="$WORK/$REPO/README.md"
}

summary() {
  local pass fail
  pass=$(awk -F'\t' 'NR > 1 && $2 == "PASS"' "$SUMMARY" | wc -l | tr -d ' ')
  fail=$(awk -F'\t' 'NR > 1 && $2 == "FAIL"' "$SUMMARY" | wc -l | tr -d ' ')
  log "results: $pass PASS, $fail FAIL ($SUMMARY)"
  awk -F'\t' 'NR > 1 && $2 == "FAIL" { printf "  FAIL %s (%s) expected=%s status=%s stopped_at=%s %s\n", $4, $5, $6, $7, $8, $14 }' "$SUMMARY" >&2
  [ "$fail" -eq 0 ]
}

PHASE_NOW=check
phase_check
case $PHASE in
  check) ;;
  all)
    for p in setup flow read legacy local; do PHASE_NOW=$p; log "== $p"; "phase_$p"; done ;;
  setup|flow|read|legacy|local) PHASE_NOW=$PHASE; "phase_$PHASE" ;;
  *) die "unknown phase $PHASE" ;;
esac
summary
