#!/bin/bash
### MODULE: Nginx

run_nginx() {
    if command -v nginx >/dev/null 2>&1; then
        log_skip "Nginx already installed. Ensuring service is enabled."
        run_cmd "Ensuring Nginx service" systemctl enable --now nginx
        return 0
    fi

    update_package_index
    install_packages nginx
    run_cmd "Enabling and starting Nginx" systemctl enable --now nginx
    log_ok "Nginx installation complete."
    return 0
}
