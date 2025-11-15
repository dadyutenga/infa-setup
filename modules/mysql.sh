#!/usr/bin/env bash
set -euo pipefail

check_service() {
  systemctl list-unit-files | grep -qE '^mariadb.service|^mysql.service'
}

if check_service; then
  echo "[SKIP] MySQL/MariaDB service already installed"
else
  echo "[INFO] Installing MariaDB server"
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y mariadb-server
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y install mariadb-server
  else
    echo "[ERROR] Unsupported package manager for MariaDB installation"
    return 1
  fi
fi

echo "[INFO] Enabling and starting MariaDB/MySQL"
if systemctl list-unit-files | grep -q '^mariadb.service'; then
  systemctl enable mariadb
  systemctl start mariadb
else
  systemctl enable mysql
  systemctl start mysql
fi

echo "[OK] MariaDB/MySQL ready"
