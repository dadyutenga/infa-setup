#!/usr/bin/env bash
set -euo pipefail

if command -v psql >/dev/null 2>&1; then
  echo "[SKIP] PostgreSQL already installed"
else
  echo "[INFO] Installing PostgreSQL"
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y postgresql postgresql-contrib
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y install postgresql-server postgresql-contrib
    if [ ! -d /var/lib/pgsql/data/base ]; then
      /usr/bin/postgresql-setup --initdb --unit postgresql
    fi
  else
    echo "[ERROR] Unsupported package manager for PostgreSQL installation"
    return 1
  fi
fi

echo "[INFO] Enabling and starting PostgreSQL"
systemctl enable postgresql
systemctl start postgresql

echo "[OK] PostgreSQL ready"
