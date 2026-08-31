# Repository standards audit

Compliance snapshot for one repository: headline health (`repo summary`),
community profile (README / LICENSE / CoC completeness), topics, and
languages. Answers "does this repo meet standard?" before an audit or
reorg.

`repo summary` is the curated GraphQL op; the other three steps use the
`api` escape hatch against endpoints no curated operation covers yet.

Requires `RUNTIME_GITHUB_TOKEN` only — no `gh` needed.

Run with:

```
runtime capability validate capabilities/github/github-repo-standards-audit.md

runtime capability execute capabilities/github/github-repo-standards-audit.md \
  --input repository=cli/cli
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [repo, summary, "${repository}"]

  - provider: github
    args: [api, GET, "/repos/${repository}/community/profile"]

  - provider: github
    args: [api, GET, "/repos/${repository}/topics"]

  - provider: github
    args: [api, GET, "/repos/${repository}/languages"]
```
