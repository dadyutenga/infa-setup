#!/usr/bin/env bash
set -euo pipefail

if [ ! -r /etc/os-release ]; then
  echo "[ERROR] /etc/os-release not found"
  return 1
fi

# shellcheck disable=SC1091
. /etc/os-release

OS_VERSION="${VERSION_ID:-unknown}"

case "${ID}" in
  debian)
    OS_FAMILY="debian"
    ;;
  ubuntu)
    OS_FAMILY="debian"
    ;;
  almalinux)
    OS_FAMILY="almalinux"
    ;;
  *)
    if [[ "${ID_LIKE:-}" == *"rhel"* ]]; then
      OS_FAMILY="almalinux"
    elif [[ "${ID_LIKE:-}" == *"debian"* ]]; then
      OS_FAMILY="debian"
    else
      echo "[ERROR] Unsupported distribution: ${ID}"
      return 1
    fi
    ;;
esac

export OS_FAMILY
export OS_VERSION

echo "[INFO] Detected OS family: ${OS_FAMILY}"
echo "[INFO] Detected OS version: ${OS_VERSION}"
