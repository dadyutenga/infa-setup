#!/usr/bin/env bash
set -euo pipefail

if command -v redis-server >/dev/null 2>&1; then
  echo "[SKIP] Redis already installed"
else
  echo "[INFO] Installing Redis"
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y redis-server
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y install redis
  else
    echo "[ERROR] Unsupported package manager for Redis installation"
    return 1
  fi
fi

echo "[INFO] Enabling and starting Redis"
if systemctl list-unit-files | grep -q '^redis-server.service'; then
  systemctl enable redis-server
  systemctl start redis-server
else
  systemctl enable redis
  systemctl start redis
fi

echo "[OK] Redis ready"
