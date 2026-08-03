#!/usr/bin/env bash
# PostToolUse: this repo is a replica of engineering-runtime/capabilities.
# Control Plane catalog SSOT is engineering-runtime — edits here do NOT
# update portal./app. Remind the author to change the runtime checkout.
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

message="Capability changed in engineering-runtime-capabilities ($file). This repo is a replica — Control Plane UI catalog SSOT is engineering-runtime/capabilities/. Edit/add the capability there, then regenerate via control-plane/engineering-runtime-app-api \`make catalog\` (runtime Claude hook does this automatically). Changes here alone will not appear on portal./app."

jq -n --arg msg "$message" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $msg}}'
