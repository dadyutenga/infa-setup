#!/bin/bash
### MODULE: Redis

run_redis() {
    if ! command -v redis-server >/dev/null 2>&1; then
        update_package_index
        if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
            install_packages redis-server
        elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
            install_packages redis
        else
            log_error "Unsupported package manager for Redis."
            return 1
        fi
    else
        log_info "Redis already installed."
    fi

    if ! command -v openssl >/dev/null 2>&1; then
        update_package_index
        install_packages openssl
    fi

    local redis_conf="/etc/redis/redis.conf"
    if [[ ! -f "$redis_conf" ]]; then
        redis_conf="/etc/redis.conf"
    fi

    if [[ -f "$redis_conf" ]]; then
        run_cmd "Configuring Redis for systemd supervision" sed -i "s/^supervised .*/supervised systemd/" "$redis_conf"
        run_cmd "Ensuring Redis binds to localhost" sed -i "s/^#*bind .*/bind 127.0.0.1 ::1/" "$redis_conf"
        run_cmd "Enabling protected mode" sed -i "s/^#*protected-mode .*/protected-mode yes/" "$redis_conf"

        if ! grep -q '^requirepass' "$redis_conf"; then
            local redis_password
            redis_password="$(openssl rand -base64 24)"
            echo "requirepass ${redis_password}" >> "$redis_conf"
            echo "Redis password: ${redis_password}" >> "$MODULE_LOG_FILE"
            log_info "Generated Redis password stored in module log."
        fi
    else
        log_warn "Redis configuration file not found at $redis_conf."
    fi

    local service_name="redis-server"
    if systemctl list-unit-files | grep -q "redis.service"; then
        service_name="redis"
    fi

    run_cmd "Enabling and restarting Redis" systemctl enable --now "$service_name"

    log_info "Redis installation and configuration complete."
    return 0
}
