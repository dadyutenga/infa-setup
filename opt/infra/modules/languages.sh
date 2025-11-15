#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_os
ensure_root

install_node() {
  if command_exists node; then
    local current
    current="$(node -v | sed 's/v//')"
    local major="${current%%.*}"
    if (( major >= 20 )); then
      log INFO "Node.js ${current} already installed"
      return
    fi
  fi

  case "$OS_ID" in
    debian|ubuntu)
      apt_install ca-certificates curl gnupg
      install -d -m 0755 /etc/apt/keyrings
      if [[ ! -f /etc/apt/keyrings/nodesource.gpg ]]; then
        log INFO "Adding NodeSource GPG key"
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
      fi
      echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
      rm -f "$APT_UPDATED_FLAG"
      apt_install nodejs
      ;;
    almalinux)
      if ! rpm -q nodesource-release >/dev/null 2>&1; then
        log INFO "Adding NodeSource repository"
        curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - >>"$LOG_FILE" 2>&1
      fi
      dnf_install nodejs
      ;;
    *)
      log ERROR "Node.js installation unsupported on ${OS_ID}"
      exit 1
      ;;
  esac
  log INFO "Node.js installation complete"
}

install_python() {
  local target_version="3.12.2"
  if command_exists python3.12; then
    log INFO "Python 3.12 already installed"
    return
  fi

  case "$OS_ID" in
    debian|ubuntu)
      apt_install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev liblzma-dev tk-dev uuid-dev xz-utils
      ;;
    almalinux)
      dnf_install gcc openssl-devel bzip2-devel libffi-devel zlib-devel xz-devel readline-devel sqlite-devel tk-devel uuid-devel make wget
      ;;
    *)
      log ERROR "Python installation unsupported on ${OS_ID}"
      exit 1
      ;;
  esac

  local src_dir="/usr/local/src"
  mkdir -p "$src_dir"
  local tarball="Python-${target_version}.tgz"
  if [[ ! -f "${src_dir}/${tarball}" ]]; then
    log INFO "Downloading Python ${target_version}"
    wget -q -O "${src_dir}/${tarball}" "https://www.python.org/ftp/python/${target_version}/Python-${target_version}.tgz"
  fi
  rm -rf "${src_dir}/Python-${target_version}"
  tar -xf "${src_dir}/${tarball}" -C "$src_dir"
  pushd "${src_dir}/Python-${target_version}" >/dev/null
  ./configure --enable-optimizations >>"$LOG_FILE" 2>&1
  make -j "$(nproc)" >>"$LOG_FILE" 2>&1
  make altinstall >>"$LOG_FILE" 2>&1
  popd >/dev/null

  ln -sf /usr/local/bin/python3.12 /usr/local/bin/python3
  if [[ ! -f /usr/local/bin/pip3.12 ]]; then
    /usr/local/bin/python3.12 -m ensurepip >>"$LOG_FILE" 2>&1
  fi
  log INFO "Python 3.12 installation complete"
}

install_go() {
  local go_version="1.22.3"
  if command_exists go; then
    local current
    current="$(go version | awk '{print $3}' | sed 's/go//')"
    if [[ "$current" == "$go_version" ]]; then
      log INFO "Go ${current} already installed"
      return
    fi
  fi

  local archive="go${go_version}.linux-amd64.tar.gz"
  local url="https://go.dev/dl/${archive}"
  local tmpdir="/tmp"
  case "$OS_ID" in
    debian|ubuntu)
      apt_install wget tar
      ;;
    almalinux)
      dnf_install wget tar
      ;;
  esac
  log INFO "Downloading Go ${go_version}"
  wget -q -O "${tmpdir}/${archive}" "$url"
  rm -rf /usr/local/go
  tar -C /usr/local -xzf "${tmpdir}/${archive}"
  cat >/etc/profile.d/go.sh <<'PROFILE'
export PATH=/usr/local/go/bin:${PATH}
PROFILE
  chmod 0755 /etc/profile.d/go.sh
  log INFO "Go ${go_version} installed"
}

install_php() {
  local required_major="8.3"
  if command_exists php; then
    local current
    current="$(php -v | head -n1 | awk '{print $2}')"
    if [[ "$current" == ${required_major}* ]]; then
      log INFO "PHP ${current} already installed"
      return
    fi
  fi

  case "$OS_ID" in
    debian|ubuntu)
      apt_install ca-certificates apt-transport-https lsb-release curl
      if [[ ! -f /etc/apt/trusted.gpg.d/php.gpg ]]; then
        curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/php.gpg
      fi
      local codename
      codename="${VERSION_CODENAME:-$(lsb_release -sc)}"
      echo "deb https://packages.sury.org/php/ ${codename} main" >/etc/apt/sources.list.d/php-sury.list
      rm -f "$APT_UPDATED_FLAG"
      apt_install php8.3 php8.3-cli php8.3-fpm php8.3-common php8.3-mysql php8.3-xml php8.3-curl php8.3-zip php8.3-gd php8.3-intl php8.3-mbstring php8.3-bcmath
      ;;
    almalinux)
      dnf_install epel-release
      if ! rpm -qa | grep -q remi-release; then
        log INFO "Adding Remi repository"
        dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm >>"$LOG_FILE" 2>&1
      fi
      dnf module reset -y php >>"$LOG_FILE" 2>&1 || true
      dnf module enable -y php:remi-8.3 >>"$LOG_FILE" 2>&1
      dnf_install php php-cli php-fpm php-common php-mysqlnd php-xml php-gd php-intl php-zip php-opcache php-mbstring php-bcmath php-curl
      ;;
    *)
      log ERROR "PHP installation unsupported on ${OS_ID}"
      exit 1
      ;;
  esac
  log INFO "PHP 8.3 installation complete"
}

install_node
install_python
install_go
install_php

log INFO "Language runtimes provisioned"
