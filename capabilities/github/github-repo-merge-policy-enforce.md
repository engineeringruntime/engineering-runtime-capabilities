# Enforce a repository's merge policy

Set the four switches that decide how pull requests land: squash, merge commit,
rebase, and whether the branch is deleted afterwards. The "every repo merges the
same way" control that teams otherwise apply by hand, repo by repo.

Each switch is a separate step so the audit record shows exactly which one
changed and in what order. All four are booleans — pass `true` or `false`.

**Idempotent.** Setting a switch to the value it already has is a no-op that
still returns the current state, so this is safe to run repeatedly and safe to
run first in a dry sense: read with `github-repo-settings-get` to see what a
repository has before you change it.

**No step-output chaining**: every step takes `repository` explicitly.

Requires `RUNTIME_GITHUB_TOKEN` with admin access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-repo-merge-policy-enforce.md
runtime capability execute github/github-repo-merge-policy-enforce \
  --input repository=acme/payments-api \
  --input allow_squash=true --input allow_merge_commit=false \
  --input allow_rebase=false --input delete_branch_on_merge=true
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  allow_squash:
    description: Allow squash merging (true/false)
    required: true
  allow_merge_commit:
    description: Allow merge commits (true/false)
    required: true
  allow_rebase:
    description: Allow rebase merging (true/false)
    required: true
  delete_branch_on_merge:
    description: Delete the head branch after merge (true/false)
    required: true

workflow:
  - provider: github
    args: [api, PATCH, "/repos/${repository}", "allow_squash_merge=${allow_squash}"]

  - provider: github
    args: [api, PATCH, "/repos/${repository}", "allow_merge_commit=${allow_merge_commit}"]

  - provider: github
    args: [api, PATCH, "/repos/${repository}", "allow_rebase_merge=${allow_rebase}"]

  - provider: github
    args: [api, PATCH, "/repos/${repository}", "delete_branch_on_merge=${delete_branch_on_merge}"]
```
