#!/bin/bash
# Retrieves the most recent magic link login URL from trigger.dev webapp logs.
# Run after submitting your email on the login page at http://localhost:3040.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

url=$(docker logs trigger_webapp 2>&1 \
  | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' \
  | tr -d '\r' \
  | grep -oE 'https?://[^ "]+magic\?token=[^ "]+' \
  | tail -1)

if [[ -z "$url" ]]; then
    echo "No magic link found in logs." >&2
    echo "To generate one:" >&2
    echo "  1. Open http://localhost:3040 in your browser" >&2
    echo "  2. Enter your email and click 'Send magic link'" >&2
    echo "  3. Run this script again immediately after" >&2
    exit 1
fi

token=$(echo "$url" | sed 's/.*token=//')
if [[ ${#token} -lt 50 ]]; then
    echo "Warning: token appears short (${#token} chars) — it may be truncated or incorrect." >&2
fi

echo "Open a browser tab and paste this URL into the address bar:"
echo "$url"
