# Create the default branch ruleset `engrt-ruleset-default`

> **Mutating.** Creates one branch ruleset on the repository, enforcement
> `active`. Run `plan` first. Execute only on an explicit request for that
> repository.

Creates a ruleset named `engrt-ruleset-default` on the repository's default
branch, then reads it back:

- `deletion`: the default branch cannot be deleted;
- `non_fast_forward`: no force pushes;
- `pull_request`: changes arrive through a pull request, with **0** required
  approvals, so a sole owner can still merge;
- no bypass actors.

It adds a ruleset beside any existing one. GitHub stacks rulesets and the
stricter rule wins, so nothing existing is replaced or loosened.

## Before you run it

The capability cannot branch, and GitHub rejects a second ruleset with the same
name. Check the repository first. The step is read-only:

```bash
engrt github api GET /repos/<organization>/<repository>/rulesets
```

Skip the repository if `engrt-ruleset-default` is already listed.

## Run it

```bash
engrt capability plan github/repo-ruleset-default \
  --input organization=<organization> --input repository=<repo>
```

Execute with the same inputs after review.

## How the body is sent

The ruleset body holds an object and arrays. From engrt 0.13.0, `key:=<json>`
carries typed JSON values in an `api` request body.

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
  - id: create
    provider: github
    args:
      - api
      - POST
      - "/repos/${organization}/${repository}/rulesets"
      - "name=engrt-ruleset-default"
      - "target=branch"
      - "enforcement=active"
      - 'bypass_actors:=[]'
      - 'conditions:={"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}}'
      - 'rules:=[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}}]'

  - id: verify
    needs: [create]
    provider: github
    args: [api, GET, "/repos/${organization}/${repository}/rulesets"]
```
