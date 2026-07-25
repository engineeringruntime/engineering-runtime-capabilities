# Daily GitHub digest

A personal catch-up workflow: unread notifications, issues assigned to
you across the active context's organization, and open pull requests
via the GitHub CLI. No inputs. Requires `RUNTIME_GITHUB_TOKEN` to be
exported and `gh` to be installed and authenticated.

Run with:

```
runtime capability validate github/github-daily-digest.md
runtime capability execute github/github-daily-digest.md
```

```runtime
version: v1

workflow:
  - provider: github
    args: [notification, list]

  - provider: github
    args: [issue, list]

  - binary: gh
    args: [pr, list]
```
