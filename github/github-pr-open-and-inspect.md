# Open a pull request, then inspect it by number

Exercises `pr create` and `pr view` — the two `pr`-family operations
`github-repo-health.md` (`pr list`) and `github-cli-pr-list.md` (raw
`binary: gh` escape hatch) don't cover between them.

**This one has a real prerequisite the auth-free/read-only capabilities in
this folder don't**: `gh pr create` resolves the repository and the
current/head branch from the working directory it runs in, the same way
`github-cli-pr-list.md` does — it is not given a repository as an input.
Run this from inside a clone that already has a pushed feature branch
checked out and ahead of its base, or `pr create` fails exactly the way a
bare `gh pr create` would in the wrong directory. This is not a runtime
limitation; it's `gh`'s own resolution, which the GitHub Provider
deliberately does not paper over (see `specs/github/capability-spec-github.md`'s
"never depend on transport" rule — this is the flip side of that: when the
*operation itself* is inherently CLI-shaped, its CLI-shaped prerequisites
come along with it).

Requires `RUNTIME_GITHUB_TOKEN` and `gh` installed (no `gh auth login`).

Run with:

```
runtime capability validate capabilities/github/github-pr-open-and-inspect.md

# from inside a clone, on a pushed feature branch:
runtime capability execute capabilities/github/github-pr-open-and-inspect.md \
  --input title="Fix retry backoff" --input body="See #42" --input number=43
```

```runtime
version: v1

inputs:
  title:
    description: Pull request title
    required: true
  body:
    description: Pull request body
    required: true
  number:
    description: PR number to inspect afterward (there is no step-output chaining, so this is supplied explicitly rather than captured from the `pr create` result)
    required: true

workflow:
  - provider: github
    args: [pr, create, --title, "${title}", --body, "${body}"]

  - provider: github
    args: [pr, view, "${number}", --json, "number,title,state,url"]
```

`number` has to be supplied by whoever calls this — after `pr create`
succeeds, `gh` prints the new PR's URL/number to its own output (visible in
this run's audit record for that step), but nothing in the capability
grammar feeds one step's result into the next step's input. Read the first
step's audit entry (or its result, with `--output json`) to get the number
before re-running just the `pr view` step, or use this capability's two
steps as two independent operations rather than expecting the second to
follow the first automatically.
