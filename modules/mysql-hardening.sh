#!/bin/bash
### MODULE: MySQL Hardening

run_mysql_hardening() {
    if ! command -v mysql >/dev/null 2>&1; then
        log_warn "MySQL is not installed. Skipping hardening."
        return 0
    fi

    if ! command -v openssl >/dev/null 2>&1; then
        log_info "Installing OpenSSL for secure password generation."
        update_package_index
        install_packages openssl
    fi

    local mysql_root_password
    mysql_root_password="$(openssl rand -hex 16)"
    local app_db_name="infra_app"
    local sanitized_domain
    sanitized_domain="$(echo "$PRIMARY_DOMAIN" | tr -c 'a-zA-Z0-9' '_' | tr '[:upper:]' '[:lower:]')"
    local app_db_user="${sanitized_domain}_svc"
    local app_db_password
    app_db_password="$(openssl rand -base64 24)"

    log_info "Starting MySQL hardening procedures."

    local creds_file="$LOG_DIR/mysql-root-latest.txt"
    local mysql_cmd=(mysql -uroot)
    local cleanup_pwd=false

    if mysql -uroot -e "SELECT 1;" >/dev/null 2>&1; then
        log_info "Using socket authentication for MySQL root."
    elif [[ -f "$creds_file" ]]; then
        local existing_root_password
        existing_root_password="$(grep '^ROOT_PASSWORD=' "$creds_file" | tail -n1 | cut -d'=' -f2-)"
        if [[ -z "$existing_root_password" ]]; then
            log_error "Existing credentials file $creds_file does not contain ROOT_PASSWORD."
            return 1
        fi
        log_info "Authenticating to MySQL with stored credentials."
        export MYSQL_PWD="$existing_root_password"
        cleanup_pwd=true
    else
        log_error "Unable to authenticate to MySQL. Populate $creds_file with ROOT_PASSWORD=<value>."
        return 1
    fi

    "${mysql_cmd[@]}" <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${mysql_root_password}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host!='localhost';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
CREATE DATABASE IF NOT EXISTS ${app_db_name};
CREATE USER IF NOT EXISTS '${app_db_user}'@'localhost' IDENTIFIED BY '${app_db_password}';
GRANT ALL PRIVILEGES ON ${app_db_name}.* TO '${app_db_user}'@'localhost';
FLUSH PRIVILEGES;
SQL

    local mysql_status=${PIPESTATUS[0]}
    if [[ "$cleanup_pwd" == true ]]; then
        unset MYSQL_PWD
    fi

    if [[ $mysql_status -ne 0 ]]; then
        log_error "MySQL hardening failed."
        return 1
    fi

    cat <<CREDS > "$creds_file"
ROOT_PASSWORD=${mysql_root_password}
APPLICATION_DATABASE=${app_db_name}
APPLICATION_USER=${app_db_user}
APPLICATION_PASSWORD=${app_db_password}
GENERATED_AT=$(date --iso-8601=seconds)
CREDS
    chmod 600 "$creds_file"

    echo "MySQL root password: ${mysql_root_password}" >> "$MODULE_LOG_FILE"
    echo "Application database: ${app_db_name}" >> "$MODULE_LOG_FILE"
    echo "Application user: ${app_db_user}" >> "$MODULE_LOG_FILE"
    echo "Application password: ${app_db_password}" >> "$MODULE_LOG_FILE"

    log_info "MySQL hardening complete. Credentials stored in module log and $creds_file."
    return 0
}
