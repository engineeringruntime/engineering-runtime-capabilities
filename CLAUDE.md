# Engineering Runtime Capabilities

## What this repo is

This repository **maintains Engineering Capabilities** — Markdown workflows
with an embedded ` ```runtime ` block — that the `runtime` binary from
`../engineering-runtime` executes **deterministically**.

This repo does not execute anything itself. It has no `internal/`, no
`main.go`. Every `runtime capability validate|execute …` invocation is
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
| `files/` | Auth-free capabilities against the `files` provider |
| `github/` | Capabilities against the `github` provider (and occasional `binary: gh` escape hatches) |
| `*/README.md` | Per-provider index, inputs, and run examples |

Reusable, general-purpose capabilities belong **here**. One-off demos and
sample projects belong in `../engineering-runtime-samples`. Runtime source,
engines, and providers belong in `../engineering-runtime`. AI sessions that
should only invoke `runtime` (never `gh`/cloud CLIs directly) use
`../engineering-runtime-ai-agent`. Never bolt workflow logic into the binary.

## How the runtime finds specs, commands, and capabilities

Capability authoring and execution depend on material the runtime seeds into
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

# Inspect what was seeded / refreshed
ls -R "${ENGINEERING_RUNTIME_HOME:-$HOME/.engineering-runtime}"
```

### User-owned (seeded once, never overwritten)

`capabilities/` under Runtime Home is **user-owned**: seeded from the
binary's embedded examples only when missing. Bootstrap never overwrites
edits on upgrade. Existing capabilities and the refreshed `specs/` /
`commands/` in Runtime Home are what agents and humans should read when
creating **new** capabilities.

### Point this repo (or any checkout) at the runtime

To author and run capabilities from a local checkout of *this* repo —
instead of the seeded `~/.engineering-runtime/capabilities` — set
`RUNTIME_CAPABILITIES_DIR` to that path. Bootstrap seeds into it when empty,
and `runtime capability validate|execute <name>` resolves names against it:

```bash
# Use this checkout (or a team-shared clone) as the capabilities directory
export RUNTIME_CAPABILITIES_DIR=~/work/capabilities   # e.g. a clone of this repo
# or, from inside this repo:
# export RUNTIME_CAPABILITIES_DIR="$(pwd)"

runtime bootstrap
runtime capability validate files/notes-roundtrip
runtime capability execute files/notes-roundtrip \
  --input path=./notes.txt --input message=hello
```

Write **new** capabilities into that directory (grouped by provider, e.g.
`files/`, `github/`). Address them by relative name
(`files/my-new-capability`) or by filesystem path.

## Creating a new capability

1. **Read the contracts from Runtime Home** (refreshed for the installed
   binary — not a copy imagined from memory):
   - `${ENGINEERING_RUNTIME_HOME:-$HOME/.engineering-runtime}/specs/capability-spec.md`
   - the matching per-provider spec under `specs/<provider>/`
   - the relevant cheatsheet under `commands/` when you need the CLI shape
2. **Only reference what the installed runtime can execute** — a step's
   `provider` + `args` must resolve to a real operation
   (`runtime <provider> --help`), or `binary` must be in `allowed_binaries`.
3. **Prefer provider operations over `binary:`** — name the operation; let
   the provider choose transport (REST / GraphQL / CLI).
4. **Never hardcode auth, org, project, namespace, or other Runtime Context
   values** — declare them as `inputs`.
5. **Validate before commit**:
   ```bash
   runtime capability validate files/my-new-capability
   # or against a path:
   runtime capability validate ./files/my-new-capability.md
   ```
6. **Update the provider folder's `README.md` index** when adding or renaming
   a capability.

## Architecture reminder

> AI reasons. Capabilities describe intent. Runtime executes. Deterministically.

This repo only owns the middle term. Specs and command cheatsheets come from
the binary into Runtime Home on each version refresh; capabilities live here
(or wherever `RUNTIME_CAPABILITIES_DIR` points) and stay under user control.
