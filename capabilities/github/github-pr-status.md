# Pull request status — can this merge, and what is holding it

Read a pull request's state, draft flag, mergeability and merge-state, then the
combined commit status on its head. The four facts that answer "why is this not
merging?" without opening the PR.

`mergeable` is computed asynchronously by GitHub. On a PR it has not looked at
recently the first read returns `null`; run it again and the value is there.
That is GitHub's behaviour, not a fault in the capability.

**Do not add `/pulls/{n}/merge` as a second step.** That endpoint means "has
this been merged" and answers `404` for every open pull request, which aborts
the whole capability. An earlier draft did exactly that and failed against every
open PR it was pointed at. Step 1 already carries `mergeable`, `mergeable_state`
and `draft`, which is what the question needs.

The second step reads the check runs on the head commit. `${head_sha}` comes
from step 1's `head.sha` — there is no step-output chaining, so pass it
explicitly on a second run, or pass the branch tip you already know.

Complements `github-pr-open-and-inspect`, which creates and views; this one only
reads, and reads more.

Requires `RUNTIME_GITHUB_TOKEN` with read access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-pr-status.md
runtime capability execute github/github-pr-status \
  --input repository=cli/cli --input number=11000 --input head_sha=<head.sha from step 1>
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  number:
    description: Pull request number
    required: true
  head_sha:
    description: Head commit SHA, from step 1's head.sha
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/pulls/${number}"]

  - provider: github
    args: [api, GET, "/repos/${repository}/commits/${head_sha}/check-runs"]
```
