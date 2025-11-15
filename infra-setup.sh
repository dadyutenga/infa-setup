#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="logs"
INFRA_LOG="${LOG_DIR}/infra.log"
MODULE_LOG_DIR="${LOG_DIR}/modules"

COLOR_INFO="\033[1;34m"
COLOR_OK="\033[1;32m"
COLOR_SKIP="\033[1;33m"
COLOR_ERROR="\033[1;31m"
COLOR_RESET="\033[0m"

mkdir -p "${MODULE_LOG_DIR}"

touch "${INFRA_LOG}"

if [ ! -w "${LOG_DIR}" ]; then
  echo -e "${COLOR_ERROR}[ERROR] Unable to write to logs directory${COLOR_RESET}" >&2
  exit 1
fi

log_message() {
  local level="$1"
  local message="$2"
  local color="$3"
  echo -e "${color}[${level}] ${message}${COLOR_RESET}"
}

run_module() {
  local module_name="$1"
  local module_script="modules/${module_name}.sh"
  local module_log="${MODULE_LOG_DIR}/${module_name}.log"

  if [ ! -f "${module_script}" ]; then
    log_message "ERROR" "Module ${module_name} not found" "${COLOR_ERROR}"
    exit 1
  fi

  log_message "INFO" "${module_name} module starting" "${COLOR_INFO}"

  if ! {
    # shellcheck disable=SC1090
    source "${module_script}"
  } >> >(tee -a "${INFRA_LOG}" "${module_log}") 2>&1; then
    log_message "ERROR" "${module_name} module failed" "${COLOR_ERROR}"
    exit 1
  fi

  log_message "OK" "${module_name} module completed" "${COLOR_OK}"
}

modules=(
  "os-detect"
  "docker"
  "nginx"
  "mysql"
  "postgres"
  "redis"
  "languages"
  "uptime-kuma"
  "firewall"
)

for module in "${modules[@]}"; do
  run_module "${module}"
done
