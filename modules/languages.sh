#!/bin/bash
### MODULE: Languages Runtime Installation

run_languages() {
    install_node
    install_python
    install_go
    install_php
    return 0
}

install_node() {
    local desired_major=20
    if command -v node >/dev/null 2>&1; then
        local current_major
        current_major="$(node --version | tr -d 'v' | cut -d'.' -f1)"
        if [[ "$current_major" -ge "$desired_major" ]]; then
            log_skip "Node.js $(node --version) already meets LTS requirement."
            return
        fi
        log_info "Updating Node.js to LTS ${desired_major}.x series."
    else
        log_info "Installing Node.js LTS ${desired_major}.x."
    fi

    update_package_index
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        install_packages ca-certificates curl gnupg lsb-release
        local keyring="/etc/apt/keyrings/nodesource.gpg"
        mkdir -p /etc/apt/keyrings
        if [[ ! -f "$keyring" ]]; then
            run_cmd "Importing NodeSource key" bash -c "curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o '$keyring'"
            chmod 644 "$keyring"
        fi
        local codename
        codename="$(lsb_release -cs 2>/dev/null || { . /etc/os-release && echo "$VERSION_CODENAME"; })"
        echo "deb [signed-by=$keyring] https://deb.nodesource.com/node_${desired_major}.x $codename main" > /etc/apt/sources.list.d/nodesource.list
        update_package_index
        install_packages nodejs
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        install_packages curl
        cat <<'YUM' > /etc/yum.repos.d/nodesource.repo
[nodesource]
name=Node.js Packages for Enterprise Linux
baseurl=https://rpm.nodesource.com/pub_${desired_major}.x/el/9/$basearch
enabled=1
gpgcheck=1
gpgkey=https://rpm.nodesource.com/pub_${desired_major}.x/el/9/$basearch/repodata/repomd.xml.key
YUM
        update_package_index
        install_packages nodejs
    else
        log_error "Unsupported package manager for Node.js installation."
        return 1
    fi

    log_ok "Node.js $(node --version) installed."
}

install_python() {
    if command -v python3 >/dev/null 2>&1; then
        log_skip "$(python3 --version) already installed."
        if ! command -v pip3 >/dev/null 2>&1; then
            install_packages python3-pip
        fi
        return
    fi

    update_package_index
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        install_packages python3 python3-pip python3-venv
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        install_packages python3 python3-pip
    else
        log_error "Unsupported package manager for Python installation."
        return 1
    fi

    log_ok "$(python3 --version) installed."
}

install_go() {
    if ! command -v curl >/dev/null 2>&1; then
        install_packages curl
    fi
    local go_version
    go_version="$(curl -fsSL https://go.dev/VERSION?m=text | head -n1)"
    if [[ -z "$go_version" ]]; then
        log_error "Unable to determine latest Go version."
        return 1
    fi

    if command -v go >/dev/null 2>&1; then
        local current
        current="$(go version | awk '{print $3}')"
        if [[ "$current" == "$go_version" ]]; then
            log_skip "Go ${go_version} already installed."
            return
        fi
        log_info "Updating Go from ${current} to ${go_version}."
    else
        log_info "Installing Go ${go_version}."
    fi

    local archive="/tmp/${go_version}.linux-amd64.tar.gz"
    run_cmd "Downloading Go ${go_version}" curl -fsSL "https://go.dev/dl/${go_version}.linux-amd64.tar.gz" -o "$archive"
    rm -rf /usr/local/go
    run_cmd "Extracting Go ${go_version}" tar -C /usr/local -xzf "$archive"
    ln -sf /usr/local/go/bin/go /usr/local/bin/go
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
    log_ok "Go ${go_version} installed."
}

install_php() {
    local desired_major=8
    local desired_minor=3
    if command -v php >/dev/null 2>&1; then
        local current_version
        current_version="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)"
        local current_major="${current_version%%.*}"
        local current_minor="${current_version#*.}"
        if [[ -n "$current_major" && -n "$current_minor" && "$current_major" -ge "$desired_major" && "$current_minor" -ge "$desired_minor" ]]; then
            log_skip "PHP $(php -v | head -n1) already meets requirement."
            return
        fi
        log_info "Updating PHP to ${desired_major}.${desired_minor}."
    else
        log_info "Installing PHP ${desired_major}.${desired_minor}."
    fi

    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        install_packages ca-certificates curl gnupg software-properties-common lsb-release
        if [[ "$OS_ID" == "ubuntu" ]]; then
            if [[ ! -f /etc/apt/sources.list.d/ondrej-php.list ]]; then
                run_cmd "Adding Ondřej Surý PHP PPA" add-apt-repository -y ppa:ondrej/php
            fi
        else
            local keyring="/etc/apt/keyrings/sury-php.gpg"
            mkdir -p /etc/apt/keyrings
            if [[ ! -f "$keyring" ]]; then
                run_cmd "Importing Sury PHP key" bash -c "curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o '$keyring'"
                chmod 644 "$keyring"
            fi
            echo "deb [signed-by=$keyring] https://packages.sury.org/php/ $(lsb_release -cs 2>/dev/null || { . /etc/os-release && echo \"$VERSION_CODENAME\"; }) main" > /etc/apt/sources.list.d/php-sury.list
        fi
        update_package_index
        install_packages php8.3 php8.3-cli php8.3-fpm php8.3-common php8.3-mysql php8.3-pgsql php8.3-xml php8.3-curl php8.3-mbstring php8.3-zip php8.3-redis
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        install_packages dnf-plugins-core
        if ! dnf repolist | grep -q remi; then
            run_cmd "Installing Remi repository" dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
        fi
        run_cmd "Enabling Remi PHP 8.3 module" dnf module enable -y php:remi-8.3
        install_packages php php-cli php-fpm php-mysqlnd php-pgsql php-xml php-json php-mbstring php-gd php-curl php-zip php-pear php-pecl-redis5
    else
        log_error "Unsupported package manager for PHP installation."
        return 1
    fi

    if systemctl list-unit-files | grep -q 'php8.3-fpm.service'; then
        run_cmd "Enabling PHP 8.3 FPM" systemctl enable --now php8.3-fpm
    elif systemctl list-unit-files | grep -q 'php-fpm.service'; then
        run_cmd "Enabling PHP FPM" systemctl enable --now php-fpm
    else
        log_skip "PHP FPM service not available to enable."
    fi

    log_ok "$(php -v | head -n1) installed."
}
