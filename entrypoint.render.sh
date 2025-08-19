#!/usr/bin/env bash
set -euo pipefail

# Render provides $PORT; default to 8069 for local use
: "${PORT:=8069}"

# Free/low-memory plans: single-threaded
: "${WORKERS:=0}"

# Required database and master password environment variables
: "${ODOO_MASTER_PASSWORD:?Set ODOO_MASTER_PASSWORD in the environment}"
: "${DB_HOST:?Set DB_HOST in the environment}"
: "${DB_PORT:=5432}"
: "${DB_USER:?Set DB_USER in the environment}"
: "${DB_PASSWORD:?Set DB_PASSWORD in the environment}"

# Enforce SSL for Postgres by default (Render Postgres requires it)
: "${PGSSLMODE:=require}"
export PGSSLMODE

# Build a minimal Odoo config file to set admin_passwd (not available as a CLI flag in Odoo 17)
CONFIG_FILE="/tmp/odoo.conf"
{
  echo "[options]"
  echo "admin_passwd = ${ODOO_MASTER_PASSWORD}"
  echo "db_host = ${DB_HOST}"
  echo "db_port = ${DB_PORT}"
  echo "db_user = ${DB_USER}"
  echo "db_password = ${DB_PASSWORD}"
} > "${CONFIG_FILE}"

# Optional database name and filter (written to config for consistency)
if [[ -n "${DB_NAME:-}" ]]; then
  echo "db_name = ${DB_NAME}" >> "${CONFIG_FILE}"
fi
if [[ -n "${DB_FILTER:-}" ]]; then
  echo "dbfilter = ${DB_FILTER}" >> "${CONFIG_FILE}"
fi

# For visibility in logs (without secrets)
echo "Using Odoo config at ${CONFIG_FILE}"

exec odoo \
  -c "${CONFIG_FILE}" \
  --http-interface=0.0.0.0 \
  --http-port="${PORT}" \
  --proxy-mode \
  --limit-time-real=1200 \
  --limit-memory-soft=134217728 \
  --limit-memory-hard=201326592 \
  --workers="${WORKERS}"