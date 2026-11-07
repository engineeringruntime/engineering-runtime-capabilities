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
| [`configs/`](configs/) | `config.yaml` and `policy.yaml` that run every capability here, with every GitHub authentication option documented |
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

Everything you need is on this page: install Runtime, connect it to GitHub,
run a capability. The commands are for macOS and Linux (`bash`/`zsh`);
Windows PowerShell equivalents follow each step where they differ.

Tested as written on macOS (Apple silicon) with Engineering Runtime 0.13.0:
install options A, B and C, then steps 2 to 9 from a fresh clone. All three
install options produce the same `engrt` binary. Linux and Windows (option D)
follow the same published installers and archives but have not been run
through this guide yet.

### 1. Install Engineering Runtime

Engineering Runtime is one binary, `engrt`, published for macOS, Linux and
Windows on `amd64` and `arm64`. Pick one way:

**A. Homebrew (macOS and Linux)**

```bash
brew install engineeringruntime/tap/engineering-runtime
engrt version            # engrt 0.13.0
```

Upgrade later with `brew update && brew upgrade engineering-runtime`.

**B. Install script (macOS and Linux)**

Downloads the archive for your OS and architecture from the latest release,
verifies it against the release's `SHA256SUMS.txt` (nothing is installed if it
does not match) and installs `engrt` in `/usr/local/bin` when that is writable,
otherwise in `~/.local/bin`. It needs `curl`, `tar` and `shasum` or
`sha256sum`.

```bash
curl -fsSL https://raw.githubusercontent.com/engineeringruntime/engineering-runtime-releases/main/install.sh | sh
engrt version
```

It prints each stage and ends with the location:

```text
Engineering Runtime v0.13.0 (darwin/arm64)
  downloading engrt-v0.13.0-darwin-arm64.tar.gz
  downloading SHA256SUMS.txt
  verifying checksum

Installed engrt 0.13.0
  location: /Users/you/.local/bin/engrt
```

`VERSION` pins a release and `INSTALL_DIR` chooses the directory:

```bash
curl -fsSL https://raw.githubusercontent.com/engineeringruntime/engineering-runtime-releases/main/install.sh \
  | VERSION=v0.13.0 INSTALL_DIR="$HOME/.local/bin" sh
```

If it prints `NOTE: … is not on your PATH`, add that directory and open a new
terminal:

```bash
export PATH="$HOME/.local/bin:$PATH"     # add this line to ~/.zshrc or ~/.bashrc
```

**C. By hand (macOS and Linux)**

Run this in an empty directory. It detects your OS and architecture, so there
is nothing to edit except `VERSION`:

```bash
VERSION=v0.13.0
OS=$(uname -s | tr '[:upper:]' '[:lower:]')                        # darwin or linux
ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')  # amd64 or arm64
NAME=engrt-$VERSION-$OS-$ARCH
BASE=https://github.com/engineeringruntime/engineering-runtime-releases/releases/download/$VERSION

curl -fsSLO "$BASE/$NAME.tar.gz"
curl -fsSLO "$BASE/SHA256SUMS.txt"
grep "$NAME.tar.gz" SHA256SUMS.txt | shasum -a 256 -c -     # Linux without shasum: sha256sum -c -
tar -xzf "$NAME.tar.gz"
mkdir -p ~/.local/bin && install -m 0755 "$NAME/engrt" ~/.local/bin/engrt
export PATH="$HOME/.local/bin:$PATH"                         # add this line to ~/.zshrc or ~/.bashrc
engrt version
```

The checksum line must print `engrt-v0.13.0-<os>-<arch>.tar.gz: OK`. If it
prints `FAILED`, stop: the archive is not the published one. Delete it and
download again.

**D. Windows (PowerShell 7, x64 or Arm64)**

