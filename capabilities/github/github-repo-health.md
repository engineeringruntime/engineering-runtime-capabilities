# Report a repository's health

Pulls a single repository's headline numbers, its open pull requests, and
its recent Actions runs.

This capability is worth reading as a demonstration of the Provider layer:
its three steps are served by three *different* transports —

| Step | Operation | Transport the provider chose | Why |
|---|---|---|---|
| 1 | `repo summary` | GraphQL | metadata, open issue count, open PR count and latest release in one round trip; REST would need four |
| 2 | `pr list` | gh CLI | `gh`'s PR surface is richer than the REST equivalent and supports `--json` field selection |
| 3 | `run list` | gh CLI | Actions run listing is a `gh` strength |

— and yet the capability names none of them. It asks for operations; the
GitHub Provider decides how to deliver each one. That is the entire point:
the transport can change in a future runtime version without touching this
file.

Requires `RUNTIME_GITHUB_TOKEN` and `gh` installed (no `gh auth login`).

Run with:

```
runtime capability validate capabilities/github/github-repo-health.md
runtime capability execute capabilities/github/github-repo-health.md --input repository=cli/cli
```

For machine-readable output covering every step:

```
runtime --output json capability execute capabilities/github/github-repo-health.md --input repository=cli/cli
```

```runtime
version: v1

inputs:
  repository:
    description: Repository to report on, as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [repo, summary, "${repository}"]

  - provider: github
    args: [pr, list, --repo, "${repository}", --json, "number,title,author"]

  - provider: github
    args: [run, list, --repo, "${repository}", --limit, "5"]
```
