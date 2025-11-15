#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_os
ensure_root

TARGET_DIR="/opt/infra"
TARGET_SCRIPT="${TARGET_DIR}/mysql-hardening.sh"
SOURCE_SCRIPT="${ROOT_DIR}/mysql-hardening.sh"
CREDENTIAL_FILE="${TARGET_DIR}/mysql-credentials.env"

mkdir -p "$TARGET_DIR"
install -m 0700 "$SOURCE_SCRIPT" "$TARGET_SCRIPT"
log INFO "Installed MySQL hardening script to ${TARGET_SCRIPT}"

if [[ -f "$CREDENTIAL_FILE" ]] && grep -q 'MYSQL_HARDENED=1' "$CREDENTIAL_FILE"; then
  log INFO "MySQL already hardened according to ${CREDENTIAL_FILE}"
  exit 0
fi

APP_DB="${MYSQL_APP_DB:-app_db}"
APP_USER="${MYSQL_APP_USER:-app_user}"
EXTRA_ARGS=("--app-db" "$APP_DB" "--app-user" "$APP_USER")

if [[ -n ${MYSQL_ROOT_PASSWORD:-} ]]; then
  EXTRA_ARGS+=("--root-password" "${MYSQL_ROOT_PASSWORD}")
fi
if [[ -n ${MYSQL_APP_PASSWORD:-} ]]; then
  EXTRA_ARGS+=("--app-password" "${MYSQL_APP_PASSWORD}")
fi

log INFO "Running MySQL hardening script"
bash "$TARGET_SCRIPT" "${EXTRA_ARGS[@]}"

log INFO "MySQL hardening completed"
