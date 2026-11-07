## What

<!-- Which capabilities this adds or changes, and the outcome each one delivers. -->

## How it was tested

<!-- engrt version and platform. Paste the plan result, and for execute the status and step counts.
     Remove tokens, private repository names and personal data. -->

- engrt version:
- `plan`:
- `execute`:

## Checklist

- [ ] `sh scripts/validate-corpus.sh` passes.
- [ ] `engrt capability plan` passes under [`configs/policy.yaml`](https://github.com/engineeringruntime/engineering-runtime-capabilities/blob/main/configs/policy.yaml) with realistic inputs.
- [ ] A capability that writes was executed against a disposable repository, and a rerun wrote nothing.
- [ ] A capability that writes starts with a **Mutating** banner saying what it changes.
- [ ] It declares `capability_version` and `engrt_version`, and every step has an `id`.
- [ ] Every target (organization, repository, branch) is an input; nothing is inferred.
- [ ] Examples use placeholders (`<organization>`, `<repository>`), not real names.
- [ ] No credentials, tokens or personal data anywhere in the file.
- [ ] The index (`capabilities/<provider>/README.md`) lists it, in the right section.
