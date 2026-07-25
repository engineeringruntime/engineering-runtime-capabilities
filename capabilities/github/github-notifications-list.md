# List the authenticated user's notifications

Single-step capability wrapping the fixed `GET /notifications` Runtime
Command. Useful as a quick "what's waiting for me" check. Requires
`RUNTIME_GITHUB_TOKEN` to be exported.

Run with:

```
runtime capability validate github/github-notifications-list.md
runtime capability execute github/github-notifications-list.md
```

```runtime
version: v1

workflow:
  - provider: github
    args: [notification, list]
```
