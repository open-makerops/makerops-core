#!/usr/bin/env bash
# Generates a one-time Outline sign-in link for an existing user.
# Requires: outline and outline_db containers to be running.
# Usage: ./recover-login.sh <email>
#
# The link uses Outline's /auth/redirect endpoint with a transfer token,
# which is validated server-side. Open it in your browser within 60 seconds.

set -euo pipefail

EMAIL="${1:?Usage: $0 <email>}"
URL="http://outline.gamingpc.home"

# Register the email auth provider for the team if not already present.
# Newer Outline versions track email sign-in via authentication_providers
# rather than an emailSigninEnabled column on teams.
docker exec -i outline_db psql -U outline -d outline -q -c "
  INSERT INTO authentication_providers (id, name, \"providerId\", enabled, \"teamId\", \"createdAt\")
  SELECT gen_random_uuid(), 'email', 'email', true, id, NOW() FROM teams LIMIT 1
  ON CONFLICT (\"providerId\", \"teamId\") DO NOTHING;"

# Write a helper script into the container. Outline's jwtSecret is encrypted
# at rest with SECRET_KEY — only the container's model layer can decrypt it.
# The script generates a transfer token via user.getTransferToken(), which
# /auth/redirect accepts, sets the session cookie, and redirects to /home.
cat << 'JSEOF' | docker exec -i outline bash -c 'cat > /tmp/outline-recover.js'
"use strict";
process.env.LOG_LEVEL = "error";
require("/opt/outline/build/server/scripts/bootstrap");
const { User } = require("/opt/outline/build/server/models");
const { sequelize } = require("/opt/outline/build/server/storage/database");

(async () => {
  const email = process.env.TARGET_EMAIL;
  const user = await User.findOne({ where: { email } });
  if (!user) {
    process.stderr.write("No user found with email: " + email + "\n");
    process.exit(1);
  }
  process.stdout.write(user.getTransferToken("app"));
  try { await sequelize.close(); } catch (_) {}
  process.exit(0);
})().catch(err => {
  process.stderr.write(err.message + "\n");
  process.exit(1);
});
JSEOF

# grep filters the dotenvx startup banner from stdout, keeping only the JWT
TOKEN=$(docker exec -e TARGET_EMAIL="${EMAIL}" outline node /tmp/outline-recover.js 2>/dev/null \
  | grep -o 'eyJ[A-Za-z0-9._-]*')
docker exec outline rm -f /tmp/outline-recover.js

echo ""
echo "Open this URL in your browser within 60 seconds:"
echo ""
echo "  ${URL}/auth/redirect?token=${TOKEN}"
echo ""
echo "The token expires in 1 minute. Re-run this script if it lapses."
echo "To avoid needing this script, configure SMTP in .env (see README.md)."
