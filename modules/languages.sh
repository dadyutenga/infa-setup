#!/usr/bin/env bash
set -euo pipefail

: "${OS_FAMILY:?OS_FAMILY is not set. Run os-detect first.}"

ensure_curl() {
  if command -v curl >/dev/null 2>&1; then
    return
  fi

  echo "[INFO] Installing curl dependency"
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y curl
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y install curl
  else
    echo "[ERROR] Unsupported package manager while ensuring curl"
    return 1
  fi
  echo "[OK] curl installed"
}

install_node() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    echo "[SKIP] Node.js and npm already installed"
    return
  fi

  echo "[INFO] Installing Node.js and npm"
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y nodejs npm
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y module reset nodejs || true
    dnf -y module enable nodejs:18
    dnf -y install nodejs npm
  else
    echo "[ERROR] Unsupported package manager for Node.js"
    return 1
  fi
  echo "[OK] Node.js and npm installed"
}

install_python() {
  if command -v python3 >/dev/null 2>&1 && command -v pip3 >/dev/null 2>&1; then
    echo "[SKIP] Python3 and pip already installed"
    return
  fi

  echo "[INFO] Installing Python3 and pip"
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y python3 python3-pip
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y install python3 python3-pip
  else
    echo "[ERROR] Unsupported package manager for Python"
    return 1
  fi
  echo "[OK] Python3 and pip installed"
}

install_go() {
  local desired_version="1.22.4"
  local current_version=""
  if command -v go >/dev/null 2>&1; then
    current_version="$(go version | awk '{print $3}' | sed 's/go//')"
    if [ "${current_version}" = "${desired_version}" ]; then
      echo "[SKIP] Go ${desired_version} already installed"
      return
    fi
  fi

  ensure_curl

  echo "[INFO] Installing Go ${desired_version}"
  local tarball="go${desired_version}.linux-amd64.tar.gz"
  curl -fsSL "https://go.dev/dl/${tarball}" -o "${tarball}"
  rm -rf /usr/local/go
  tar -C /usr/local -xzf "${tarball}"
  rm -f "${tarball}"
  echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh
  chmod +x /etc/profile.d/go.sh
  echo "[OK] Go ${desired_version} installed"
}

install_php() {
  local php_version="8.3"
  if command -v php >/dev/null 2>&1; then
    if php -v | grep -q "PHP ${php_version}"; then
      echo "[SKIP] PHP ${php_version} already installed"
      return
    fi
  fi

  ensure_curl

  echo "[INFO] Installing PHP ${php_version}"
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ca-certificates apt-transport-https lsb-release curl gnupg
    if [ ! -f /etc/apt/trusted.gpg.d/sury-php.gpg ]; then
      curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-php.gpg
    fi
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php-sury.list
    apt-get update
    apt-get install -y php${php_version} php${php_version}-cli php${php_version}-fpm php${php_version}-common
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y module reset php || true
    dnf -y module enable php:${php_version}
    dnf -y install php php-cli php-fpm
  else
    echo "[ERROR] Unsupported package manager for PHP"
    return 1
  fi
  echo "[OK] PHP ${php_version} installed"
}

install_node
install_python
install_go
install_php

echo "[OK] Language runtimes ready"
