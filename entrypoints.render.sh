#!/usr/bin/env bash
set -euo pipefail

# Render provides $PORT
: "${PORT:=8069}"

# Free plan is memory-constrained; use single worker
: "${WORKERS:=0}"

# Required secrets
: "${ODOO_MASTER_PASSWORD:?Set ODOO_MASTER_PASSWORD in Render}"
: "${DB_HOST:?Set DB_HOST in Render}"
: "${DB_PORT:=5432}"
: "${DB_USER:?Set DB_USER in Render}"
: "${DB_PASSWORD:?Set DB_PASSWORD in Render}"

# SSL for Render Postgres (external requires it; safe internally too)
: "${PGSSLMODE:=require}"
export PGSSLMODE

# If DB_NAME is not set, Odoo will show the DB Manager to create/select a database
EXTRA_DB_ARG=()
if [[ -n "${DB_NAME:-}" ]]; then
  EXTRA_DB_ARG=(--database="${DB_NAME}")
fi

# Optional: restrict which DBs are visible/usable (regex)
if [[ -n "${DB_FILTER:-}" ]]; then
  EXTRA_DB_ARG+=(--db-filter="${DB_FILTER}")
fi

exec odoo \
  --http-interface=0.0.0.0 \
  --http-port="${PORT}" \
  --proxy-mode=1 \
  --db_host="${DB_HOST}" \
  --db_port="${DB_PORT}" \
  --db_user="${DB_USER}" \
  --db_password="${DB_PASSWORD}" \
  "${EXTRA_DB_ARG[@]}" \
  --admin-passwd="${ODOO_MASTER_PASSWORD}" \
  --limit-time-real=1200 \
  --limit-memory-soft=134217728 \
  --limit-memory-hard=201326592 \
  --workers="${WORKERS}"
