# List the authenticated user's repositories

Single-step capability wrapping the fixed `GET /user/repos` Runtime
Command. Lists every repository the authenticated user can see —
personal and org-owned. Requires `ENGRT_GITHUB_TOKEN` to be exported.

Run with:

```
engrt capability validate github/github-repositories-list.md
engrt capability execute github/github-repositories-list.md
```

```runtime
version: v1

workflow:
  - provider: github
    args: [repo, list]
```
