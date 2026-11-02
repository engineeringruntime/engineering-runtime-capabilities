# List the authenticated user's notifications

Single-step capability wrapping the fixed `GET /notifications` Runtime
Command. Useful as a quick "what's waiting for me" check. Requires
`ENGRT_GITHUB_TOKEN` to be exported.

Run with:

```
engrt capability validate github/github-notifications-list.md
engrt capability execute github/github-notifications-list.md
```

```runtime
version: v1

workflow:
  - provider: github
    args: [notification, list]
```
