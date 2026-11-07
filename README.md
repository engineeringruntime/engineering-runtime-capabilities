# Engineering Runtime Capabilities

Reusable engineering workflows for [Engineering Runtime](https://github.com/engineeringruntime/engineering-runtime-releases)
(`engrt`). A capability is a Markdown file with one fenced `runtime` block.
Runtime executes that block under your policy and records audit evidence. The
prose around the block explains what the workflow does, what it needs and how
to run it.

The same file works for a person at a terminal, a CI job or an AI assistant.

## What is here

| Directory | Contents |
|---|---|
| [`capabilities/github`](capabilities/github/README.md) | 53 read-only GitHub workflows (repositories, pull requests, Actions, governance, standards drift, releases), plus 17 that write: a service lifecycle from onboarding to retirement, rulesets and Actions environments |
| [`capabilities/platform`](capabilities/platform/README.md) | Workflows across several providers, including a Java service scaffold-and-ship showcase |
| [`capabilities/files`](capabilities/files/README.md) | A credential-free File Engine round trip, for checking your setup |
| [`examples/`](examples/) | A sample `config.yaml` and `policy.yaml` that run every capability here |
| [`demo/`](demo/README.md) | A script that runs every capability against disposable demo repositories, and its [latest results](demo/RESULTS.md) |

Most capabilities are read-only. The ones that write to GitHub start with a
**Mutating** banner and are listed separately in each index:

- the [service lifecycle](capabilities/github/README.md#service-lifecycle-writes)
  capabilities, which create, change, release, deploy, freeze and archive
  repositories;
- the [rulesets and environments](capabilities/github/README.md#rulesets-and-environments-writes)
  capabilities, which change repository configuration;
- `platform/java-service-scaffold-and-ship`, which commits, pushes and
  dispatches a workflow. Run it only against a disposable repository you own.

## Quick start: from install to your first run

Ten minutes, on macOS or Linux. Every command below was run on Engineering
Runtime 0.13.0.

### 1. Install Engineering Runtime

With Homebrew (macOS and Linux):

```bash
brew install engineeringruntime/tap/engineering-runtime
engrt version            # engrt 0.13.0 or later
```

Without Homebrew, download the archive for your platform from the
[latest release](https://github.com/engineeringruntime/engineering-runtime-releases/releases/latest),
check it against `SHA256SUMS.txt` in the same release, and put `engrt` on your
`PATH`. The [releases repository](https://github.com/engineeringruntime/engineering-runtime-releases)
also has a shell installer and a Windows PowerShell installer.

Read-only capabilities need 0.10.0 or later. The capabilities that write need
**0.13.0 or later**; each file declares the version it needs, and an older
Runtime refuses it.

To upgrade later: `brew update && brew upgrade engineering-runtime`.

### 2. Install `git` and `gh`

Some GitHub operations run through the GitHub CLI and some capabilities use
`git`:

```bash
git --version
gh --version             # https://cli.github.com
```

You do **not** need `gh auth login`: Runtime hands `gh` the authority it has
already checked.

### 3. Get this catalogue

```bash
git clone https://github.com/engineeringruntime/engineering-runtime-capabilities.git
cd engineering-runtime-capabilities
```

### 4. Point Runtime at the sample config and policy

Run these from the repository root, in every new terminal (or add them to
your shell profile with absolute paths):

```bash
export ENGRT_CONFIG_FILE="$PWD/examples/config.yaml"
export ENGRT_POLICY_FILE="$PWD/examples/policy.yaml"
export ENGRT_CAPABILITIES_DIR="$PWD/capabilities"
```

**[`examples/config.yaml`](examples/config.yaml)** says where GitHub authority
comes from. Without its comments it is:

```yaml
schema_version: 2
runtime:
  name: engineering-runtime
  log_level: info
portal:
  enabled: false                  # fully local; no Control Plane
authentication:
  provider: github
  github:
    enabled: true
    base_url: https://api.github.com   # GitHub Enterprise Server: https://<host>/api/v3
    token_env: ENGRT_GITHUB_TOKEN      # the variable's name, never the token
  gcp:        { enabled: false, binary: gcloud, source: native }
  kubernetes: { enabled: false, source: kubeconfig, kubeconfig_path: "" }
  openshift:  { enabled: false, binary: oc, server: "" }
capabilities:
  sources: []                     # ENGRT_CAPABILITIES_DIR selects this checkout
command_providers:
  gh: github                      # gh runs with the GitHub provider's authority
```

**[`examples/policy.yaml`](examples/policy.yaml)** says what Runtime may do.
It composes with a safety profile compiled into the binary, which no document
can switch off. Without its comments it is:

```yaml
schema_version: 3
providers:
  github:
    enabled: true
    denied:
      - api DELETE                # nothing is ever deleted through Runtime
  files:
    enabled: true
    denied:
      - delete
file_policy:                      # File Engine access is default-deny
  read_roots:  ["."]              # "." = the directory you run engrt from
  write_roots: ["."]
  max_read_bytes: 1048576
  max_list_entries: 1000
  max_depth: 32
allowed_binaries: [gh, git]       # the only programs Runtime may start
command_policy:
  denied_binaries: [rm, sudo, chmod, curl, wget, ssh]
  rules:
    git:
      denied: [push --force, push -f, push --force-with-lease, push --delete,
               reset --hard, clean -fd, filter-branch, update-ref -d]
    gh:
      denied: [api, auth token, repo archive, repo delete, repo edit --visibility,
               release delete, secret delete, variable delete, run delete,
               workflow disable, pr merge --admin]
```

Neither file holds a credential. Copy them and narrow them for your own use;
keep `api DELETE` denied unless you have a reason. They are separate from the
validation-only fixtures in [`validation/`](validation/), which can execute
nothing.

### 5. Give Runtime GitHub authority

Create a [personal access token](https://github.com/settings/tokens) and export
it. Export it in your shell, never put it in a file in this repository:

```bash
export ENGRT_GITHUB_TOKEN=<your token>
```

| To run | Classic token scopes |
|---|---|
| read-only capabilities | `repo`, `read:org` |
| the write capabilities | add `workflow` (onboarding writes `.github/workflows/ci.yml`) and `admin:org` (team access, organization settings) |

Fine-grained tokens and GitHub Apps work too; each capability lists the exact
permissions it needs under **What it needs**.

Set only **one** token source. If `ENGRT_GITHUB_TOKEN_FILE` is also set,
Runtime refuses with `auth_source_ambiguous` rather than guess.

### 6. Check the setup

```bash
engrt config validate
engrt auth status
```

`config validate` names the config and policy in force (they should be the two
`examples/` files) and lists `gh` and `git` as installed. `auth status` should
show `github ✓` with your login.

### 7. Run your first capability (read-only)

Find one, read what it does, then run it in three stages:

```bash
engrt capability list                                  # every capability, by name
engrt capability inspect github/github-repo-view       # inputs, steps, providers

engrt capability validate github/github-repo-view      # grammar only; no network
engrt capability plan     github/github-repo-view --input repository=cli/cli
engrt capability execute  github/github-repo-view --input repository=cli/cli
```

- `validate` checks grammar and operation names. It does not authenticate or
  contact GitHub.
- `plan` resolves inputs, authority and policy for every step and performs
  nothing. A policy denial shows up here, before anything runs.
- `execute` runs the workflow and records audit evidence.

Every target is an explicit input. Runtime never infers a repository or
organization from your current directory.

For machine-readable output, put `--output json` before the command:

```bash
engrt --output json capability execute github/github-repo-health --input repository=cli/cli
```

See what was recorded, and check the evidence chain:

```bash
engrt audit tail
engrt audit verify
```

### 8. Run one that writes

Use a repository you own and can change. Always `plan` first, read it, then
`execute` with the same inputs:

```bash
engrt capability plan    github/repo-labels-standard-sync \
  --input organization=<your-org> --input repository=<your-repo>
engrt capability execute github/repo-labels-standard-sync \
  --input organization=<your-org> --input repository=<your-repo>
```

Write capabilities follow **observe → change only when needed → verify**:
run the same command again and it writes nothing. Their gates stop a run
before any write when a precondition fails, and the result names the step that
stopped it.

To create a fully protected service repository from nothing, start with
[`java-springboot-service-onboard`](capabilities/github/java-springboot-service-onboard.md);
the [service lifecycle](capabilities/github/README.md#service-lifecycle-writes)
table shows what comes after it.

### 9. Try everything

[`demo/run-demo.sh`](demo/README.md) runs all 73 capabilities through `engrt`
with the sample config and policy, on two disposable repositories it creates
in an organization you name. Read [demo/README.md](demo/README.md) first: it
creates repositories and a team, merges a pull request, publishes a release
and runs GitHub Actions.

```bash
bash demo/run-demo.sh <organization> check     # touches nothing
```

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `auth_source_ambiguous` | Two token sources are set (for example `ENGRT_GITHUB_TOKEN` and `ENGRT_GITHUB_TOKEN_FILE`). Unset one. |
| `engrt config validate` shows another config or policy | A different `ENGRT_CONFIG_FILE` / `ENGRT_POLICY_FILE` is exported in your shell profile. Re-run step 4 in this terminal. |
| `policy denied …` | The sample policy refuses that operation on purpose (for example `api DELETE`, `files delete`, `git push --force`). `plan` shows it before anything runs. |
| A File Engine step is refused as outside every granted root | Capabilities that take a `workdir` or `path` need it under the directory you run `engrt` from (the policy's `"."`). `cd` to its parent and run again. |
| `github-branch-protection-audit` or `github-repo-branches-and-protection` stops with `404` | The branch has no classic branch protection; it may be protected by rulesets instead. Use `github-repo-rulesets-export` or `repo-standards-drift`. |
| `github-security-posture` stops with `404` | Code scanning is not set up on that repository. |
| A feature is reported as unavailable on a private repository | Secret scanning, push protection, private vulnerability reporting and environment reviewers need a public repository or a paid GitHub plan. Each capability says which. |
| Runs get slow over time | Runtime appends every run to its evidence journal in its home (`~/.engrt`). For experiments, use a separate one: `export ENGRT_HOME="$HOME/.engrt-demo"`. |

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
