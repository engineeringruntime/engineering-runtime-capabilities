# Claude Code hooks — engineering-runtime-capabilities

## `control-plane-catalog-reminder.sh`

Triggers on: `capabilities/**/*.md` (PostToolUse Write|Edit).

Regenerates `engineering-runtime-app-api`'s `catalog.json` from this repo +
sibling `engineering-runtime` providers so portal Live / App UI pick up new
capabilities after the next API deploy. The hosted API never clones this
repo live.

Requires sibling layout (or env overrides):

| Env | Default |
|---|---|
| `ENGINEERING_RUNTIME_APP_API_DIR` | `../control-plane/engineering-runtime-app-api` |
| `ENGINEERING_RUNTIME_DIR` | `../engineering-runtime` |
