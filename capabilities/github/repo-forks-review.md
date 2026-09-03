# github/repo-forks-review

List the repositories that have forked this one, so a maintainer can see who is
building on it.

Forks are the quietest signal a project has. Stars say someone approved; a fork
says someone started work. Maintainers rarely look, because the list lives behind
a tab nobody opens — and it is the first place a fork that has become a real
downstream shows up.

**Inputs**

| Name | Required | Description |
|---|---|---|
| `repository` | yes | Repository in `owner/name` form |

**Run it**

```bash
runtime capability execute github/repo-forks-review --input repository=cli/cli
```

Returns each fork with its owner, push date and open-issue count, newest first.
`pushed_at` is the field that matters: a fork nobody has pushed to since the day
it was created is a bookmark, not a downstream.

```runtime
version: v1

inputs:
  repository:
    description: Repository in owner/name form
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/forks?sort=newest&per_page=20"]
```
