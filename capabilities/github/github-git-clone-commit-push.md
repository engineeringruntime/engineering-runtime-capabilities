# Clone a repository, add a file, commit and push

The full git round trip through the runtime: clone, write a file with the
File Engine, stage it, commit with a message, push. Every step is governed
and audited; nothing runs outside the lifecycle.

This is the alternative to [`github-file-push.md`](./github-file-push.md),
and the two suit different jobs:

| | `github-file-push.md` | this capability |
|---|---|---|
| Mechanism | GitHub Contents API | real `git` working copy |
| Needs `git` installed | no | yes |
| Content encoding | base64 input | plain file on disk |
| Files per commit | one | as many as you write before committing |
| Leaves a working copy | no | yes, at `workdir` |
| Works for non-GitHub remotes | no | yes |

Use the Contents API version for a single small file. Use this one when you
want a real checkout, multiple files in one commit, or a non-GitHub remote.

## Why every git step passes `-C`

The Command Engine does not set a working directory — it inherits whatever
directory `runtime` was invoked from (`internal/engine/command.go`). So a
capability can never rely on "the shell is in the repo now"; each git step
states the directory explicitly with `git -C <dir>`.

That is a feature, not a workaround: it keeps each step independently
meaningful and re-runnable, and it means a step's behaviour doesn't depend
on invisible state left by the step before it.

## Governance

`git` is in `allowed_binaries`, with `command_policy.rules.git` refusing the
irreversible operations:

```
push --force · push -f · reset --hard · clean -fd · filter-branch · update-ref -d
```

Those rules match a contiguous run of argument tokens anywhere in the
command, so `git -C /tmp/wd push --force` is denied exactly like the bare
form. Ordinary `push`, `commit`, `add` and every read command are allowed.

## Credentials — read this before running

`git` is deliberately **not** mapped in `config.yaml`'s `command_providers`,
so the Auth Engine does not run for it, and the runtime does **not** hand
git a token. git uses its own credential mechanism, exactly as `terraform`
uses its own — consistent with "authenticate using the platform, govern
using the runtime".

In practice:

- **Locally**, git uses your existing credential helper (macOS keychain,
  SSH agent, ...). If `git push` works in your terminal, it works here.
- **In CI**, configure git first — `gh auth setup-git`, a token-bearing
  remote URL, or a deploy key. This capability will not do it for you, and
  will fail honestly at the push step rather than half-succeeding.
- A committer identity must be set (`git config user.name` / `user.email`),
  otherwise `git commit` refuses.

## Inputs and preconditions

`workdir` **must not already exist** — `git clone` refuses a non-empty
target. Use a fresh path per run (e.g. under `/tmp`) and delete it
afterwards, or point `repository_url` at a checkout path you rotate.

## Run it

```bash
runtime capability validate capabilities/github/github-git-clone-commit-push.md

runtime capability execute capabilities/github/github-git-clone-commit-push.md \
  --input repository_url=https://github.com/kishore-gutta/my-repo.git \
  --input workdir=/tmp/my-repo-work \
  --input path=notes.txt \
  --input content="hello from the engineering runtime" \
  --input message="Add notes via Engineering Runtime"
```

Then check what happened:

```bash
runtime audit tail -n 10      # one record per step, with the transport used
rm -rf /tmp/my-repo-work      # clean up the working copy
```

## What each step does

1. **clone** — Command Engine, `git`
2. **write the file** — File Engine, via the `files` provider (no auth, no network)
3. **stage** — Command Engine, `git -C`
4. **commit** — Command Engine, `git -C`
5. **push** — Command Engine, `git -C`

Note step 2: a capability can mix providers freely. The `files` provider
writes the file, the `git` binary commits it, and both go through the same
Bootstrap → Context → Policy → Auth → Execution → Audit lifecycle.

Execution stops at the first failing step, so a failed clone never leaves a
half-made commit, and a rejected push leaves the commit sitting in the
working copy for you to inspect.

```runtime
version: v1

inputs:
  repository_url:
    description: Clone URL, e.g. https://github.com/<owner>/<repo>.git
    required: true
  workdir:
    description: Directory to clone into. Must not already exist.
    required: true
  path:
    description: File to create inside the repository, e.g. notes.txt
    required: true
  content:
    description: Text content to write into the file
    required: true
  message:
    description: Commit message
    required: true

workflow:
  - binary: git
    args: [clone, "${repository_url}", "${workdir}"]

  - provider: files
    args: [write, "${workdir}/${path}", "${content}"]

  - binary: git
    args: [-C, "${workdir}", add, "${path}"]

  - binary: git
    args: [-C, "${workdir}", commit, -m, "${message}"]

  - binary: git
    args: [-C, "${workdir}", push]
```
