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

# Optional database name and filter
EXTRA_DB_ARGS=()
if [[ -n "${DB_NAME:-}" ]]; then
  EXTRA_DB_ARGS+=(--database="${DB_NAME}")
fi
if [[ -n "${DB_FILTER:-}" ]]; then
  EXTRA_DB_ARGS+=(--db-filter="${DB_FILTER}")
fi

exec odoo \
  --http-interface=0.0.0.0 \
  --http-port="${PORT}" \
  --proxy-mode=1 \
  --db_host="${DB_HOST}" \
  --db_port="${DB_PORT}" \
  --db_user="${DB_USER}" \
  --db_password="${DB_PASSWORD}" \
  "${EXTRA_DB_ARGS[@]}" \
  --admin-passwd="${ODOO_MASTER_PASSWORD}" \
  --limit-time-real=1200 \
  --limit-memory-soft=134217728 \
  --limit-memory-hard=201326592 \
  --workers="${WORKERS}"