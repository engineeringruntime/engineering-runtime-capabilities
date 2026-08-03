#!/usr/bin/env bash
# PostToolUse hook (Write|Edit): when a capability markdown changes in this
# SSOT repo, regenerate the Control Plane catalog so portal./app. list the
# new capability after the next API deploy.
set -euo pipefail

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')

[ -z "$file" ] && exit 0

case "$file" in
  */capabilities/*/*.md | */capabilities/*.md)
    ;;
  *)
    exit 0
    ;;
esac

# Skip README-only index tweaks? Still regenerate — cheap and keeps counts right.
repo_root=$(git -C "$(dirname "$0")/../.." rev-parse --show-toplevel 2>/dev/null || true)
[ -z "$repo_root" ] && exit 0

runtime_root="${ENGINEERING_RUNTIME_DIR:-}"
if [ -z "$runtime_root" ]; then
  if [ -f "$repo_root/../engineering-runtime/go.mod" ]; then
    runtime_root=$(cd "$repo_root/../engineering-runtime" && pwd)
  fi
fi

api_root="${ENGINEERING_RUNTIME_APP_API_DIR:-}"
if [ -z "$api_root" ]; then
  if [ -x "$repo_root/../control-plane/engineering-runtime-app-api/scripts/generate-catalog.sh" ]; then
    api_root=$(cd "$repo_root/../control-plane/engineering-runtime-app-api" && pwd)
  elif [ -x "$repo_root/../engineering-runtime-app-api/scripts/generate-catalog.sh" ]; then
    api_root=$(cd "$repo_root/../engineering-runtime-app-api" && pwd)
  fi
fi

if [ -z "${api_root:-}" ] || [ ! -x "$api_root/scripts/generate-catalog.sh" ]; then
  message="Capability changed ($file). Control Plane app-api not found — cannot auto-regenerate catalog. Layout expected: ER/control-plane/engineering-runtime-app-api next to this repo (override ENGINEERING_RUNTIME_APP_API_DIR). Manually: cd <app-api> && make catalog, commit catalog files, redeploy API."
  jq -n --arg msg "$message" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $msg}}'
  exit 0
fi

export ENGINEERING_RUNTIME_CAPABILITIES_DIR="$repo_root"
if [ -n "${runtime_root:-}" ]; then
  export ENGINEERING_RUNTIME_DIR="$runtime_root"
fi

if out=$("$api_root/scripts/generate-catalog.sh" 2>&1); then
  message="Capability changed ($file). Regenerated Control Plane catalog in ${api_root} (${out}). Before finishing: commit catalog/catalog.json + internal/catalog/catalog.json in app-api and redeploy (or CATALOG_URL) so portal./app. show it. Also update capabilities/<provider>/README.md if you added/renamed a file."
else
  reason="Capability changed ($file). Catalog regenerate failed in ${api_root}:

${out}

Fix, then: cd ${api_root} && make catalog"
  jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
  exit 0
fi

jq -n --arg msg "$message" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $msg}}'
