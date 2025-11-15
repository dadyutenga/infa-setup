#!/bin/bash
### MODULE: PostgreSQL Superuser Provisioning

run_postgres_superuser() {
    if ! command -v psql >/dev/null 2>&1; then
        log_warn "PostgreSQL not installed. Skipping superuser creation."
        return 0
    fi

    if ! command -v openssl >/dev/null 2>&1; then
        update_package_index
        install_packages openssl
    fi

    local superuser_name="infra_superuser"
    local superuser_password
    superuser_password="$(openssl rand -base64 24)"

    local existing
    existing=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${superuser_name}'" || true)

    if [[ "$existing" == "1" ]]; then
        log_info "Superuser ${superuser_name} already exists. Updating password."
        if ! sudo -u postgres psql -c "ALTER ROLE ${superuser_name} WITH SUPERUSER LOGIN PASSWORD '${superuser_password}';" >/dev/null; then
            log_error "Failed to update password for ${superuser_name}."
            return 1
        fi
    else
        log_info "Creating PostgreSQL superuser ${superuser_name}."
        if ! sudo -u postgres psql -c "CREATE ROLE ${superuser_name} WITH SUPERUSER LOGIN PASSWORD '${superuser_password}';" >/dev/null; then
            log_error "Failed to create superuser ${superuser_name}."
            return 1
        fi
    fi

    echo "PostgreSQL superuser: ${superuser_name}" >> "$MODULE_LOG_FILE"
    echo "PostgreSQL password: ${superuser_password}" >> "$MODULE_LOG_FILE"

    log_info "PostgreSQL superuser credentials stored in module log only."
    return 0
}
