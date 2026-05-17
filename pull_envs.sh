#!/bin/bash
# Pulls encrypted .env files from the configured GitHub Gist, decrypts them
# with age (using ~/.ssh/id_ed25519), and writes each to the matching service
# directory as .env.
#
# Gist file naming: <concern>.<service>.env.age  (e.g. core.bookstack.env.age)
# Config:           .envs-gist.conf    (stores GIST_URL)
# Local gist clone: .envs-gist/
#
# Existing local .env files are overwritten silently.
# Gist entries with no matching local service directory are skipped with a warning.
#
# See README.md → "Environment File Management" for first-time setup instructions.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONF_FILE=".envs-gist.conf"
GIST_DIR=".envs-gist"
AGE_KEY="$HOME/.ssh/id_ed25519"

# ── Preflight checks ───────────────────────────────────────────────────────────
if ! command -v age &>/dev/null; then
    echo "ERROR: 'age' is not installed."
    echo "       Install: sudo apt install age   (Debian/Ubuntu)"
    echo "                brew install age        (macOS)"
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

# ── Decrypt each .env.age into the matching service directory ──────────────────
PULLED=0
SKIPPED=0
shopt -s nullglob
for age_file in "$GIST_DIR"/*.env.age; do
    filename="$(basename "$age_file")"
    # filename format: <concern>.<service>.env.age
    rest="${filename%.env.age}"
    concern="${rest%%.*}"
    svc="${rest#*.}"

    if [[ ! -d "$concern/$svc" ]]; then
        echo "  SKIP: no local directory for '$concern/$svc' (file: $filename)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    echo "  Decrypting $filename → $concern/$svc/.env"
    age --decrypt --identity "$AGE_KEY" --output "$concern/$svc/.env" "$age_file"
    PULLED=$((PULLED + 1))
done
shopt -u nullglob

echo ""
if [[ $PULLED -eq 0 && $SKIPPED -eq 0 ]]; then
    echo "No .env.age files found in gist. Nothing pulled."
else
    echo "Pulled $PULLED service .env file(s)."
    [[ $SKIPPED -gt 0 ]] && echo "Skipped $SKIPPED file(s) with no matching local service directory."
fi
