# Review queue — what needs my eyes, and what is going stale

Daily review hygiene for one repository: pull requests waiting on me,
then open non-draft PRs older than a cut-off date (stale queue). Both
steps use the curated `pr list` operation with `gh`'s `--search` /
`--json` surface — no transport named in the capability.

Supply `stale_before` as an ISO date (`YYYY-MM-DD`); the search uses
GitHub's `created:<date>` qualifier.

Requires `RUNTIME_GITHUB_TOKEN` and `gh` installed (no `gh auth login`).

Run with:

```
runtime capability validate capabilities/github/github-review-queue.md

runtime capability execute capabilities/github/github-review-queue.md \
  --input repository=cli/cli \
  --input stale_before=2026-07-01
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  stale_before:
    description: ISO date (YYYY-MM-DD) — open non-draft PRs created before this are "stale"
    required: true

workflow:
  - provider: github
    args: [pr, list, --repo, "${repository}", --search, "is:open review-requested:@me", --json, "number,title,author,createdAt,url"]

  - provider: github
    args: [pr, list, --repo, "${repository}", --search, "is:open draft:false created:<${stale_before}", --json, "number,title,author,createdAt,reviewDecision"]
```
