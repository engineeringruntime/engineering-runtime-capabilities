# File an issue via the provider operation, then list it back

Uses the **curated `issue create` operation** (`provider: github`), not the
raw `binary: gh` escape hatch — the direct contrast to
`github-cli-issue-create.md`, which pins the `gh` CLI transport
deliberately as an escape-hatch demonstration. This file is the "prefer the
operation" side of that same job: `issue create` and `issue list` are both
`provider: github` steps, so the GitHub Provider — not this file — decides
that both currently go through `gh` under the hood; that can change in a
later runtime version without this capability needing an edit.

The organization is an explicit input. GitHub has no native context for
Runtime to read, so nothing supplies it on your behalf — see
`specs/github/capability-spec-github.md`.

Requires `RUNTIME_GITHUB_TOKEN` and `gh` installed (no `gh auth login` —
the Command Engine forwards the validated token as `GH_TOKEN`).

Run with:

```
runtime capability validate capabilities/github/github-issue-create-and-list.md
runtime capability execute capabilities/github/github-issue-create-and-list.md \
  --input organization=acme \
  --input title="Bug: retry loop never backs off" --input body="Filed via runtime capability execute."
```

```runtime
version: v1

inputs:
  organization:
    description: GitHub organization to list issues from after filing
    required: true
  title:
    description: Issue title
    required: true
  body:
    description: Issue body
    required: true

workflow:
  - provider: github
    args: [issue, create, --title, "${title}", --body, "${body}"]

  - provider: github
    args: [issue, list, "${organization}", per_page=5]
```

The final `issue list` doesn't filter down to only the issue just created —
`gh issue list` has no "issue I just created" flag, and there's no step
output to feed a number into a filter anyway (workflow steps only
substitute declared `${input}` values, never a previous step's result).
It's there so the new issue's presence is visible in the same run, in the
same audit trail, rather than requiring a second manual check.
