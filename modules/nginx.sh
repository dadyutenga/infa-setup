#!/usr/bin/env bash
set -euo pipefail

if command -v nginx >/dev/null 2>&1; then
  echo "[SKIP] Nginx already installed"
else
  echo "[INFO] Installing Nginx"
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y nginx
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y install nginx
  else
    echo "[ERROR] Unsupported package manager for Nginx installation"
    return 1
  fi
fi

echo "[INFO] Enabling and starting Nginx"
systemctl enable nginx
systemctl start nginx

echo "[OK] Nginx ready"
