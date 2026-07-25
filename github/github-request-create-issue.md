# Create an issue on a specific repository

Uses the generic `github.request` pass-through to file an issue via
`POST /repos/{owner}/{repo}/issues`. `POST`/`PUT`/`PATCH` requests turn
every `key=value` arg into a JSON request body field. Requires
`RUNTIME_GITHUB_TOKEN` to be exported.

Run with:

```
runtime capability validate github/github-request-create-issue.md
runtime capability execute github/github-request-create-issue.md \
  --input owner=octocat --input repo=hello-world \
  --input title="Bug" --input body="found via runtime"
```

```runtime
version: v1

inputs:
  owner:
    description: Repository owner (user or organization)
    required: true
  repo:
    description: Repository name
    required: true
  title:
    description: Issue title
    required: true
  body:
    description: Issue body
    required: true

workflow:
  - provider: github
    args: [api, POST, "/repos/${owner}/${repo}/issues", "title=${title}", "body=${body}"]
```
