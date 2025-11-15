#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_os
ensure_root

apt_prereqs() {
  apt_install git
}

dnf_prereqs() {
  dnf_install git
}

case "$OS_ID" in
  debian|ubuntu)
    apt_prereqs
    ;;
  almalinux)
    dnf_prereqs
    ;;
  *)
    log ERROR "Unsupported OS for Uptime Kuma"
    exit 1
    ;;
esac

if ! command_exists node; then
  log ERROR "Node.js is required for Uptime Kuma. Run languages module first."
  exit 1
fi

if ! id uptime-kuma >/dev/null 2>&1; then
  log INFO "Creating uptime-kuma system user"
  useradd --system --home-dir /opt/uptime-kuma --shell /usr/sbin/nologin uptime-kuma
fi

REPO_DIR="/opt/uptime-kuma"
if [[ ! -d "$REPO_DIR" ]]; then
  log INFO "Cloning Uptime Kuma"
  git clone https://github.com/louislam/uptime-kuma.git "$REPO_DIR" >>"$LOG_FILE" 2>&1
else
  log INFO "Updating Uptime Kuma"
  git -C "$REPO_DIR" pull >>"$LOG_FILE" 2>&1 || true
fi

cd "$REPO_DIR"
log INFO "Installing Uptime Kuma dependencies"
npm install --production >>"$LOG_FILE" 2>&1

chown -R uptime-kuma:uptime-kuma "$REPO_DIR"

SERVICE_FILE="/etc/systemd/system/uptime-kuma.service"
cat >"$SERVICE_FILE" <<SERVICE
[Unit]
Description=Uptime Kuma self-hosted monitoring tool
After=network.target

[Service]
Type=simple
User=uptime-kuma
WorkingDirectory=${REPO_DIR}
Environment=NODE_ENV=production
ExecStart=/usr/bin/env node server/server.js
Restart=always
RestartSec=5
StandardOutput=append:/var/log/uptime-kuma.log
StandardError=append:/var/log/uptime-kuma.log

[Install]
WantedBy=multi-user.target
SERVICE

log INFO "Enabling Uptime Kuma service"
mkdir -p /var/log
: > /var/log/uptime-kuma.log
chown uptime-kuma:uptime-kuma /var/log/uptime-kuma.log

systemctl daemon-reload
systemctl enable --now uptime-kuma >>"$LOG_FILE" 2>&1

log INFO "Uptime Kuma installation complete"
