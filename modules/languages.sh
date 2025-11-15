#!/bin/bash
### MODULE: Languages Runtime Installation

run_languages() {
    install_node
    install_python
    install_go
    install_php
    return 0
}

version_ge() {
    # usage: version_ge current minimum
    printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1 | grep -qx "$2"
}

install_node() {
    if command -v node >/dev/null 2>&1; then
        local node_version
        node_version="$(node --version | tr -d 'v')"
        if version_ge "$node_version" "18.0.0"; then
            log_info "Node.js $node_version already satisfies LTS requirement."
            return
        fi
        log_info "Existing Node.js version $node_version is outdated. Upgrading."
    else
        log_info "Installing Node.js LTS."
    fi

    update_package_index
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        install_packages ca-certificates curl gnupg
        local keyring="/etc/apt/keyrings/nodesource.gpg"
        mkdir -p /etc/apt/keyrings
        run_cmd "Fetching NodeSource GPG key" curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key -o "$keyring"
        chmod 644 "$keyring"
        local distro
        distro="$(lsb_release -cs 2>/dev/null || { . /etc/os-release && echo "$VERSION_CODENAME"; })"
        echo "deb [signed-by=$keyring] https://deb.nodesource.com/node_18.x $distro main" > /etc/apt/sources.list.d/nodesource.list
        update_package_index
        install_packages nodejs
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        install_packages curl
        run_cmd "Configuring NodeSource repository" bash -c "curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -"
        install_packages nodejs
    else
        log_warn "Unsupported package manager for Node.js. Skipping."
    fi
}

install_python() {
    if command -v python3.12 >/dev/null 2>&1; then
        log_info "Python $(python3.12 --version 2>/dev/null) already installed."
        return
    fi

    log_info "Building Python 3.12 from source."

    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        install_packages build-essential libssl-dev zlib1g-dev libncurses5-dev libffi-dev libsqlite3-dev libreadline-dev libbz2-dev liblzma-dev tk-dev libgdbm-dev wget
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        install_packages gcc openssl-devel bzip2-devel libffi-devel zlib-devel readline-devel sqlite-devel xz-devel tk-devel make wget
    fi

    local python_version="3.12.3"
    local python_src="/tmp/Python-${python_version}.tgz"
    if [[ ! -f "$python_src" ]]; then
        run_cmd "Downloading Python ${python_version}" wget -q https://www.python.org/ftp/python/${python_version}/Python-${python_version}.tgz -O "$python_src"
    fi
    tar -xf "$python_src" -C /tmp
    pushd /tmp/Python-${python_version} >/dev/null
    run_cmd "Configuring Python ${python_version}" ./configure --enable-optimizations
    run_cmd "Building Python ${python_version}" make -j"$(nproc)"
    run_cmd "Installing Python ${python_version}" make altinstall
    popd >/dev/null
    rm -rf /tmp/Python-${python_version}

    log_info "Python $(python3.12 --version 2>/dev/null) installed."
}

install_go() {
    if ! command -v curl >/dev/null 2>&1; then
        install_packages curl
    fi
    local go_version
    go_version="$(curl -s https://go.dev/VERSION?m=text | head -n1)"
    if [[ -z "$go_version" ]]; then
        log_error "Unable to determine latest Go version."
        return 1
    fi

    local current=""
    if command -v go >/dev/null 2>&1; then
        current="$(go version | awk '{print $3}')"
        if [[ "$current" == "$go_version" ]]; then
            log_info "Go ${go_version} already installed."
            return
        fi
        log_info "Updating Go from ${current} to ${go_version}."
    else
        log_info "Installing Go ${go_version}."
    fi

    local archive="/tmp/${go_version}.linux-amd64.tar.gz"
    run_cmd "Downloading Go ${go_version}" curl -fsSL https://go.dev/dl/${go_version}.linux-amd64.tar.gz -o "$archive"
    rm -rf /usr/local/go
    tar -C /usr/local -xzf "$archive"
    ln -sf /usr/local/go/bin/go /usr/local/bin/go
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

    log_info "Go ${go_version} installed."
}

install_php() {
    local desired_version="8.3"
    local current_version=""
    if command -v php >/dev/null 2>&1; then
        current_version="$(php -r 'echo PHP_VERSION;' 2>/dev/null)"
        local major
        local minor
        major="${current_version%%.*}"
        minor="${current_version#*.}"
        minor="${minor%%.*}"
        if [[ -n "$current_version" ]]; then
            if (( major > 8 || (major == 8 && minor >= 3) )); then
                log_info "PHP ${current_version} already meets requirement."
                return
            fi
        fi
        log_info "Upgrading PHP from ${current_version} to ${desired_version}."
    else
        log_info "Installing PHP ${desired_version}."
    fi

    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        install_packages ca-certificates curl gnupg software-properties-common
        if [[ "$OS_ID" == "ubuntu" ]]; then
            run_cmd "Adding Ondřej Surý PHP PPA" add-apt-repository ppa:ondrej/php -y
        else
            local keyring="/etc/apt/keyrings/sury-php.gpg"
            mkdir -p /etc/apt/keyrings
            run_cmd "Fetching Sury PHP GPG key" curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o "$keyring"
            echo "deb [signed-by=$keyring] https://packages.sury.org/php/ $(lsb_release -cs 2>/dev/null || { . /etc/os-release && echo \"$VERSION_CODENAME\"; }) main" > /etc/apt/sources.list.d/php-sury.list
        fi
        update_package_index
        install_packages php8.3 php8.3-cli php8.3-fpm php8.3-common php8.3-mysql php8.3-pgsql php8.3-xml php8.3-curl php8.3-mbstring php8.3-zip php8.3-redis
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        install_packages dnf-plugins-core
        run_cmd "Installing Remi repository" dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
        run_cmd "Enabling Remi PHP 8.3 module" dnf module enable -y php:remi-8.3
        install_packages php php-cli php-fpm php-mysqlnd php-pgsql php-xml php-json php-mbstring php-gd php-curl php-zip php-pecl-redis5
    else
        log_warn "Unsupported package manager for PHP."
    fi

    systemctl enable --now php8.3-fpm 2>/dev/null || systemctl enable --now php-fpm 2>/dev/null || true
    log_info "PHP $(php -v | head -n1) installed."
}
