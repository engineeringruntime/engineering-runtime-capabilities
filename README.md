# Engineering Runtime Capabilities

Reusable engineering workflows for [Engineering Runtime](https://github.com/engineeringruntime/engineering-runtime-releases).
A capability is a Markdown file with one fenced `runtime` block. Runtime
executes that block under its policy and records audit evidence. The prose
around the block explains what the workflow does, what it needs, and how to
run it.

The same file works for a person at a terminal, a CI job, or an AI assistant.

## What is here

| Directory | Contents |
|---|---|
| [`capabilities/github`](capabilities/github/README.md) | 50 read-only GitHub workflows: repositories, pull requests, Actions, governance and security, releases |
| [`capabilities/platform`](capabilities/platform/README.md) | Workflows across several providers, including a Java service scaffold-and-ship showcase |
| [`capabilities/files`](capabilities/files/README.md) | A credential-free File Engine round trip, for checking your setup |

Everything under `capabilities/github` is read-only. The one capability that
writes to GitHub, `platform/java-service-scaffold-and-ship`, says so at the
top. Run it only against a disposable repository you own.

## Requirements

These capabilities target Engineering Runtime **0.10.0 or later** and are
validated against the current release. Check your version with:

```bash
engrt version
```

Most GitHub capabilities need GitHub authority (for example
`ENGRT_GITHUB_TOKEN`) and some need `gh` installed. Each file lists exactly
what it needs.

## Use one

```bash
git clone https://github.com/engineeringruntime/engineering-runtime-capabilities.git
cd engineering-runtime-capabilities

engrt capability validate capabilities/github/github-repo-view.md
engrt capability plan     capabilities/github/github-repo-view.md --input repository=cli/cli
engrt capability execute  capabilities/github/github-repo-view.md --input repository=cli/cli
```

- `validate` checks grammar and operation names. It does not authenticate or
  contact GitHub.
- `plan` applies inputs and policy without performing any effect.
- `execute` runs the workflow and writes audit evidence.

To make the whole catalogue discoverable by name, point Runtime at this
checkout:

```bash
export ENGRT_CAPABILITIES_DIR="$PWD/capabilities"
engrt capability list
```

## Write one

Author against the contract installed with your Runtime, not a copy:

```bash
engrt --output json capability authoring-context
```

That output names the installed `capability-spec.md` and provider specs. Ask
for exact targets as inputs; Runtime never infers a repository, organization or
project from your current directory. Keep credentials out of capability source
and inputs.

Before opening a pull request, validate every file:

```bash
sh scripts/validate-corpus.sh
```

The script runs `engrt capability validate` on each capability with the
fixtures in [`validation/`](validation/). It executes nothing and needs no
credentials.

## License

Capability definitions, examples and related materials in this repository are
licensed under the [Apache License 2.0](LICENSE). The Engineering Runtime
executable is separate, proprietary software; see [NOTICE](NOTICE).