The script verifies the checksum and installs `engrt.exe` in
`%USERPROFILE%\.local\bin`:

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/engineeringruntime/engineering-runtime-releases/main/install.ps1 -OutFile install.ps1
./install.ps1                                   # or: ./install.ps1 -Version v0.13.0 -InstallDirectory C:\Tools\engrt
$env:PATH = "$HOME\.local\bin;$env:PATH"      # also add it to your user PATH for new terminals
engrt version
```

By hand: download `engrt-v0.13.0-windows-<amd64|arm64>.zip` and
`SHA256SUMS.txt` from the
[latest release](https://github.com/engineeringruntime/engineering-runtime-releases/releases/latest),
compare `Get-FileHash <zip>` with its line, and put `engrt.exe` on your `PATH`.

**Which version?** `engrt version` must print **0.13.0 or later** for the
capabilities that write; read-only ones work from 0.10.0. Each capability
declares the version it needs, and an older Runtime refuses it rather than
run it differently. Runtime creates its home (`~/.engrt`) on the first command;
there is no separate setup step.

### 2. Install `git` and `gh`

Some GitHub operations run through the [GitHub CLI](https://cli.github.com) and
some capabilities use `git`:

| Platform | Install |
|---|---|
| macOS | `brew install git gh` |
| Debian, Ubuntu | `sudo apt install git gh` (or GitHub's [apt repository](https://github.com/cli/cli/blob/trunk/docs/install_linux.md) for a current `gh`) |
| Fedora, RHEL | `sudo dnf install git gh` |
| Windows | `winget install --id Git.Git` and `winget install --id GitHub.cli` |

```bash
git --version
gh --version
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
export ENGRT_CONFIG_FILE="$PWD/configs/config.yaml"
export ENGRT_POLICY_FILE="$PWD/configs/policy.yaml"
export ENGRT_CAPABILITIES_DIR="$PWD/capabilities"
```

```powershell
# Windows
$env:ENGRT_CONFIG_FILE = "$PWD\configs\config.yaml"
$env:ENGRT_POLICY_FILE = "$PWD\configs\policy.yaml"
$env:ENGRT_CAPABILITIES_DIR = "$PWD\capabilities"
```

**[`configs/config.yaml`](configs/config.yaml)** says where GitHub authority
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
    source: env                        # env | file | os_secure_store | github_app | github_actions (step 5)
  gcp:        { enabled: false, binary: gcloud, source: native }
  kubernetes: { enabled: false, source: kubeconfig, kubeconfig_path: "" }
  openshift:  { enabled: false, binary: oc, server: "" }
capabilities:
  sources: []                     # ENGRT_CAPABILITIES_DIR selects this checkout
command_providers:
  gh: github                      # gh runs with the GitHub provider's authority
```

**[`configs/policy.yaml`](configs/policy.yaml)** says what Runtime may do.
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
keep `api DELETE` denied unless you have a reason.

### 5. Give Runtime GitHub authority

Pick **one** source and set `source:` in `configs/config.yaml` to it. The file
ships with `source: env`. Runtime uses only the source you name: if it fails,
Runtime stops and never falls back to another one.

| `source:` | Use it for | What to set |
|---|---|---|
| `env` (default) | trying it out; scripts | `export ENGRT_GITHUB_TOKEN=<token>` |
| `file` | CI secrets mounted as files, Kubernetes secret volumes | `export ENGRT_GITHUB_TOKEN_FILE=/path/to/token` (the token on one line) |
| `os_secure_store` | a person on their own machine (recommended) | run `engrt auth login github` once; the session is kept in the macOS Keychain, Windows Credential Manager or Linux Secret Service |
| `github_app` | automation that should act as a GitHub App, not a person | add `app_id: "<app id>"` and `installation_id: "<installation id>"` under `source:`, and `export ENGRT_GITHUB_APP_PRIVATE_KEY_FILE=/path/to/app.private-key.pem` |
| `github_actions` | inside a GitHub Actions job, with the job's `GITHUB_TOKEN` | nothing else; Runtime accepts it only when it observes it is running in Actions |

For example, to act as a GitHub App:

```yaml
authentication:
  github:
    enabled: true
    base_url: https://api.github.com
    token_env: ENGRT_GITHUB_TOKEN
    source: github_app
    app_id: "<app id>"                    # from the App's settings page
    installation_id: "<installation id>"  # from the installation's URL
```

