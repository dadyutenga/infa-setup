#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/infra-setup.log"
MODULE_DIR="$(cd "$(dirname "$0")" && pwd)/modules"
COMMON_FILE="${MODULE_DIR}/common.sh"

if [[ ! -f "$COMMON_FILE" ]]; then
  echo "Missing common module: $COMMON_FILE" >&2
  exit 1
fi

source "$COMMON_FILE"

usage() {
  cat <<USAGE
Usage: $0 [--domain example.com] [--subdomains "api,app"] [--skip module1,module2]

Options:
  --domain        Primary domain name for nginx/certbot provisioning.
  --subdomains    Comma-separated list of additional subdomains. Defaults to
                  api,app,admin,billing,files.
  --skip          Comma-separated list of modules to skip (e.g. docker,certbot).
  -h, --help      Show this message.
USAGE
}

PRIMARY_DOMAIN=""
SUBDOMAIN_LIST="api,app,admin,billing,files"
SKIP_MODULES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      PRIMARY_DOMAIN="$2"
      shift 2
      ;;
    --subdomains)
      SUBDOMAIN_LIST="$2"
      shift 2
      ;;
    --skip)
      IFS=',' read -r -a SKIP_MODULES <<<"$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

ensure_root

log INFO "Starting infrastructure setup"

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  OS_ID="$ID"
  OS_VERSION_ID="$VERSION_ID"
  OS_NAME="$PRETTY_NAME"
  VERSION_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
else
  log ERROR "Unable to detect operating system"
  exit 1
fi

export OS_ID OS_VERSION_ID OS_NAME VERSION_CODENAME LOG_FILE PRIMARY_DOMAIN SUBDOMAIN_LIST

log INFO "Detected OS: ${OS_NAME} (${OS_ID} ${OS_VERSION_ID})"

MODULE_SEQUENCE=(docker nginx certbot mysql mysql-hardening postgres redis rabbitmq languages uptime-kuma firewall)

should_skip() {
  local module="$1"
  for skip in "${SKIP_MODULES[@]}"; do
    if [[ "$module" == "$skip" ]]; then
      return 0
    fi
  done
  return 1
}

for module in "${MODULE_SEQUENCE[@]}"; do
  if should_skip "$module"; then
    log INFO "Skipping module: $module"
    continue
  fi
  local_script="${MODULE_DIR}/${module}.sh"
  if [[ ! -x "$local_script" ]]; then
    log ERROR "Module script not found or not executable: ${local_script}"
    exit 1
  fi
  log INFO "Running module: $module"
  bash "$local_script"
  log INFO "Module completed: $module"
  sleep 1
done

log INFO "Infrastructure setup completed successfully"
