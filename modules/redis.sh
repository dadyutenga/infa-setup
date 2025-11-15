#!/bin/bash
### MODULE: Redis

run_redis() {
    local service_name="redis-server"
    if command -v redis-server >/dev/null 2>&1; then
        if systemctl list-unit-files | grep -q "redis.service"; then
            service_name="redis"
        fi
        log_skip "Redis already installed. Ensuring service is enabled."
        run_cmd "Ensuring Redis service" systemctl enable --now "$service_name"
        return 0
    fi

    update_package_index
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        install_packages redis-server
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        install_packages redis
        service_name="redis"
    else
        log_error "Unsupported package manager for Redis."
        return 1
    fi

    if systemctl list-unit-files | grep -q "redis.service"; then
        service_name="redis"
    fi

    run_cmd "Enabling and starting Redis" systemctl enable --now "$service_name"
    log_ok "Redis installation complete."
    return 0
}
