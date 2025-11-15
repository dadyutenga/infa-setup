#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_os
ensure_root

case "$OS_ID" in
  debian|ubuntu)
    apt_install redis-server
    CONF_FILE="/etc/redis/redis.conf"
    SERVICE="redis-server"
    ;;
  almalinux)
    dnf_install redis
    CONF_FILE="/etc/redis/redis.conf"
    SERVICE="redis"
    ;;
  *)
    log ERROR "Redis installation unsupported on ${OS_ID}"
    exit 1
    ;;
esac

backup_file "$CONF_FILE"

MAXMEMORY="${REDIS_MAXMEMORY:-256mb}"

sed -i "s/^#\?supervised .*/supervised systemd/" "$CONF_FILE"
sed -i "s/^#\?maxmemory .*/maxmemory ${MAXMEMORY}/" "$CONF_FILE" || echo "maxmemory ${MAXMEMORY}" >>"$CONF_FILE"
sed -i "s/^#\?maxmemory-policy .*/maxmemory-policy allkeys-lru/" "$CONF_FILE" || echo "maxmemory-policy allkeys-lru" >>"$CONF_FILE"
sed -i "s/^#\?bind .*/bind 127.0.0.1 ::1/" "$CONF_FILE"
sed -i "s/^#\?protected-mode .*/protected-mode yes/" "$CONF_FILE"

if ! grep -q '^rename-command CONFIG ""' "$CONF_FILE"; then
  cat <<'CFG' >>"$CONF_FILE"
rename-command CONFIG ""
rename-command FLUSHALL ""
rename-command FLUSHDB ""
CFG
fi

systemctl_enable_start "$SERVICE"

log INFO "Redis configured with maxmemory=${MAXMEMORY}"
