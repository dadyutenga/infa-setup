#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_os
ensure_root

case "$OS_ID" in
  debian|ubuntu)
    apt_install postgresql postgresql-contrib
    PG_SERVICE="postgresql"
    ;;
  almalinux)
    dnf_install postgresql-server postgresql-contrib
    PG_SERVICE="postgresql"
    if [[ ! -f /var/lib/pgsql/data/PG_VERSION ]]; then
      log INFO "Initializing PostgreSQL database"
      /usr/bin/postgresql-setup --initdb >>"$LOG_FILE" 2>&1
    fi
    ;;
  *)
    log ERROR "PostgreSQL installation unsupported on ${OS_ID}"
    exit 1
    ;;
esac

systemctl_enable_start "$PG_SERVICE"

TARGET_DIR="/opt/infra"
TARGET_SCRIPT="${TARGET_DIR}/postgres-setup.sh"
SOURCE_SCRIPT="${ROOT_DIR}/postgres-setup.sh"

mkdir -p "$TARGET_DIR"
install -m 0700 "$SOURCE_SCRIPT" "$TARGET_SCRIPT"
log INFO "Installed PostgreSQL setup script to ${TARGET_SCRIPT}"

ENV_FILE="${TARGET_DIR}/postgres-superuser.env"

if [[ ! -f "$ENV_FILE" ]]; then
  log INFO "Running PostgreSQL setup script for initial provisioning"
  bash "$TARGET_SCRIPT"
else
  log INFO "PostgreSQL already configured (${ENV_FILE} present)"
fi

log INFO "PostgreSQL installation complete"
