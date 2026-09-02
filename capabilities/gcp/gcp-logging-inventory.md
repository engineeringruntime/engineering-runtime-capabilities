# Which logs this project is writing

List the log names the project has written to. The cheapest way to find out what
is actually being logged before writing a query against it.

Deliberately narrow. `gcloud logging read` accepts a filter and returns log
entries — which is the useful operation, and also the one that can return
customer data, credentials pasted into a stack trace, and anything else a
service logged. That belongs behind an explicit human decision with an explicit
filter, not inside a capability an agent can call speculatively.

So this lists log *names* and stops. Use the names to write a `gcloud logging
read` by hand, with a filter you chose.

Requires `gcloud`, `authentication.gcp.enabled: true`, and ADC.

Run with:

```
runtime capability validate capabilities/gcp/gcp-logging-inventory.md
runtime capability execute gcp/gcp-logging-inventory
```

```runtime
version: v1

workflow:
  - binary: gcloud
    args: [logging, logs, list, "--limit=50"]
```
