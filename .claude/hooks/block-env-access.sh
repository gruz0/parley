#!/bin/bash
# Blocks an AI assistant from accessing .env files (but NOT .env.example).
# Registered as a PreToolUse hook for Read/Edit/Write in .claude/settings.json.
# Requires jq and GNU grep (uses grep -P / PCRE) — works on Linux; grep -P is not
# available on stock macOS/BSD grep.
# Handles both Bash (tool_input.command) and Read/Edit/Write (tool_input.file_path).

INPUT=$(cat)

# Extract the relevant field depending on the tool
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Combine both into a single string to check
CHECK_STRING="${COMMAND}${FILE_PATH}"

# Allow if nothing to check
[ -z "$CHECK_STRING" ] && exit 0

deny() {
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Access to .env files is blocked. Use .env.example instead."
    }
  }'
  exit 0
}

# Block commands/paths that reference .env files but not .env.example
# Matches: .env, .env.local, .env.production, .env.development, find -name ".env*", etc.
if echo "$CHECK_STRING" | grep -qP '\.env(?!\.example)(\b|\s|$|[^a-zA-Z])'; then
  deny
fi

if echo "$CHECK_STRING" | grep -qP '\.env"'; then
  deny
fi

if echo "$CHECK_STRING" | grep -qE '"-name.*\.env'; then
  deny
fi

exit 0
