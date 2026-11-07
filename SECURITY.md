# Security policy

## Reporting a vulnerability

**Do not open a public issue, discussion or pull request for a security
problem.** Report it privately, in one of two ways:

1. **On GitHub (preferred):** [**Report a vulnerability**](https://github.com/engineeringruntime/engineering-runtime-capabilities/security/advisories/new), also on
   this repository's **Security** tab. Only you and the maintainers see the
   report, and the fix, any advisory and your credit are handled in the same
   private thread.
2. **By email**, if you have no GitHub account:
   **[support@engineeringruntime.com](mailto:support@engineeringruntime.com?subject=Security%3A%20)**,
   with a subject that starts with `Security:`.

Please include:

- the capability (its name, as `engrt capability list` shows it) or the file
  that is affected, and the `engrt version` you ran it with;
- what an attacker, or a careless run, could do with it;
- the smallest set of steps that reproduces it, with placeholder names.

While you investigate:

- use test or revoked credentials, never a real token, and never send one;
- run capabilities only against repositories and organizations you own or are
  allowed to test;
- give us a chance to fix it before you disclose it.

## What happens next

- We aim to acknowledge your report within five business days.
- We keep you updated while we investigate and agree on when the issue
  can be disclosed.
- The fix lands on `main` with a note in the pull request. If you would like
  credit, tell us the name to use.

## Supported versions

Capabilities are not released separately: fixes go to `main`. Pull the latest
`main` to get them.

## Scope

In scope: the files in this repository.

- a capability that writes something its **Mutating** banner does not say, or
  writes when it claims to be read-only;
- a gate that should stop a run but lets a write through;
- a capability that puts a token, key or other secret value into its output;
- [`configs/policy.yaml`](configs/policy.yaml) allowing something it says it
  denies;
- the [GitHub Actions workflow](.github/workflows/engrt.yml) exposing its token
  or holding more permissions than it needs.

Problems in `engrt` itself (the binary, its policy and safety enforcement,
authentication, audit or the installers) go to the same address; see the
[releases repository's security policy](https://github.com/engineeringruntime/engineering-runtime-releases/security/policy).

Not in scope: vulnerabilities in GitHub or another provider. Report those to
that provider.
