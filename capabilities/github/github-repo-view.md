# View a single repository's REST metadata

The plainest possible demonstration of `repo view` — one `GET
/repos/{owner}/{repo}` call, one step, no combination with anything else.
Worth having as its own capability specifically to contrast with
`repo summary`: `repo view` is the one-round-trip REST call for the raw
repository object (visibility, default branch, fork/star counts as REST
reports them, `pushed_at`, etc.); `repo summary` is the *curated* GraphQL
call that additionally bundles open issue/PR counts and the latest release
in that same round trip. Reach for `repo view` when you only need the
repository object itself and don't want the extra GraphQL round trip's
shape to deal with.

Requires `RUNTIME_GITHUB_TOKEN` (`runtime auth status`). No `gh` needed —
`repo view` is REST-only.

Run with:

```
runtime capability validate capabilities/github/github-repo-view.md
runtime capability execute capabilities/github/github-repo-view.md \
  --input repository=cli/cli
```

```runtime
version: v1

inputs:
  repository:
    description: Repository to view, as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [repo, view, "${repository}"]
```

If what you actually need is the raw REST object *plus* open issue/PR
counts and the latest release without a second call, use `repo summary`
(see `github-repo-health.md`) instead — that's exactly the four-round-trips-
into-one tradeoff GraphQL exists for here.
