#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_os
ensure_root

PORTS=(22 80 443 6379 5672 15672 3001)

case "$OS_ID" in
  debian|ubuntu)
    apt_install ufw
    if ! ufw status | grep -q "Status: active"; then
      log INFO "Enabling UFW firewall"
      ufw --force enable >>"$LOG_FILE" 2>&1
    fi
    for port in "${PORTS[@]}"; do
      if ! ufw status | grep -q "${port}/tcp"; then
        log INFO "Allowing TCP port ${port} via UFW"
        ufw allow "$port"/tcp >>"$LOG_FILE" 2>&1
      fi
    done
    ;;
  almalinux)
    dnf_install firewalld
    systemctl_enable_start firewalld
    for port in "${PORTS[@]}"; do
      if ! firewall-cmd --permanent --query-port="${port}/tcp" >/dev/null 2>&1; then
        log INFO "Allowing TCP port ${port} via firewalld"
        firewall-cmd --permanent --add-port="${port}/tcp" >>"$LOG_FILE" 2>&1
      fi
    done
    firewall-cmd --reload >>"$LOG_FILE" 2>&1
    ;;
  *)
    log WARN "No firewall automation for ${OS_ID}"
    ;;
esac

log INFO "Firewall configuration applied"
