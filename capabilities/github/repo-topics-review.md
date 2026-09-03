# github/repo-topics-review

Report the topics a repository declares, so a review can check it is
discoverable by the labels your organisation standardises on.

Topics are how people find a repository when they do not already know its name.
They drift: a service is renamed, a team reorganises, and the labels stay as they
were on the day someone created it. Reading them back is the cheap half of
keeping them true.

**Inputs**

| Name | Required | Description |
|---|---|---|
| `repository` | yes | Repository in `owner/name` form |

**Run it**

```bash
runtime capability execute github/repo-topics-review --input repository=cli/cli
```

Returns the raw `names` array from the GitHub topics API, so the output is the
same shape whether the repository has nine topics or none.

```runtime
version: v1

inputs:
  repository:
    description: Repository in owner/name form
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/topics"]
```
