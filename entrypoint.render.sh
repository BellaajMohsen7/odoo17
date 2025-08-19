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

# Optional tuning knobs via env
: "${MAX_CRON_THREADS:=1}"
: "${LIMIT_TIME_REAL:=1200}"

# Detect container memory limit and set Odoo memory limits accordingly
# Allow overriding via LIMIT_MEMORY_SOFT_BYTES and LIMIT_MEMORY_HARD_BYTES
read_cgroup_mem_limit() {
  local v2="/sys/fs/cgroup/memory.max"
  local v1="/sys/fs/cgroup/memory/memory.limit_in_bytes"
  local limit=""
  if [[ -f "$v2" ]]; then
    limit=$(cat "$v2")
    [[ "$limit" == "max" ]] && limit=""
  fi
  if [[ -z "$limit" && -f "$v1" ]]; then
    limit=$(cat "$v1")
  fi
  # Guard against absurd/unlimited values
  if [[ -n "$limit" && "$limit" =~ ^[0-9]+$ && "$limit" -lt 9223372036854771712 ]]; then
    echo "$limit"
  else
    echo ""
  fi
}

MEM_LIMIT_BYTES="$(read_cgroup_mem_limit)"
DEFAULT_SOFT=$((384 * 1024 * 1024))   # 384MB
DEFAULT_HARD=$((448 * 1024 * 1024))   # 448MB

if [[ -n "
${LIMIT_MEMORY_SOFT_BYTES:-}" ]]; then
  LIMIT_MEMORY_SOFT=${LIMIT_MEMORY_SOFT_BYTES}
elif [[ -n "$MEM_LIMIT_BYTES" ]]; then
  LIMIT_MEMORY_SOFT=$(( MEM_LIMIT_BYTES * 75 / 100 ))
else
  LIMIT_MEMORY_SOFT=$DEFAULT_SOFT
fi

if [[ -n "
${LIMIT_MEMORY_HARD_BYTES:-}" ]]; then
  LIMIT_MEMORY_HARD=${LIMIT_MEMORY_HARD_BYTES}
elif [[ -n "$MEM_LIMIT_BYTES" ]]; then
  LIMIT_MEMORY_HARD=$(( MEM_LIMIT_BYTES * 90 / 100 ))
else
  LIMIT_MEMORY_HARD=$DEFAULT_HARD
fi

# Ensure hard > soft by at least 8MB
if (( LIMIT_MEMORY_HARD <= LIMIT_MEMORY_SOFT )); then
  LIMIT_MEMORY_HARD=$(( LIMIT_MEMORY_SOFT + 8 * 1024 * 1024 ))
fi

SOFT_MB=$(( LIMIT_MEMORY_SOFT / 1024 / 1024 ))
HARD_MB=$(( LIMIT_MEMORY_HARD / 1024 / 1024 ))
echo "Configuring Odoo memory limits: soft=${SOFT_MB}MB hard=${HARD_MB}MB (container limit: ${MEM_LIMIT_BYTES:-unknown} bytes)"

# Build a minimal Odoo config file to set admin_passwd and DB params
CONFIG_FILE="/tmp/odoo.conf"
{
  echo "[options]"
  echo "admin_passwd = ${ODOO_MASTER_PASSWORD}"
  echo "db_host = ${DB_HOST}"
  echo "db_port = ${DB_PORT}"
  echo "db_user = ${DB_USER}"
  echo "db_password = ${DB_PASSWORD}"
} > "${CONFIG_FILE}"

# Optional database name and filter
if [[ -n "${DB_NAME:-}" ]]; then
  echo "db_name = ${DB_NAME}" >> "${CONFIG_FILE}"
  # If no explicit DB_FILTER, default to the specific DB name to save resources
  if [[ -z "${DB_FILTER:-}" ]]; then
    echo "dbfilter = ^${DB_NAME}$" >> "${CONFIG_FILE}"
  fi
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
  --limit-time-real="${LIMIT_TIME_REAL}" \
  --limit-memory-soft="${LIMIT_MEMORY_SOFT}" \
  --limit-memory-hard="${LIMIT_MEMORY_HARD}" \
  --max-cron-threads="${MAX_CRON_THREADS}" \
  --workers="${WORKERS}".