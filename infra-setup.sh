#!/bin/bash

### Infra Setup Master Script
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$BASE_DIR/logs"
MODULES_DIR="$BASE_DIR/modules"
mkdir -p "$LOG_DIR"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/infra-setup-$TIMESTAMP.log"

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
declare -A SKIP_MAP=()

log_info() {
    local message="$1"
    echo -e "${GREEN}[INFO]${NC} $message"
    [[ -n "${MODULE_LOG_FILE:-}" ]] && echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $message" >> "$MODULE_LOG_FILE"
}

log_warn() {
    local message="$1"
    echo -e "${YELLOW}[WARN]${NC} $message"
    [[ -n "${MODULE_LOG_FILE:-}" ]] && echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') $message" >> "$MODULE_LOG_FILE"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message" >&2
    [[ -n "${MODULE_LOG_FILE:-}" ]] && echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $message" >> "$MODULE_LOG_FILE"
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

should_skip() {
    local module_key="${1,,}"
    if [[ ${SKIP_MAP[$module_key]+_} ]]; then
        return 0
    fi
    return 1
}

run_module() {
    local module_name="$1"
    local module_function="$2"
    CURRENT_MODULE="$module_name"
    MODULE_LOG_FILE="$LOG_DIR/${module_name}-${TIMESTAMP}.log"
    touch "$MODULE_LOG_FILE"
    chmod 600 "$MODULE_LOG_FILE"

    log_info "Starting module: $module_name"
    echo "---- Module $module_name started at $(date) ----" >> "$MODULE_LOG_FILE"

    if ! "$module_function"; then
        log_error "Module $module_name failed. Check $MODULE_LOG_FILE for details."
        exit 1
    fi

    log_info "Module $module_name completed successfully."
    echo "---- Module $module_name completed at $(date) ----" >> "$MODULE_LOG_FILE"
    echo "" >> "$MODULE_LOG_FILE"
    MODULE_LOG_FILE=""
    CURRENT_MODULE=""
}

execute_module() {
    local module_name="$1"
    local module_function="$2"
    if [[ "$module_name" == "os-detect" ]]; then
        run_module "$module_name" "$module_function"
        return
    fi
    if should_skip "$module_name"; then
        log_warn "Skipping module via SKIP_MODULES: $module_name"
        return
    fi
    run_module "$module_name" "$module_function"
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
            log_warn "Unknown package manager: $PACKAGE_MANAGER"
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
load_module "certbot.sh"
load_module "mysql.sh"
load_module "mysql-hardening.sh"
load_module "postgres.sh"
load_module "postgres-superuser.sh"
load_module "redis.sh"
load_module "rabbitmq.sh"
load_module "languages.sh"
load_module "uptime-kuma.sh"
load_module "firewall.sh"

PRIMARY_DOMAIN=""
CERTBOT_EMAIL=""
SKIP_MODULES="${SKIP_MODULES:-}"

if [[ -n "$SKIP_MODULES" ]]; then
    IFS=',' read -ra skip_items <<< "$SKIP_MODULES"
    for item in "${skip_items[@]}"; do
        item="${item,,}"
        item="${item// /}"
        if [[ -n "$item" ]]; then
            SKIP_MAP[$item]=1
        fi
    done
    log_warn "Modules requested to skip: ${!SKIP_MAP[*]}"
fi

while [[ -z "$PRIMARY_DOMAIN" ]]; do
    read -rp "Enter the primary domain (e.g., example.com): " PRIMARY_DOMAIN
    if [[ -z "$PRIMARY_DOMAIN" ]]; then
        echo -e "${YELLOW}[WARN]${NC} Domain cannot be empty."
    fi
done

read -rp "Enter email for Let's Encrypt notifications (press enter to skip): " CERTBOT_EMAIL

execute_module "os-detect" run_os_detect

log_info "Detected OS: ${OS_NAME:-unknown} (${OS_ID:-?}) ${OS_VERSION_ID:-?}"

execute_module "docker" run_docker
execute_module "nginx" run_nginx
execute_module "certbot" run_certbot
execute_module "mysql" run_mysql
execute_module "mysql-hardening" run_mysql_hardening
execute_module "postgres" run_postgres
execute_module "postgres-superuser" run_postgres_superuser
execute_module "redis" run_redis
execute_module "rabbitmq" run_rabbitmq
execute_module "languages" run_languages
execute_module "uptime-kuma" run_uptime_kuma
execute_module "firewall" run_firewall

log_info "Infrastructure setup complete! Review logs in $LOG_DIR."
