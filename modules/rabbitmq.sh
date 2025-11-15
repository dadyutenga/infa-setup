#!/bin/bash
### MODULE: RabbitMQ

configure_rabbitmq_repo_debian() {
    install_packages curl gnupg apt-transport-https lsb-release ca-certificates
    local keyring="/usr/share/keyrings/rabbitmq-archive-keyring.gpg"
    if [[ ! -f "$keyring" ]]; then
        run_cmd "Importing RabbitMQ signing key" bash -c "curl -fsSL https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey | gpg --dearmor -o '$keyring'"
        chmod 644 "$keyring"
    fi
    local distro
    distro="$(lsb_release -is | tr 'A-Z' 'a-z')"
    local codename
    codename="$(lsb_release -cs)"
    cat <<APT > /etc/apt/sources.list.d/rabbitmq.list
deb [signed-by=$keyring] https://packagecloud.io/rabbitmq/rabbitmq-server/${distro}/ ${codename} main
deb [signed-by=$keyring] https://packagecloud.io/rabbitmq/erlang/${distro}/ ${codename} main
APT
}

configure_rabbitmq_repo_rhel() {
    install_packages curl
    cat <<'YUM' > /etc/yum.repos.d/rabbitmq.repo
[rabbitmq_erlang]
name=RabbitMQ Erlang
baseurl=https://packagecloud.io/rabbitmq/erlang/el/9/$basearch
gpgcheck=1
gpgkey=https://packagecloud.io/rabbitmq/erlang/gpgkey
repo_gpgcheck=0
enabled=1

[rabbitmq_server]
name=RabbitMQ Server
baseurl=https://packagecloud.io/rabbitmq/rabbitmq-server/el/9/$basearch
gpgcheck=1
gpgkey=https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey
repo_gpgcheck=0
enabled=1
YUM
}

run_rabbitmq() {
    if command -v rabbitmqctl >/dev/null 2>&1; then
        log_skip "RabbitMQ already installed. Ensuring service and plugins are active."
        run_cmd "Ensuring RabbitMQ service" systemctl enable --now rabbitmq-server
        run_cmd "Ensuring RabbitMQ management plugin" rabbitmq-plugins enable rabbitmq_management
        return 0
    fi

    update_package_index

    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        configure_rabbitmq_repo_debian
        update_package_index
        install_packages rabbitmq-server
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        configure_rabbitmq_repo_rhel
        update_package_index
        install_packages erlang rabbitmq-server
    else
        log_error "Unsupported package manager for RabbitMQ."
        return 1
    fi

    run_cmd "Enabling and starting RabbitMQ" systemctl enable --now rabbitmq-server
    run_cmd "Enabling RabbitMQ management plugin" rabbitmq-plugins enable rabbitmq_management
    log_ok "RabbitMQ installation complete."
    return 0
}
