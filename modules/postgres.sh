#!/bin/bash
### MODULE: PostgreSQL

run_postgres() {
    if command -v psql >/dev/null 2>&1; then
        log_info "PostgreSQL already installed."
    else
        update_package_index
        if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
            install_packages postgresql postgresql-contrib
        elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
            install_packages postgresql-server postgresql-contrib
            if [[ ! -d /var/lib/pgsql/data/base ]]; then
                run_cmd "Initializing PostgreSQL database" postgresql-setup --initdb --unit postgresql
            fi
        else
            log_error "Unsupported package manager for PostgreSQL."
            return 1
        fi
    fi

    local service_name="postgresql"
    if systemctl list-unit-files | grep -q "postgresql@"; then
        # Debian uses versioned services like postgresql@14-main
        local latest_cluster
        latest_cluster=$(pg_lsclusters 2>/dev/null | awk 'NR==1 {print $1"-"$2}')
        if [[ -n "$latest_cluster" ]]; then
            service_name="postgresql@$latest_cluster"
        fi
    fi

    run_cmd "Enabling and starting PostgreSQL" systemctl enable --now "$service_name"

    log_info "PostgreSQL installation complete."
    return 0
}
