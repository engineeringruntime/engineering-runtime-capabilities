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
| [`capabilities/github`](capabilities/github/README.md) | 53 read-only GitHub workflows (repositories, pull requests, Actions, governance, standards drift, releases), plus 17 that write: a service lifecycle from onboarding to retirement, rulesets and Actions environments |
| [`capabilities/platform`](capabilities/platform/README.md) | Workflows across several providers, including a Java service scaffold-and-ship showcase |
| [`capabilities/files`](capabilities/files/README.md) | A credential-free File Engine round trip, for checking your setup |
| [`examples/`](examples/) | A `config.yaml` and `policy.yaml` that run every capability here |
| [`demo/`](demo/README.md) | A script that runs every capability against disposable demo repositories, and its latest results |

Most capabilities here are read-only. The ones that write to GitHub say so at
the top of the file and are listed separately in each index:

- the [service lifecycle](capabilities/github/README.md#service-lifecycle-writes)
  capabilities, which create, change, release, deploy, freeze and archive
  repositories;
- the [rulesets and environments](capabilities/github/README.md#rulesets-and-environments-writes)
  capabilities, which change repository configuration;
- `platform/java-service-scaffold-and-ship`, which commits, pushes and
  dispatches a workflow. Run it only against a disposable repository you own.

Run `engrt capability plan` before executing any of them.

## Requirements

These capabilities target Engineering Runtime **0.10.0 or later** and are
validated against the current release. Check your version with:

```bash
engrt version
```

Most GitHub capabilities need GitHub authority (for example
`ENGRT_GITHUB_TOKEN`) and some need `gh` installed. Each file lists exactly
what it needs. The write capabilities need Engineering Runtime **0.13.0 or
later**; each declares its own `engrt_version`.

## Configure

[`examples/config.yaml`](examples/config.yaml) and
[`examples/policy.yaml`](examples/policy.yaml) are a working configuration
for this catalogue: GitHub authority from `ENGRT_GITHUB_TOKEN`, the `git` and
`gh` binaries, File Engine access under the directory you run from, and no
deletion through Runtime. They hold no credential.

```bash
export ENGRT_CONFIG_FILE="$PWD/examples/config.yaml"
export ENGRT_POLICY_FILE="$PWD/examples/policy.yaml"
export ENGRT_CAPABILITIES_DIR="$PWD/capabilities"
export ENGRT_GITHUB_TOKEN=<token>   # or: engrt auth login github
engrt config validate
engrt auth status
```

Copy and narrow them for your own use. They are separate from the
validation-only fixtures in [`validation/`](validation/), which can execute
nothing.

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
checkout (the [Configure](#configure) step already does):

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