```bash
export ENGRT_GITHUB_APP_PRIVATE_KEY_FILE="$HOME/keys/my-app.private-key.pem"
```

Keep tokens and keys outside this repository, and never put a value in the
config file: it holds only names and IDs.

```powershell
# Windows, source: env
$env:ENGRT_GITHUB_TOKEN = "<your token>"
```

**Token permissions** (`env`, `file` and `os_secure_store` act as you):

| To run | Classic token scopes |
|---|---|
| read-only capabilities | `repo`, `read:org` |
| the write capabilities | add `workflow` (onboarding writes `.github/workflows/ci.yml`) and `admin:org` (team access, organization settings) |

Fine-grained tokens and GitHub Apps need the matching repository and
organization permissions; each capability lists them under **What it needs**.
A GitHub App can change only the repositories it is installed on.

### 6. Check the setup

```bash
engrt config validate
engrt auth status
```

`config validate` names the config and policy in force (they should be the two
`configs/` files) and lists `gh` and `git` as installed. `auth status` should
show `github ✓` with the source you chose and who you are: your login, or
`installation:<id>` for a GitHub App.

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
| `auth_source_ambiguous` | Your config has no `source:` line and two inputs are set (for example `ENGRT_GITHUB_TOKEN` and `ENGRT_GITHUB_TOKEN_FILE`). Set `source:` (step 5); `configs/config.yaml` already does. |
| `auth_invalid_credential` | The selected source has no usable value: the variable is unset or empty, or the file is missing or has extra content. |
| `auth_surface_mismatch` with `job_source_requires_ci` | `source: github_actions` outside a GitHub Actions job. Choose another source locally. |
| `engrt config validate` shows another config or policy | A different `ENGRT_CONFIG_FILE` / `ENGRT_POLICY_FILE` is exported in your shell profile. Re-run step 4 in this terminal. |
| `policy denied …` | The sample policy refuses that operation on purpose (for example `api DELETE`, `files delete`, `git push --force`). `plan` shows it before anything runs. |
| A File Engine step is refused as outside every granted root | Capabilities that take a `workdir` or `path` need it under the directory you run `engrt` from (the policy's `"."`). `cd` to its parent and run again. |
| `github-branch-protection-audit` or `github-repo-branches-and-protection` stops with `404` | The branch has no classic branch protection; it may be protected by rulesets instead. Use `github-repo-rulesets-export` or `repo-standards-drift`. |
| `github-security-posture` stops with `404` | Code scanning is not set up on that repository. |
| A feature is reported as unavailable on a private repository | Secret scanning, push protection, private vulnerability reporting and environment reviewers need a public repository or a paid GitHub plan. Each capability says which. |
| Runs get slow over time | Runtime appends every run to its evidence journal in its home (`~/.engrt`). For experiments, use a separate one: `export ENGRT_HOME="$HOME/.engrt-demo"`. |

## Report a problem or ask

| About | Where |
|---|---|
| A capability in this repository, or a capability you would like | [Issues here](https://github.com/engineeringruntime/engineering-runtime-capabilities/issues/new/choose) |
| `engrt` itself: install, upgrade, CLI, auth, policy, audit, MCP | [engineering-runtime-releases issues](https://github.com/engineeringruntime/engineering-runtime-releases/issues/new/choose) |
| Questions | [Discussions → Q&A](https://github.com/orgs/engineeringruntime/discussions/categories/q-a) |
| Ideas not yet concrete | [Discussions → Ideas](https://github.com/orgs/engineeringruntime/discussions/categories/ideas) |
| A security vulnerability | privately, through the [contact page](https://engineeringruntime.com/contact/) |

To add or improve a capability, read [CONTRIBUTING.md](CONTRIBUTING.md).

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

The script runs `engrt capability validate` on each capability with the files
in [`configs/`](configs/). Validation reads no credential, contacts nothing and
executes nothing.

## License

Capability definitions, examples and related materials in this repository are
licensed under the [Apache License 2.0](LICENSE). The Engineering Runtime
executable is separate, proprietary software; see [NOTICE](NOTICE).
