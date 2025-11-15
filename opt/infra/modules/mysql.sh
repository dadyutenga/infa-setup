#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_os
ensure_root

case "$OS_ID" in
  debian|ubuntu)
    if command_exists mysql; then
      log INFO "MySQL already installed"
    else
      apt_install mysql-server
    fi
    MYSQL_SERVICE="mysql"
    ;;
  almalinux)
    if systemctl list-unit-files | grep -q '^mariadb\.service'; then
      log INFO "MariaDB already present"
    else
      dnf_install mariadb-server
    fi
    MYSQL_SERVICE="mariadb"
    ;;
  *)
    log ERROR "MySQL installation unsupported on this OS: ${OS_ID}"
    exit 1
    ;;
esac

systemctl_enable_start "$MYSQL_SERVICE"

log INFO "MySQL/MariaDB installation complete"
