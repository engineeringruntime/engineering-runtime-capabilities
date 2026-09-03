# From nothing to a deployed service, in one capability

Create a GitHub repository, write a Java service and its delivery pipeline into
it, trigger that pipeline, and report the run. The pipeline builds the container
image, pushes it to Artifact Registry and deploys to Cloud Run.

## What runs where, and why the split is not arbitrary

| Stage | Runs in | Why |
|---|---|---|
| Create the repository | **Runtime** | `repo create` — curated operation |
| Write service, Dockerfile, pipeline | **Runtime** | `file put` — writes straight through the API, no clone |
| Trigger the pipeline | **Runtime** | `api POST …/dispatches` — see the transport note |
| Build the image | **CI** | see below |
| Push to Artifact Registry | **CI** | Runtime can, with `admitted_helpers` — this pipeline keeps it in CI; see below |
| Deploy to Cloud Run | **CI** | Runtime cannot: every `gcloud` change is refused |
| Report the run | **Runtime** | `api GET …/actions/runs` |

Two stages are not in Runtime because Runtime refuses them, and both refusals are
deliberate:

- **`docker push`** used to fail inside Runtime with `exec:
  "docker-credential-gcloud": executable file not found in $PATH`, because
  Runtime pins `docker` and runs it in a bounded environment that did not admit
  docker's transitive credential helper. **Runtime 0.9.1 added
  `command_policy.admitted_helpers`**, which admits named helper executables by
  absolute path, scoped to one parent binary — verified: with the helper admitted
  the same command authenticates and reaches the registry. This pipeline still
  pushes from CI, because the image is built there and moving bytes twice buys
  nothing; the constraint is now a choice rather than a limit. See
  [`gcp/gcp-image-build-and-push`](../gcp/gcp-image-build-and-push.md).
- **`gcloud run deploy`** is refused by the compiled safety profile at
  `selector_bound` strength: *"Read-only operations are allowed at this strength;
  changes are not."* Every `gcloud` write is refused, in a capability and through
  `runtime command run` alike.

Building in Runtime and pushing in CI would be the worst of both — the image
would have to cross machines. So the whole container stage lives in CI, where
`docker` has an ordinary environment.

## Why this uses `api` and not `workflow run`

`workflow run` and `run list` are curated operations and would read better here.
They do not work on Runtime v0.8.0:

```
runtime github workflow run … → gh reached the Command Engine with no pinned
                                 artifact
runtime github run list …     → the same
runtime command run gh …      → gh is registered as context-unsupported …
                                 Use the curated `runtime github ...` operations
```

`gh` is deliberately refused because it resolves the repository from the working
directory, so Runtime cannot pin what it would reach — and the refusal points at
the curated operations, which themselves route through `gh`. Every GitHub
operation whose transport is the CLI is therefore unreachable, while every REST
operation works.

So this capability uses the REST escape hatch for both steps. That is not a
stylistic choice, and it should be reverted to the curated operations once the
transport is fixed.

## What this capability does not do

- **It does not confirm a deployment.** The last step reports a *triggered run*.
  Whether the service is serving traffic is a separate check — run
  `gcp-cloudrun-deployment-provenance` afterwards.
- **It is not resumable.** A capability aborts on the first failure and the
  grammar has no conditionals. If it stops after the repository exists, rerun
  against a different name, or finish by hand. The steps are ordered so that
  everything before the first write is cheap to repeat.
- **It does not create the GCP credential.** The pipeline authenticates with a
  `GCP_SA_KEY` secret. A capability cannot set one: repository secrets require
  libsodium encryption the grammar cannot perform, and passing the value as an
  argument would write a credential into the audit record. Use an
  **organisation secret scoped to selected repositories**, granted by a human.
  Until that is granted, the pipeline runs and fails on authentication — which
  the run list will show.
- **It does not create the Artifact Registry repository.** That is a `gcloud`
  write. Confirm it exists first with `gcp-artifact-registry-footprint`.

## Why it duplicates `java-service-scaffold-and-ship`

Because **capabilities cannot call capabilities.** A step is `provider` or
`binary`; there is no include, and `runtime` is not an allowed binary. An
orchestrator must therefore inline every step it needs. That is a real cost of
the v1 grammar, and it is written down here rather than hidden: if the scaffold
changes, this file needs the same change.

The two differ in shape as well as content. `java-service-scaffold-and-ship`
clones, writes locally, commits and pushes. This one writes through `file put`,
so it needs no working directory, no `git`, and no local checkout at all.

## Prerequisites

- `RUNTIME_GITHUB_TOKEN` with permission to create repositories and dispatch workflows.
- An Artifact Registry repository that already exists.
- `GCP_SA_KEY` available to the new repository, with Artifact Registry write and
  Cloud Run admin.
- `${repository}` must be `<token owner>/<name>` and `${name}` the same name —
  `repo create` creates under the token's owner, and there is no step-output
  chaining to derive one from the other.

Run with:

```
runtime capability validate capabilities/platform/platform-service-bootstrap.md
runtime capability execute platform/platform-service-bootstrap \
  --input name=payments-api \
  --input repository=my-org/payments-api \
  --input service_name=payments-api \
  --input java_package_path=com/example/payments \
  --input image_uri=us-central1-docker.pkg.dev/my-project/my-repo/payments-api \
  --input region=us-central1 \
  --input gcp_project=my-project
```

