#!/bin/bash
### MODULE: MySQL / MariaDB

run_mysql() {
    local service_name="mysql"

    if command -v mysql >/dev/null 2>&1; then
        if systemctl list-units --type=service | grep -q "mariadb.service"; then
            service_name="mariadb"
        fi
        log_skip "MySQL/MariaDB already installed. Ensuring service is enabled."
        run_cmd "Ensuring ${service_name} service" systemctl enable --now "$service_name"
        return 0
    fi

    update_package_index

    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        install_packages default-mysql-server
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        install_packages mariadb-server mariadb
        service_name="mariadb"
    else
        log_error "Unsupported package manager for MySQL installation."
        return 1
    fi

    if systemctl list-units --type=service | grep -q "mariadb.service"; then
        service_name="mariadb"
    fi

    run_cmd "Enabling and starting ${service_name}" systemctl enable --now "$service_name"
    log_ok "MySQL/MariaDB installation completed."
    return 0
}
