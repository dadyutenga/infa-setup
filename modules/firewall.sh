#!/bin/bash
### MODULE: Firewall Configuration

open_ports=(22 80 443 3001 5672 6379)

run_firewall() {
    if [[ "$OS_FAMILY" == "debian" ]]; then
        install_packages ufw
        if ! ufw status >/dev/null 2>&1; then
            log_error "UFW command unavailable after installation."
            return 1
        fi
        for port in "${open_ports[@]}"; do
            run_cmd "Allowing TCP port ${port} via UFW" ufw allow ${port}/tcp
        done
        if ! ufw status | grep -q "Status: active"; then
            run_cmd "Enabling UFW firewall" ufw --force enable
        else
            log_skip "UFW already active."
        fi
        log_ok "UFW firewall configured."
    elif [[ "$OS_FAMILY" == "rhel" ]]; then
        install_packages firewalld
        run_cmd "Enabling firewalld" systemctl enable --now firewalld
        for port in "${open_ports[@]}"; do
            run_cmd "Allowing TCP port ${port} via firewalld" firewall-cmd --permanent --add-port=${port}/tcp
        done
        run_cmd "Allowing SSH service" firewall-cmd --permanent --add-service=ssh
        run_cmd "Allowing HTTP service" firewall-cmd --permanent --add-service=http
        run_cmd "Allowing HTTPS service" firewall-cmd --permanent --add-service=https
        run_cmd "Reloading firewalld" firewall-cmd --reload
        log_ok "firewalld configured."
    else
        log_error "Unsupported OS family for firewall configuration."
        return 1
    fi
    return 0
}
