# Who writes this repository, and in what

Contributors ranked by commit count, and the language breakdown by bytes. The
two numbers that describe a codebase before you open it.

Useful in an ownership review: a service with one contributor and no CODEOWNERS
has a bus factor of one, and the two capabilities that show it —
`github-repo-codeowners-errors` and this one — are worth running together.

Language bytes are GitHub's own linguist analysis, so vendored directories and
generated files can dominate the result. Treat it as a shape, not a measurement.

Requires `RUNTIME_GITHUB_TOKEN` with read access to the repository.

Run with:

```
runtime capability validate capabilities/github/github-repo-contributors-and-languages.md
runtime capability execute github/github-repo-contributors-and-languages --input repository=cli/cli
```

```runtime
version: v1

inputs:
  repository:
    description: Repository as <owner>/<repo>
    required: true

workflow:
  - provider: github
    args: [api, GET, "/repos/${repository}/contributors", "per_page=30"]

  - provider: github
    args: [api, GET, "/repos/${repository}/languages"]
```
