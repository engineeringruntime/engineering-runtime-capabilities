# Golden-path service onboarding

Stand up a new service repository that already meets org standards —
create it, tag it, set merge policy, protect the default branch, grant a
team write access, then check CODEOWNERS for errors. The "golden path"
every platform team ends up writing by hand.

There is no curated `file push` / `branch protect` / `team grant`
operation today, so the post-create steps use the `api` escape hatch
(see `github-file-push.md` for the same pattern). Prefer promoting
repeated escape-hatch paths into curated operations later.

**No step-output chaining**: `repository` must be supplied as
`<owner>/<repo>` for the configure steps even though step 1 creates the
repo — the create response prints the full name, but nothing feeds it
into later steps automatically.

Requires `RUNTIME_GITHUB_TOKEN` with `repo` (and org) scope sufficient to
create repos, set topics/protection, and update team permissions. Default
policy denies `api DELETE` — this workflow only uses POST/PUT/PATCH/GET.

Run with:

```
runtime capability validate capabilities/github/github-service-onboarding.md

runtime capability execute capabilities/github/github-service-onboarding.md \
  --input name=payments-api \
  --input private=true \
  --input description="Payments API" \
  --input repository=acme/payments-api \
  --input organization=acme \
  --input team_slug=platform \
  --input branch=main \
  --input topic=service
```

```runtime
version: v1

inputs:
  name:
    description: Repository name to create (under the authenticated user account)
    required: true
  private:
    description: "true or false — whether the repository is private"
    required: true
  description:
    description: Short description of the repository
    required: true
  repository:
    description: Full <owner>/<repo> used by every configure step after create
    required: true
  organization:
    description: Org that owns the team receiving write access
    required: true
  team_slug:
    description: Team slug granted push on the new repository
    required: true
  branch:
    description: Branch to protect (usually main)
    required: true
  topic:
    description: Single topic label to apply (e.g. service, go, tier1)
    required: true

workflow:
  - provider: github
    args: [repo, create, "name=${name}", "private=${private}", "description=${description}", "auto_init=true"]

  - provider: github
    args: [api, PUT, "/repos/${repository}/topics", "names[]=${topic}"]

  - provider: github
    args: [api, PATCH, "/repos/${repository}", "delete_branch_on_merge=true", "allow_squash_merge=true", "allow_merge_commit=false"]

  - provider: github
    args: [api, PUT, "/repos/${repository}/branches/${branch}/protection", "required_pull_request_reviews[required_approving_review_count]=1", "enforce_admins=true", "restrictions=null", "required_status_checks=null"]

  - provider: github
    args: [api, PUT, "/orgs/${organization}/teams/${team_slug}/repos/${repository}", "permission=push"]

  - provider: github
    args: [api, GET, "/repos/${repository}/codeowners/errors"]
```
