# Firewall rules and reserved addresses

The firewall rules in force and the external addresses reserved. Read together
because they are the two halves of "what can reach this project from outside?"

A firewall rule with source range `0.0.0.0/0` on anything other than a load
balancer's health check is the finding this capability exists to surface. It
lists rather than judges — the grammar has no assertions — but the rule is
visible in one line rather than one console page per rule.

Reserved addresses matter for the opposite reason: an address reserved and no
longer attached is billed monthly and forgotten, and it appears here with an
empty `users` column.

Read-only. Changing a rule resolves a named target and is refused at
`selector_bound` strength.

Requires `gcloud`, `authentication.gcp.enabled: true`, ADC, and the Compute
Engine API enabled.

Run with:

```
runtime capability validate capabilities/gcp/gcp-firewall-and-addresses.md
runtime capability execute gcp/gcp-firewall-and-addresses
```

```runtime
version: v1

workflow:
  - binary: gcloud
    args: [compute, firewall-rules, list, "--limit=50"]

  - binary: gcloud
    args: [compute, addresses, list, "--limit=50"]
```
