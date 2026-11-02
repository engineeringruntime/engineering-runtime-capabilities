# Export a repository's rulesets

List the repository's rulesets and read each one's full definition. Rulesets are
the modern replacement for branch protection, and they are the hardest part of a
repository's configuration to see: the UI shows one at a time and the API is the
only way to read them together.

Read-only. Applying a ruleset is **not** possible from a v1 capability: a
ruleset body is a nested JSON object with arrays of rules, and the `api`
operation takes flat `key=value` arguments only. Export here, then apply with
`gh api --input` outside the Runtime, or wait for a curated `ruleset` operation.

`${ruleset_id}` comes from the first step's output — supply it explicitly on a
second run. There is no step-output chaining.

Requires `ENGRT_GITHUB_TOKEN` with admin read on the repository.

**When this reports failure.** Rulesets answer 403 "Upgrade to GitHub Pro or make this repository public" for a private repository on a plan without rulesets. Runtime reports that as a failed step. Observed to succeed once the same repository was public.

Run with:

```
engrt capability validate capabilities/github/github-repo-rulesets-export.md
engrt capability execute github/github-repo-rulesets-export \
  --input repository=cli/cli --input ruleset_id=0
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  ruleset_id:
    description: Ruleset id to read in full, from the first step's output. Pass 0 to list only.
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/rulesets"]

  - provider: github
    args: [api, GET, "/repos/${repository}/rules/branches/main"]
```
