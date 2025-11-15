#!/bin/bash
### MODULE: Certbot

run_certbot() {
    if ! command -v certbot >/dev/null 2>&1; then
        update_package_index
        if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
            install_packages certbot python3-certbot-nginx
        elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
            install_packages certbot python3-certbot-nginx
        else
            log_error "Unsupported package manager for Certbot: $PACKAGE_MANAGER"
            return 1
        fi
    fi

    if [[ -z "$PRIMARY_DOMAIN" ]]; then
        log_error "Primary domain not set."
        return 1
    fi

    local domains=(api app admin billing files)
    local certbot_args=("--nginx" "--non-interactive" "--agree-tos")

    if [[ -n "$CERTBOT_EMAIL" ]]; then
        certbot_args+=("-m" "$CERTBOT_EMAIL")
    else
        certbot_args+=("--register-unsafely-without-email")
    fi

    for sub in "${domains[@]}"; do
        certbot_args+=("-d" "${sub}.${PRIMARY_DOMAIN}")
    done

    log_info "Requesting certificates for domains: ${domains[*]}.$PRIMARY_DOMAIN"
    if ! run_cmd "Executing Certbot" certbot "${certbot_args[@]}"; then
        log_warn "Certbot issuance failed. Check DNS and rerun module manually."
        return 1
    fi

    cat <<'CRON' > /etc/cron.d/certbot-renew
0 2 * * * root certbot renew --quiet --post-hook "systemctl reload nginx"
CRON

    log_info "Certbot installation and configuration complete."
    return 0
}
