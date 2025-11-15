#!/bin/bash
### MODULE: RabbitMQ

run_rabbitmq() {
    if ! command -v rabbitmqctl >/dev/null 2>&1; then
        update_package_index
        if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
            install_packages rabbitmq-server
        elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
            install_packages rabbitmq-server
        else
            log_error "Unsupported package manager for RabbitMQ."
            return 1
        fi
    else
        log_info "RabbitMQ already installed."
    fi

    if ! command -v openssl >/dev/null 2>&1; then
        update_package_index
        install_packages openssl
    fi

    run_cmd "Enabling and starting RabbitMQ" systemctl enable --now rabbitmq-server

    run_cmd "Enabling RabbitMQ management plugin" rabbitmq-plugins enable rabbitmq_management

    local admin_user="infra_admin"
    local admin_password
    admin_password="$(openssl rand -base64 24)"

    if rabbitmqctl list_users | awk '{print $1}' | grep -q "^${admin_user}$"; then
        log_info "Updating RabbitMQ admin user password."
        rabbitmqctl change_password "$admin_user" "$admin_password"
    else
        log_info "Creating RabbitMQ admin user."
        rabbitmqctl add_user "$admin_user" "$admin_password"
        rabbitmqctl set_user_tags "$admin_user" administrator
        rabbitmqctl set_permissions -p / "$admin_user" ".*" ".*" ".*"
    fi

    echo "RabbitMQ admin user: ${admin_user}" >> "$MODULE_LOG_FILE"
    echo "RabbitMQ admin password: ${admin_password}" >> "$MODULE_LOG_FILE"

    log_info "RabbitMQ configuration complete. Credentials stored in module log only."
    return 0
}
