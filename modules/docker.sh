#!/bin/bash
### MODULE: Docker

run_docker() {
    if command -v docker >/dev/null 2>&1; then
        log_skip "Docker already installed. Ensuring service is enabled."
        run_cmd "Enabling Docker service" systemctl enable --now docker
        return 0
    fi

    update_package_index

    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        install_packages ca-certificates curl gnupg lsb-release
        local keyring="/etc/apt/keyrings/docker.gpg"
        mkdir -p /etc/apt/keyrings
        if [[ ! -f "$keyring" ]]; then
            run_cmd "Adding Docker GPG key" curl -fsSL "https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg" -o "$keyring"
            run_cmd "Setting Docker key permissions" chmod a+r "$keyring"
        fi
        local repo="deb [arch=$(dpkg --print-architecture) signed-by=$keyring] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") $(lsb_release -cs 2>/dev/null || { . /etc/os-release && echo "$VERSION_CODENAME"; }) stable"
        echo "$repo" > /etc/apt/sources.list.d/docker.list
        update_package_index
        install_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        install_packages dnf-plugins-core curl
        if [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
            run_cmd "Adding Docker repository" dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        fi
        install_packages docker-ce docker-ce-cli containerd.io docker-compose-plugin
    else
        log_error "Unsupported package manager for Docker: $PACKAGE_MANAGER"
        return 1
    fi

    run_cmd "Enabling Docker service" systemctl enable --now docker

    if ! getent group docker >/dev/null 2>&1; then
        run_cmd "Creating docker group" groupadd docker
    fi

    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        run_cmd "Adding ${SUDO_USER} to docker group" usermod -aG docker "$SUDO_USER"
    fi

    log_ok "Docker installation complete."
    return 0
}
