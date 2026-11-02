# Platform capabilities

Workflows that span more than one provider, such as GitHub plus a local
checkout and the File Engine.

| Capability | What it does | Effects |
|---|---|---|
| [`repository-delivery-readiness`](repository-delivery-readiness.md) | Gathers remote repository, pull request and CI state beside the local working tree and a delivery document | Read-only |
| [`java-service-scaffold-and-ship`](java-service-scaffold-and-ship.md) | Scaffolds a Maven service into a repository, commits and pushes it, then dispatches its Actions pipeline | **Writes**: creates files and commits, pushes, dispatches a workflow |

`java-service-scaffold-and-ship` changes a real repository. Point it at a new,
disposable repository you own, and read its "What it needs" section before
running it. It needs a policy that grants File Engine read/write roots and
admits `git` and `gh`.
