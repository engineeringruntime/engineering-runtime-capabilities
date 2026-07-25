# Bootstrap a new repository and confirm it exists

Creates a repository under the authenticated user's account via the
REST API, then re-lists the user's repositories via the GitHub CLI as a
confirmation step. Requires `RUNTIME_GITHUB_TOKEN` to be exported and
`gh` to be installed and authenticated.

Run with:

```
runtime capability validate github/github-repo-bootstrap.md
runtime capability execute github/github-repo-bootstrap.md \
  --input name=my-new-repo --input private=true \
  --input description="created via runtime" --input limit=5
```

```runtime
version: v1

inputs:
  name:
    description: Name of the repository to create
    required: true
  private:
    description: "true or false — whether the repository is private"
    required: true
  description:
    description: Short description of the repository
    required: true
  limit:
    description: Number of recent repositories to confirm against
    required: true

workflow:
  - provider: github
    args: [repo, create, "name=${name}", "private=${private}", "description=${description}"]

  - binary: gh
    args: [repo, list, --limit, "${limit}"]
```
