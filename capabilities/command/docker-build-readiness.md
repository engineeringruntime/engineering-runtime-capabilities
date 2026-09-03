# Docker build-client readiness

Check the Docker CLI, Buildx plugin, and configured Docker contexts before a
build is attempted. These reads do not build, push, prune, or start a container.

```runtime
version: v1

workflow:
  - binary: docker
    args: [--version]
  - binary: docker
    args: [buildx, version]
  - binary: docker
    args: [context, ls]
```
