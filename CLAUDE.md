# Engineering Runtime Capabilities

## What this repo is

This repository **maintains Engineering Capabilities** — Markdown workflows
with an embedded ` ```runtime ` block — that the `runtime` binary from
`../engineering-runtime` executes **deterministically**.

This repo does not execute anything itself. It has no `internal/`, no
`main.go`. Every `runtime capability authoring-context|list|validate|plan|execute …` invocation is
performed by the installed runtime; this repo only authors and versions the
capability files the runtime resolves and runs.

```
Intent → Capability (this repo) → Engineering Runtime → Engines → Industry Tools
```

AI reasons about intent. Capabilities describe the workflow. The runtime
executes — same inputs, same outcome, every time, under Bootstrap → Context
→ Policy → Auth → Execution → Audit.

## Layout

| Path | Contents |
|---|---|
| `capabilities/files/` | Auth-free capabilities against the `files` provider |
| `capabilities/github/` | Capabilities against the `github` provider (and occasional `binary: gh` escape hatches) |
| `*/README.md` | Per-provider index, inputs, and run examples |

Reusable, general-purpose capabilities belong **here**. One-off demos and
sample projects belong in `../engineering-runtime-ci`. Runtime source,
engines, and providers belong in `../engineering-runtime`. AI sessions that
should only invoke `runtime` (never `gh`/cloud CLIs directly) use
`../engineering-runtime-agent`. Never bolt workflow logic into the binary.

## How the runtime finds specs, commands, and capabilities

Capability authoring and execution depend on release-owned material the runtime refreshes into
the **Runtime Home** (defaults to `~/.engineering-runtime`, override with
`ENGINEERING_RUNTIME_HOME`). Bootstrap runs automatically before other
commands; invoke `runtime bootstrap` only when you need to inspect or force
a refresh.

### Runtime-owned (refreshed every binary version)

`specs/*` and `commands/*` **ship inside the runtime binary** (`assets.go`
`//go:embed`). They describe what *this* binary can do:

| Tree | Role |
|---|---|
| `specs/` | Capability-authoring contracts (`capability-spec.md` + per-provider specs). **Required reading before writing or changing a capability.** |
| `commands/` | Copy-paste CLI cheatsheets for the live surface |

When the binary's version differs from the `version` file in Runtime Home,
bootstrap **rewrites** these trees to match the binary and **prunes** files
the new version no longer ships. Do not keep hand-authored files here —
they will be removed on the next upgrade.

```bash
# After installing or upgrading the runtime binary
runtime bootstrap

# Inspect what was refreshed
ls -R "${ENGINEERING_RUNTIME_HOME:-$HOME/.engineering-runtime}"
```

### User-owned source (this repo)

Author capabilities **here**, never silently into Runtime Home. A Home
`capabilities/` directory is a provenance-labelled cache, not the library.
Use `runtime files write|append` for governed authoring. Commit or publish only
when the user explicitly requests it.

### Point this repo (or any checkout) at the runtime

To author and run from a local checkout, use the exact file path. For named
resolution, declare the checkout's `capabilities/` directory in the selected
external config document under ordered `capabilities.sources`:

```bash
runtime capability validate capabilities/files/notes-roundtrip.md
runtime capability plan capabilities/files/notes-roundtrip.md \
  --input path=./notes.txt --input message=hello
runtime capability execute capabilities/files/notes-roundtrip.md \
  --input path=./notes.txt --input message=hello
```

An external config source has this shape (use an absolute reviewed-checkout
path and select the config with `RUNTIME_CONFIG_FILE`):

```yaml
schema_version: 2
capabilities:
  authoring_source: maintained-corpus
  sources:
    - name: maintained-corpus
      dir: /absolute/path/to/engineering-runtime-capabilities/capabilities
```

`authoring_source` must match exactly one source and does not grant writes.
Policy must include the directory under `file_policy.write_roots`. Verify the
complete result with `runtime --output json capability authoring-context`.

`RUNTIME_CAPABILITIES_DIR` only relocates Runtime's implicit compatibility
cache in 0.6.0. It does not make this repository authoritative.

Write new capabilities under `capabilities/files/` or
`capabilities/github/`. Address them by exact filesystem path, or by relative
name after configuring the source.

## Creating a new capability

1. **Discover before reasoning** with `runtime --output json capability
   authoring-context`. Continue only when it reports the installed contracts,
   this exact selected worktree and `authoring_ready: true`.
2. **Reuse before creating** with `runtime capability list`; ask for every
   missing required input or target fact.
3. **Only reference what the installed runtime can execute** — a step's
   `provider` + `args` must resolve to a real operation
   (`runtime <provider> --help`), or `binary` must be in `allowed_binaries`.
4. **Prefer provider operations over `binary:`** — name the operation; let
   the provider choose transport (REST / GraphQL / CLI).
5. **Never hardcode auth, org, project, namespace, or other target values** —
   declare them as `inputs`; Runtime owns no context document.
6. **Write through Runtime, validate, then plan** — validation proves grammar
   and operations; planning applies context and policy without executing:
   ```bash
   runtime files write /absolute/path/to/.../my-new-capability.md '<reviewed Markdown>'
   runtime capability validate capabilities/files/my-new-capability.md
   runtime capability plan capabilities/files/my-new-capability.md --input key=value
   ```
7. **Show the diff, source and digest.** Publish only when explicitly requested;
   execute only through a separate explicit request.
8. **Update the provider folder's `README.md` index** when adding or renaming
   a capability.

If Runtime Home `RUNTIME-AGENT.md`, `manifest.json`, or `specs/` are missing
or do not match `runtime version`, restore them from that binary and stop.
Do not fetch `/metadata/*`.

## Architecture reminder

> AI reasons. Capabilities describe intent. Runtime executes. Deterministically.

This repo only owns the middle term. Specs and command cheatsheets come from
the binary into Runtime Home on each version refresh; definitions live in this
or another explicit source and stay under source-owner control.
