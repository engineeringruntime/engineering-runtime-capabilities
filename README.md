# engineering-runtime-capabilities

Markdown Engineering Capabilities (```runtime blocks) executed by the
`engineering-runtime` binary. See [`CLAUDE.md`](./CLAUDE.md) for authoring rules.

## Control Plane catalog

The Control Plane UI (portal Live + app) lists capabilities from a **generated
catalog**, not by calling GitHub or running the runtime on Cloud Run.

After you add/rename a capability here, regenerate the catalog in
`engineering-runtime-app-api`:

```bash
cd ../control-plane/engineering-runtime-app-api   # sibling layout under ER/
make catalog
# commit catalog/catalog.json + internal/catalog/catalog.json, redeploy API
```

Claude Code: `.claude/hooks/control-plane-catalog-reminder.sh` runs that
regenerate automatically on `capabilities/**/*.md` edits when the sibling
app-api checkout is present.
