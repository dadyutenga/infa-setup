#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_os
ensure_root

if command_exists docker; then
  log INFO "Docker already installed. Ensuring service is running."
  systemctl_enable_start docker
  exit 0
fi

case "$OS_ID" in
  debian|ubuntu)
    apt_install ca-certificates curl gnupg lsb-release
    install -d -m 0755 /etc/apt/keyrings
    if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
      log INFO "Adding Docker GPG key"
      curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
    fi
    local repo_entry
    repo_entry="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS_ID} ${VERSION_CODENAME:-stable} stable"
    if [[ ! -f /etc/apt/sources.list.d/docker.list ]] || ! grep -q "download.docker.com" /etc/apt/sources.list.d/docker.list; then
      log INFO "Configuring Docker repository"
      echo "$repo_entry" > /etc/apt/sources.list.d/docker.list
      rm -f "$APT_UPDATED_FLAG"
    fi
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    ;;
  almalinux)
    dnf_install dnf-plugins-core
    log INFO "Configuring Docker CE repository"
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >>"$LOG_FILE" 2>&1 || true
    dnf_install docker-ce docker-ce-cli containerd.io docker-compose-plugin
    ;;
  *)
    log ERROR "Docker installation is not supported on this OS: ${OS_ID}"
    exit 1
    ;;
esac

systemctl_enable_start docker

if [[ -n ${SUDO_USER:-} && ${SUDO_USER} != "root" ]]; then
  if id -nG "$SUDO_USER" | tr ' ' '\n' | grep -qx docker; then
    log INFO "User ${SUDO_USER} already in docker group"
  else
    log INFO "Adding ${SUDO_USER} to docker group"
    usermod -aG docker "$SUDO_USER"
    log INFO "User ${SUDO_USER} will need to log out/in for docker group membership"
  fi
fi

log INFO "Docker installation completed"
