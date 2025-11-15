#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${LOG_FILE:-/var/log/infra-setup.log}"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 640 "$LOG_FILE" || true

log() {
  local level="$1"; shift
  local message="$*"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE" >/dev/null
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_root() {
  if [[ ${EUID} -ne 0 ]]; then
    log ERROR "This module must be run as root."
    exit 1
  fi
}

require_os() {
  if [[ -z "${OS_ID:-}" || -z "${OS_VERSION_ID:-}" ]]; then
    log ERROR "OS_ID/OS_VERSION_ID not exported from infra-setup.sh"
    exit 1
  fi
}

APT_UPDATED_FLAG="/tmp/.infra_apt_updated"
DNF_UPDATED_FLAG="/tmp/.infra_dnf_updated"

apt_install() {
  local packages=("$@")
  if [[ ! -f "$APT_UPDATED_FLAG" ]]; then
    log INFO "Updating apt package lists"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >>"$LOG_FILE" 2>&1
    touch "$APT_UPDATED_FLAG"
  fi
  log INFO "Installing packages via apt: ${packages[*]}"
  apt-get install -y "${packages[@]}" >>"$LOG_FILE" 2>&1
}

dnf_install() {
  local packages=("$@")
  if [[ ! -f "$DNF_UPDATED_FLAG" ]]; then
    log INFO "Refreshing dnf metadata"
    dnf -y makecache >>"$LOG_FILE" 2>&1
    touch "$DNF_UPDATED_FLAG"
  fi
  log INFO "Installing packages via dnf: ${packages[*]}"
  dnf install -y "${packages[@]}" >>"$LOG_FILE" 2>&1
}

systemctl_enable_start() {
  local service="$1"
  if systemctl list-unit-files | grep -q "^${service}\.service"; then
    log INFO "Enabling and starting service: ${service}"
    systemctl enable --now "$service" >>"$LOG_FILE" 2>&1
  else
    log WARN "Service ${service} does not exist, skipping enable/start"
  fi
}

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local backup="${file}.bak.$(date '+%Y%m%d%H%M%S')"
    cp "$file" "$backup"
    log INFO "Backup created: ${backup}"
  fi
}

random_password() {
  tr -dc 'A-Za-z0-9!@#%^&*()_+-=' </dev/urandom | head -c 24
}

