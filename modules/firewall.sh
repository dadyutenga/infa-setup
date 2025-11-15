#!/usr/bin/env bash
set -euo pipefail

: "${OS_FAMILY:?OS_FAMILY is not set. Run os-detect first.}"

ALLOWED_PORTS=(22 80 443 6379 3001)

configure_ufw() {
  if ! command -v ufw >/dev/null 2>&1; then
    echo "[INFO] Installing UFW"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ufw
  fi

  for port in "${ALLOWED_PORTS[@]}"; do
    ufw allow "${port}" || true
  done

  if ufw status | grep -q "Status: active"; then
    echo "[SKIP] UFW already enabled"
  else
    echo "[INFO] Enabling UFW"
    yes | ufw enable
  fi
}

configure_firewalld() {
  if ! command -v firewall-cmd >/dev/null 2>&1; then
    echo "[INFO] Installing firewalld"
    dnf -y install firewalld
  fi

  systemctl enable firewalld
  systemctl start firewalld

  for port in "${ALLOWED_PORTS[@]}"; do
    firewall-cmd --permanent --add-port="${port}/tcp"
  done
  firewall-cmd --reload
}

case "${OS_FAMILY}" in
  debian)
    configure_ufw
    ;;
  almalinux)
    configure_firewalld
    ;;
  *)
    echo "[ERROR] Unsupported OS family for firewall configuration"
    return 1
    ;;
esac

echo "[OK] Firewall configured"
