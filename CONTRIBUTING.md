# Contributing

Thanks for helping. This repository holds capability files: Markdown workflows
that Engineering Runtime (`engrt`) executes. `engrt` itself is closed source
and lives elsewhere.

## How to get involved

1. **Not sure yet, or just an idea?** Start a [Discussion](https://github.com/orgs/engineeringruntime/discussions/categories/ideas): ask in
   [Q&A](https://github.com/orgs/engineeringruntime/discussions/categories/q-a), or share an idea in [Ideas](https://github.com/orgs/engineeringruntime/discussions/categories/ideas).
2. **It is concrete?** Open an issue: a capability problem or request in
   [engineering-runtime-capabilities](https://github.com/engineeringruntime/engineering-runtime-capabilities/issues/new/choose), a problem or request for `engrt`
   itself in [engineering-runtime-releases](https://github.com/engineeringruntime/engineering-runtime-releases/issues/new/choose).
3. **Want to build it?** Capabilities are open source: open a
   [pull request](https://github.com/engineeringruntime/engineering-runtime-capabilities/pulls) to the capabilities repository.

## Where to report what

| You found… | Report it in |
|---|---|
| A capability here fails, gives a wrong result, or its prose is wrong | [this repository's issues](https://github.com/engineeringruntime/engineering-runtime-capabilities/issues/new/choose) (**A capability does not work**) |
| A capability you would like | [this repository's issues](https://github.com/engineeringruntime/engineering-runtime-capabilities/issues/new/choose) (**Request a capability**) |
| A problem with `engrt` itself: install, upgrade, CLI, auth, policy, audit, a provider operation, MCP | [engineering-runtime-releases issues](https://github.com/engineeringruntime/engineering-runtime-releases/issues/new/choose) |
| A question | [Discussions → Q&A](https://github.com/orgs/engineeringruntime/discussions/categories/q-a) |
| An idea that is not concrete yet | [Discussions → Ideas](https://github.com/orgs/engineeringruntime/discussions/categories/ideas) |
| A security vulnerability | privately: [Report a vulnerability](https://github.com/engineeringruntime/engineering-runtime-capabilities/security/advisories/new) on the Security tab, or email support@engineeringruntime.com. See [SECURITY.md](SECURITY.md). Never in a public issue |

Not sure whether it is the capability or `engrt`? Run the same operation
directly (for example `engrt github api GET …`). If it fails there too, it is
an `engrt` issue.

Remove tokens, private repository names and personal data from anything you
paste.

## Before you write a capability

- **Search first:** `engrt capability search "<terms>"` and the
  [GitHub index](capabilities/github/README.md). Improving an existing
  capability beats adding a near-duplicate.
- **For a new capability, open a request issue first** so the outcome and its
  safety gates can be agreed before you write it.
- A capability can only use operations `engrt` already offers (`engrt github
  --help`, `engrt files --help`, `engrt command run` with an allowed binary).
  If something is missing, that is an `engrt` request, not a capability.

## Set up

Follow the [Quick start](README.md#quick-start-from-install-to-your-first-run):
install `engrt` 0.13.0 or later, `git` and `gh`, and select
[`configs/config.yaml`](configs/config.yaml) and
[`configs/policy.yaml`](configs/policy.yaml).

## Write it

Author against the contract installed with your Runtime, not a copy of it:

```bash
engrt --output json capability authoring-context
```

That names the installed `capability-spec.md` and provider specs. Then:

- **One file, one fenced `runtime` block, grammar `v1`.** Declare
  `capability_version` and `engrt_version`, and give every step an `id`.
- **Every target is an input.** Organization, repository, branch, run or pull
  request number: Runtime never infers them, and neither should a capability.
- **Writes start with a Mutating banner** at the top of the file, saying
  exactly what it creates or changes and what it never does.
- **Observe, change only when needed, verify.** A write capability reads the
  current state, writes only when it differs, and reads back what it wrote. A
  rerun of a completed run must write nothing.
- **Gates before writes.** Preconditions (an open pull request, a failing
  build, the wrong ruleset layout) stop the run before anything is written.
- **No deletion.** The example policy denies `api DELETE` and `files delete`;
  archive or disable instead, so a person can undo it.
- **No credentials** in the file or in inputs. Authority comes from the
  configured provider.
- **Placeholders in examples:** `<organization>`, `<repository>`, never real
  names.
- **Prose a stranger can follow:** what it does, what it needs (policy,
  credential permissions, GitHub plan), known limits, and a `plan` command to
  run first.
- **List it** in `capabilities/<provider>/README.md`, in the read-only or the
  writes section.

## Test it

```bash
sh scripts/validate-corpus.sh                       # every file still validates
engrt capability plan <name> --input …              # ALLOWED under configs/policy.yaml
engrt capability execute <name> --input …           # read-only: against any repository you can read
```

A capability that writes must be executed against a **disposable** repository
you own, then run again to show the rerun writes nothing. Test each gate that
should refuse, too. [`demo/run-demo.sh`](demo/README.md) shows how the
catalogue itself is tested end to end.

## Open the pull request

Fill in the [pull request template](.github/pull_request_template.md): what
it adds, the `engrt` version and platform you tested on, the plan and execute
results, and the checklist. A maintainer reviews it and merges it.

## Licence of contributions

This repository is licensed under the [Apache License 2.0](LICENSE). As its
section 5 provides, anything you submit for inclusion is licensed under the
same terms, unless you say otherwise in writing. The `engrt` executable is
separate, proprietary software; see [NOTICE](NOTICE).
