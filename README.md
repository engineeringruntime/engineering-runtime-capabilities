# engineering-runtime-capabilities

Maintained corpus of reviewed GitHub, Files, GCP and platform capabilities. Author here;
Runtime Home `capabilities/` is a non-authoritative compatibility cache, not a
second library. Begin with `runtime capability authoring-context`, write through
`runtime files`, validate, plan, and execute only after a separate explicit request.

Control Plane UI (portal Live + app) may catalog from a Runtime snapshot.
This checkout is the company library to author against.

See [`CLAUDE.md`](./CLAUDE.md) for authoring rules, exact-path use, and
authoritative `capabilities.sources` configuration.

## This repository is canonical

Every capability the product ships lives here and nowhere else. Until Runtime
0.9.2 the binary also embedded 47 of these files, and the two copies drifted —
the same capability existed twice and the copies disagreed, so a customer reading
this store and one reading their Runtime Home got different instructions. Those
embedded copies were deleted in 0.9.2. There is one copy now, and it is this one.

**What that means for a release.** The release gate validates every file here
against the candidate binary before tagging, and executes at least one capability
per transport — REST, GraphQL, the `gh` CLI, the File Engine and the Command
Engine — because validation parses a file and never runs it. A release that
changes behaviour a customer would now be wrong about updates the capability that
shows it, in the same cycle.

