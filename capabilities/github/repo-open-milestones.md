# github/repo-open-milestones

Report a repository's open milestones, so a planning review can see what work is
still committed to a date.

A milestone is the one place a repository states intent with a deadline attached.
They rot quietly: the date passes, the issues stay open, and nobody notices until
someone asks why a release slipped. Reading them back is how that question gets
answered before it is asked.

**Inputs**

| Name | Required | Description |
|---|---|---|
| `repository` | yes | Repository in `owner/name` form |

**Run it**

```bash
runtime capability execute github/repo-open-milestones --input repository=cli/cli
```

Returns each open milestone with its title, due date, and the count of open and
closed issues against it — enough to tell a live milestone from an abandoned one
without opening the browser.

**Reading the result honestly.** An empty `[]` is a successful call, not a broken
capability: it means the repository has no open milestones. Verified on
`cli/cli`, which returns exactly that. Run it against a repository that uses them
before concluding anything about the output shape — `kubernetes/kubernetes`
returns ten, and the `open_issues` versus `closed_issues` counts are what make a
stale milestone obvious.

```runtime
version: v1

inputs:
  repository:
    description: Repository in owner/name form
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/milestones?state=open"]
```
