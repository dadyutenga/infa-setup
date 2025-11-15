#!/bin/bash
### MODULE: Firewall Configuration

run_firewall() {
    if [[ "$OS_FAMILY" == "debian" ]]; then
        install_packages ufw
        if ! ufw status | grep -q "Status: active"; then
            log_info "Enabling UFW firewall."
            ufw allow OpenSSH
            ufw allow 80
            ufw allow 443
            ufw allow 6379
            ufw allow 5672
            ufw allow 15672
            ufw allow 3001
            echo "y" | ufw enable
        else
            log_info "UFW already active. Refreshing rules."
            ufw allow 80
            ufw allow 443
            ufw allow 6379
            ufw allow 5672
            ufw allow 15672
            ufw allow 3001
        fi
    elif [[ "$OS_FAMILY" == "rhel" ]]; then
        install_packages firewalld
        run_cmd "Enabling firewalld" systemctl enable --now firewalld
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --permanent --add-port=6379/tcp
        firewall-cmd --permanent --add-port=5672/tcp
        firewall-cmd --permanent --add-port=15672/tcp
        firewall-cmd --permanent --add-port=3001/tcp
        firewall-cmd --reload
    else
        log_warn "Unsupported OS family for firewall configuration."
    fi

    log_info "Firewall configuration completed."
    return 0
}