```runtime
version: v1

inputs:
  name:
    description: Repository name to create, without the owner
    required: true
  repository:
    description: The same repository as <owner>/<repo>
    required: true
  service_name:
    description: Service name, used as the Cloud Run service and Maven artifactId
    required: true
  java_package_path:
    description: Java package in path form, e.g. com/example/payments
    required: true
  image_uri:
    description: Artifact Registry image path WITHOUT a tag
    required: true
  region:
    description: Cloud Run region
    required: true
  gcp_project:
    description: GCP project id the pipeline deploys into
    required: true

workflow:
  - provider: github
    args: [repo, create, "name=${name}", "private=true", "description=${service_name} — bootstrapped by Engineering Runtime"]

  - provider: github
    args:
      - file
      - put
      - "${repository}"
      - "pom.xml"
      - "message=Add Maven build for ${service_name}"
      - |
        content=<?xml version="1.0" encoding="UTF-8"?>
        <project xmlns="http://maven.apache.org/POM/4.0.0">
          <modelVersion>4.0.0</modelVersion>
          <groupId>com.example</groupId>
          <artifactId>${service_name}</artifactId>
          <version>0.1.0</version>
          <properties>
            <maven.compiler.source>21</maven.compiler.source>
            <maven.compiler.target>21</maven.compiler.target>
          </properties>
        </project>

  - provider: github
    args:
      - file
      - put
      - "${repository}"
      - "src/main/java/${java_package_path}/App.java"
      - "message=Add entry point for ${service_name}"
      - |
        content=import com.sun.net.httpserver.HttpServer;
        import java.io.OutputStream;
        import java.net.InetSocketAddress;

        public class App {
          public static void main(String[] args) throws Exception {
            int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));
            HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
            server.createContext("/", exchange -> {
              byte[] body = "ok\n".getBytes();
              exchange.sendResponseHeaders(200, body.length);
              try (OutputStream os = exchange.getResponseBody()) { os.write(body); }
            });
            server.start();
          }
        }

  - provider: github
    args:
      - file
      - put
      - "${repository}"
      - "Dockerfile"
      - "message=Add container image for ${service_name}"
      - |
        content=FROM maven:3.9-eclipse-temurin-21 AS build
        WORKDIR /src
        COPY pom.xml .
        COPY src ./src
        RUN mvn -q -B package

        FROM eclipse-temurin:21-jre
        WORKDIR /app
        COPY --from=build /src/target/classes /app/classes
        ENV PORT=8080
        EXPOSE 8080
        CMD ["java", "-cp", "/app/classes", "App"]

  - provider: github
    args:
      - file
      - put
      - "${repository}"
      - ".github/workflows/build-and-deploy.yml"
      - "message=Add build and deploy pipeline for ${service_name}"
      - |
        content=name: build-and-deploy

        on:
          workflow_dispatch:

        permissions:
          contents: read

        jobs:
          build-and-deploy:
            runs-on: ubuntu-latest
            steps:
              - uses: actions/checkout@v4

              - uses: google-github-actions/auth@v2
                with:
                  credentials_json: ${{ secrets.GCP_SA_KEY }}

              - uses: google-github-actions/setup-gcloud@v2

              - name: Configure Docker for Artifact Registry
                run: gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet
                env:
                  REGION: ${{ vars.REGION || 'us-central1' }}

              - name: Build and push
                run: |
                  IMAGE="${IMAGE_URI}:${GITHUB_SHA}"
                  docker build -t "$IMAGE" .
                  docker push "$IMAGE"
                env:
                  IMAGE_URI: ${{ vars.IMAGE_URI }}

              - name: Deploy to Cloud Run
                run: |
                  gcloud run deploy "${SERVICE}" \
                    --image "${IMAGE_URI}:${GITHUB_SHA}" \
                    --region "${REGION}" \
                    --project "${GCP_PROJECT}" \
                    --platform managed \
                    --allow-unauthenticated
                env:
                  SERVICE: ${{ vars.SERVICE_NAME }}
                  IMAGE_URI: ${{ vars.IMAGE_URI }}
                  REGION: ${{ vars.REGION || 'us-central1' }}
                  GCP_PROJECT: ${{ vars.GCP_PROJECT }}

  - provider: github
    args:
      - file
      - put
      - "${repository}"
      - "README.md"
      - "message=Describe ${service_name}"
      - |
        content=# ${service_name}

        Bootstrapped by Engineering Runtime.

        Runtime created this repository, wrote the service and the pipeline, and
        triggered the first run. The pipeline builds the image, pushes it to
        Artifact Registry and deploys to Cloud Run — those three stages run in CI
        because Runtime deliberately refuses them: `gcloud` changes are denied at
        `selector_bound` strength, and `docker` cannot reach its credential
        helper inside Runtime's bounded environment.

        ## Before the pipeline can succeed

        Set repository or organisation variables `IMAGE_URI`, `SERVICE_NAME`,
        `REGION` and `GCP_PROJECT`, and grant the `GCP_SA_KEY` secret.

        ## Verify a deployment

            runtime capability execute gcp/gcp-cloudrun-deployment-provenance \
              --input region=<region> --input location=<location> \
              --input repository=<registry repo> --input package=<image name>

  - provider: github
    args: [api, POST, "/repos/${repository}/actions/workflows/build-and-deploy.yml/dispatches", "ref=main"]

  - provider: github
    args: [api, GET, "/repos/${repository}/actions/runs", "per_page=5"]
```
