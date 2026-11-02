# The latest release, and the ones before it

Read the release GitHub considers latest, then the release history behind it.
Two calls because they answer different questions: "what should someone install
right now?" and "how often do we actually ship?"

`/releases/latest` excludes drafts and prereleases; the list includes them. A
repository whose newest tag is a prerelease will show a *different* release in
step 1 than at the top of step 2, and that gap is usually the bug — the install
docs point at latest, and latest is not what the team just shipped.

A repository with no published release returns `404` on step 1 and the run ends
there. That is the answer for a repository that has never released.

Requires `ENGRT_GITHUB_TOKEN` with read access to the repository.

**When this reports failure.** `GET /releases/latest` returns 404 for a repository with no published release. Runtime reports that as a failed step, because generic `api GET` steps have no "absent" observation (only curated reads such as `release get <owner>/<repo> <tag>` do, and that needs a known tag). Observed on a repository with no releases.

Run with:

```
engrt capability validate capabilities/github/github-release-latest-and-history.md
engrt capability execute github/github-release-latest-and-history --input repository=cli/cli
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/releases/latest"]

  - provider: github
    args: [api, GET, "/repos/${repository}/releases", "per_page=20"]
```
