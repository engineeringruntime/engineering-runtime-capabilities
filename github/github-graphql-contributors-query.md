# A custom GraphQL query the `graphql` escape hatch covers, that no curated operation does

`repo summary` (see `github-repo-health.md`) is the **curated** GraphQL
operation — a fixed, published query the provider maintains. This
capability is the escape hatch next to it: `provider: github args:
[graphql, "<query>", key=value ...]` for a query no curated operation
publishes yet — here, a repository's top contributors by commit count,
which none of the curated operations expose.

Same relationship as `binary: gh` is to `provider: github args: [pr, ...]`
in `capabilities/github/README.md`'s "Known overlap" section: prefer a
curated operation when one exists; reach for the escape hatch only when
none does, and treat repeated reach-for-the-escape-hatch as a signal worth
turning into a real operation (see
`specs/github/capability-spec-github.md`'s "Choosing between an operation
and a raw binary" — the same rule, just for GraphQL instead of the
Command Engine).

Requires `RUNTIME_GITHUB_TOKEN`. No `gh` needed — `graphql`, like `repo
summary`, is REST/GraphQL-transport only.

Run with:

```
runtime capability validate capabilities/github/github-graphql-contributors-query.md
runtime capability execute capabilities/github/github-graphql-contributors-query.md \
  --input owner=cli --input name=cli
```

```runtime
version: v1

inputs:
  owner:
    description: Repository owner
    required: true
  name:
    description: Repository name
    required: true

workflow:
  - provider: github
    args: [graphql, "query($owner:String!,$name:String!){ repository(owner:$owner,name:$name){ mentionableUsers(first:10){ totalCount nodes { login } } } }", "owner=${owner}", "name=${name}"]
```

If a query like this earns repeat use, that's the signal to promote it
into a real curated operation the way `repo summary` was — publish it in
`providers/github/github.go`'s operations table with its own name (e.g.
`repo contributors`), document it in
`specs/github/capability-spec-github.md`, and this file can then be
rewritten to call that operation instead of hand-rolling the query inline,
the same way a `binary: gh` step gets rewritten to a `provider: github`
step once the operation exists.
