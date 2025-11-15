#!/bin/bash
### MODULE: MySQL / MariaDB

run_mysql() {
    if command -v mysql >/dev/null 2>&1; then
        log_info "MySQL/MariaDB already installed."
    else
        update_package_index
        if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
            install_packages mysql-server
        elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
            install_packages mariadb-server mariadb
        else
            log_error "Unsupported package manager for MySQL installation."
            return 1
        fi
    fi

    local service_name="mysql"
    if systemctl list-units --type service | grep -q "mariadb.service"; then
        service_name="mariadb"
    fi

    run_cmd "Enabling and starting ${service_name}" systemctl enable --now "$service_name"

    log_info "MySQL/MariaDB installation completed."
    return 0
}
