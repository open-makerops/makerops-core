#!/bin/bash
# Runs once at first PostgreSQL startup via docker-entrypoint-initdb.d
# Creates a non-root application user and grants it the minimum required privileges.
set -e

if [ -n "${POSTGRES_NON_ROOT_USER:-}" ] && [ -n "${POSTGRES_NON_ROOT_PASSWORD:-}" ]; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE USER ${POSTGRES_NON_ROOT_USER} WITH PASSWORD '${POSTGRES_NON_ROOT_PASSWORD}';
        GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_NON_ROOT_USER};
        GRANT CREATE ON SCHEMA public TO ${POSTGRES_NON_ROOT_USER};
EOSQL
    echo "SETUP INFO: Non-root user '${POSTGRES_NON_ROOT_USER}' created."
else
    echo "SETUP INFO: POSTGRES_NON_ROOT_USER or POSTGRES_NON_ROOT_PASSWORD not set — skipping non-root user creation."
fi
