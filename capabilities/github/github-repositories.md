# Review an organization's repositories and open pull requests

Lists every repository in a GitHub organization, then its open pull
requests. Requires `RUNTIME_GITHUB_TOKEN` to be exported and `gh` to be
installed — `gh auth login` is *not* needed, since the Command Engine
forwards the token the Auth Engine already validated.

Note what this capability does **not** say: how GitHub is reached. The
first step happens to go out over the REST API and the second happens to
shell out to `gh`, but that is the GitHub Provider's decision, not this
file's. If a future runtime version serves `repo list` over GraphQL
instead, this capability keeps working unchanged.

Run with:

```
runtime capability validate capabilities/github/github-repositories.md
runtime capability execute capabilities/github/github-repositories.md --input organization=octocat
```

```runtime
version: v1

inputs:
  organization:
    description: GitHub organization to inspect
    required: true

workflow:
  - provider: github
    args: [repo, list, "${organization}"]

  - provider: github
    args: [pr, list]
```
