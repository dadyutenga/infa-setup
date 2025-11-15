#!/bin/bash

### Infra Setup Master Script
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$BASE_DIR/logs"
MODULES_DIR="$BASE_DIR/modules"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/infra-install.log"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

# Redirect stdout/stderr to log while preserving console output
exec > >(tee -a "$LOG_FILE") 2>&1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MODULE_LOG_FILE=""
CURRENT_MODULE=""

log_status() {
    local level="$1"
    shift
    local message="$*"
    local color="$NC"
    case "$level" in
        INFO) color="$BLUE" ;;
        OK) color="$GREEN" ;;
        SKIP) color="$YELLOW" ;;
        ERROR) color="$RED" ;;
    esac
    echo -e "${color}[${level}]${NC} $message"
    if [[ -n "${MODULE_LOG_FILE:-}" ]]; then
        echo "[$level] $(date '+%Y-%m-%d %H:%M:%S') $message" >> "$MODULE_LOG_FILE"
    fi
}

log_info() {
    log_status "INFO" "$@"
}

log_ok() {
    log_status "OK" "$@"
}

log_skip() {
    log_status "SKIP" "$@"
}

log_error() {
    log_status "ERROR" "$@"
}

run_cmd() {
    local description="$1"
    shift
    log_info "$description"
    local status
    if [[ -n "${MODULE_LOG_FILE:-}" ]]; then
        "$@" 2>&1 | tee -a "$MODULE_LOG_FILE"
        status=${PIPESTATUS[0]}
    else
        "$@" 2>&1
        status=$?
    fi
    return $status
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[FATAL]${NC} This script must be run with sudo or as root." >&2
        exit 1
    fi
}

load_module() {
    local module_file="$1"
    if [[ ! -f "$MODULES_DIR/$module_file" ]]; then
        echo -e "${RED}[FATAL]${NC} Missing module: $module_file" >&2
        exit 1
    fi
    # shellcheck disable=SC1090
    source "$MODULES_DIR/$module_file"
}

run_module() {
    local module_name="$1"
    local module_function="$2"
    CURRENT_MODULE="$module_name"
    MODULE_LOG_FILE="$LOG_DIR/${module_name}.log"
    : > "$MODULE_LOG_FILE"
    chmod 600 "$MODULE_LOG_FILE"

    log_info "Starting module: $module_name"
    echo "---- Module $module_name started at $(date) ----" >> "$MODULE_LOG_FILE"

    if ! "$module_function"; then
        log_error "Module $module_name failed. Check $MODULE_LOG_FILE for details."
        exit 1
    fi

    log_ok "Module $module_name completed successfully."
    echo "---- Module $module_name completed at $(date) ----" >> "$MODULE_LOG_FILE"
    echo "" >> "$MODULE_LOG_FILE"
    MODULE_LOG_FILE=""
    CURRENT_MODULE=""
}

update_package_index() {
    case "$PACKAGE_MANAGER" in
        apt)
            run_cmd "Updating apt package index" apt-get update
            ;;
        dnf)
            run_cmd "Refreshing dnf metadata" dnf makecache --refresh -y
            ;;
        *)
            log_error "Unknown package manager: $PACKAGE_MANAGER"
            return 1
            ;;
    esac
}

install_packages() {
    local packages=("$@")
    case "$PACKAGE_MANAGER" in
        apt)
            run_cmd "Installing packages: ${packages[*]}" apt-get install -y "${packages[@]}"
            ;;
        dnf)
            run_cmd "Installing packages: ${packages[*]}" dnf install -y "${packages[@]}"
            ;;
        *)
            log_error "Unsupported package manager: $PACKAGE_MANAGER"
            return 1
            ;;
    esac
}

require_root

load_module "os-detect.sh"
load_module "docker.sh"
load_module "nginx.sh"
load_module "mysql.sh"
load_module "postgres.sh"
load_module "redis.sh"
load_module "rabbitmq.sh"
load_module "languages.sh"
load_module "uptime-kuma.sh"
load_module "firewall.sh"

run_module "os-detect" run_os_detect

log_info "Detected OS: ${OS_NAME:-unknown} (${OS_ID:-?}) ${OS_VERSION_ID:-?}"

run_module "docker" run_docker
run_module "nginx" run_nginx
run_module "mysql" run_mysql
run_module "postgres" run_postgres
run_module "redis" run_redis
run_module "rabbitmq" run_rabbitmq
run_module "languages" run_languages
run_module "uptime-kuma" run_uptime_kuma
run_module "firewall" run_firewall

log_ok "Infrastructure setup complete! Review logs in $LOG_DIR."
