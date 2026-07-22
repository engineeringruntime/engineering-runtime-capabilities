# List an organization's repositories and open pull requests

Lists every repository in a GitHub organization via the REST API, then
lists open pull requests via the GitHub CLI. Requires `RUNTIME_GITHUB_TOKEN`
to be exported and `gh` to be installed and authenticated.

Run with:

```
runtime capability validate examples/capabilities/github-repositories.md
runtime capability execute examples/capabilities/github-repositories.md --input organization=octocat
```

```runtime
version: v1

inputs:
  organization:
    description: GitHub organization to inspect
    required: true

workflow:
  - command: github.request
    args: [GET, "/orgs/${organization}/repos"]

  - command: command.run
    binary: gh
    args: [pr, list]
```
