# Set a repository's description

The one field every repository listing shows and most repositories leave empty.
Worth enforcing as a standard, because a repo with no description is one an
engineer has to open to identify.

Deliberately one field. An earlier draft set description *and* homepage
together, which meant you could not change one without restating the other, and
an empty homepage was rejected rather than left alone. Setting a single scalar
is the honest unit; homepage deserves its own capability if it is ever wanted.

Idempotent — setting the description to the value it already has changes nothing
and still returns the current state.

Requires `RUNTIME_GITHUB_TOKEN` with admin access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-repo-description-set.md
runtime capability execute github/github-repo-description-set \
  --input repository=acme/payments-api \
  --input description="Payments API — settlement and refunds"
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true
  description:
    description: One-line repository description
    required: true

workflow:
  - provider: github
    args: [api, PATCH, "/repos/${repository}", "description=${description}"]
```
