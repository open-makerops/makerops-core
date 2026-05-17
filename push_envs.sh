#!/bin/bash
# Encrypts each service's .env file with age (using ~/.ssh/id_ed25519) and
# pushes the resulting .age files to the configured GitHub Gist.
#
# Gist file naming: <concern>.<service>.env.age  (e.g. core.bookstack.env.age)
# Config:           .envs-gist.conf    (stores GIST_URL)
# Local gist clone: .envs-gist/
#
# See README.md → "Environment File Management" for first-time setup instructions.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONF_FILE=".envs-gist.conf"
GIST_DIR=".envs-gist"
AGE_KEY="$HOME/.ssh/id_ed25519"
AGE_PUB="$HOME/.ssh/id_ed25519.pub"

# ── Preflight checks ───────────────────────────────────────────────────────────
if ! command -v age &>/dev/null; then
    echo "ERROR: 'age' is not installed."
    echo "       Install: sudo apt install age   (Debian/Ubuntu)"
    echo "                brew install age        (macOS)"
    exit 1
fi

if [[ ! -f "$AGE_PUB" ]]; then
    echo "ERROR: SSH public key not found at $AGE_PUB"
    echo "       See README.md → 'Environment Sync' for setup instructions."
    exit 1
fi

if [[ ! -f "$AGE_KEY" ]]; then
    echo "ERROR: SSH private key not found at $AGE_KEY"
    echo "       See README.md → 'Environment Sync' for setup instructions."
    exit 1
fi

# ── Load or create config ──────────────────────────────────────────────────────
if [[ ! -f "$CONF_FILE" ]]; then
    echo "No $CONF_FILE found."
    read -r -p "Enter the gist git URL (e.g. git@gist.github.com:<hash>.git): " GIST_URL
    if [[ -z "$GIST_URL" ]]; then
        echo "ERROR: No URL provided. Aborting."
        exit 1
    fi
    echo "GIST_URL=$GIST_URL" > "$CONF_FILE"
    echo "Saved to $CONF_FILE"
else
    GIST_URL=$(grep "^GIST_URL=" "$CONF_FILE" | cut -d= -f2-)
    if [[ -z "$GIST_URL" ]]; then
        echo "ERROR: GIST_URL is empty in $CONF_FILE. Aborting."
        exit 1
    fi
fi

# ── Clone or sync gist ─────────────────────────────────────────────────────────
if [[ ! -d "$GIST_DIR" ]]; then
    echo "Cloning gist into $GIST_DIR/ ..."
    git clone "$GIST_URL" "$GIST_DIR"
else
    echo "Pulling latest from gist..."
    git -C "$GIST_DIR" pull --quiet
fi

# ── Encrypt and stage each service's .env ─────────────────────────────────────
PUSHED=0
for concern in core remote_access ai; do
    [[ ! -d "$concern" ]] && continue
    for svc_path in "$concern"/*/; do
        [[ ! -d "$svc_path" ]] && continue
        [[ ! -f "${svc_path}.env" ]] && continue
        svc="$(basename "${svc_path%/}")"
        out="$GIST_DIR/$concern.$svc.env.age"
        echo "  Encrypting $concern/$svc/.env → $(basename "$out")"
        age --recipient "$(cat "$AGE_PUB")" --output "$out" "${svc_path}.env"
        PUSHED=$((PUSHED + 1))
    done
done

if [[ $PUSHED -eq 0 ]]; then
    echo ""
    echo "No .env files found in any service directory. Nothing to push."
    exit 0
fi

# ── Commit and push ────────────────────────────────────────────────────────────
git -C "$GIST_DIR" add -A

if git -C "$GIST_DIR" diff --cached --quiet; then
    echo ""
    echo "Gist is already up to date — no changes to push."
else
    TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    git -C "$GIST_DIR" commit -m "update envs $TIMESTAMP"
    git -C "$GIST_DIR" push
    echo ""
    echo "Pushed $PUSHED service .env file(s) to gist."
fi
