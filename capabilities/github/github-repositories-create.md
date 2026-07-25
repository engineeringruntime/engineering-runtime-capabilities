# Create a repository under the authenticated user's account

Single-step capability wrapping the fixed `POST /user/repos` Runtime
Command. Every declared input becomes a `key=value` arg, which the
REST Engine coerces into a JSON body field (`true`/`false`/numbers
are coerced automatically). Requires `RUNTIME_GITHUB_TOKEN` to be
exported.

Run with:

```
runtime capability validate github/github-repositories-create.md
runtime capability execute github/github-repositories-create.md \
  --input name=my-new-repo --input private=true \
  --input description="created via runtime"
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

workflow:
  - provider: github
    args: [repo, create, "name=${name}", "private=${private}", "description=${description}"]
```
