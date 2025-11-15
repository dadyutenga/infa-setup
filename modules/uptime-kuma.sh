#!/bin/bash
### MODULE: Uptime Kuma

run_uptime_kuma() {
    local install_dir="/opt/uptime-kuma"
    local service_file="/etc/systemd/system/uptime-kuma.service"

    update_package_index
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        install_packages git
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        install_packages git
    fi

    if ! id uptime-kuma >/dev/null 2>&1; then
        run_cmd "Creating uptime-kuma user" useradd --system --home "$install_dir" --shell /usr/sbin/nologin uptime-kuma
    fi

    if ! command -v npm >/dev/null 2>&1; then
        log_error "npm is required for Uptime-Kuma. Ensure the languages module installs Node.js."
        return 1
    fi

    if [[ -d "$install_dir/.git" ]]; then
        log_info "Updating existing Uptime-Kuma installation."
        run_cmd "Fetching latest Uptime-Kuma" bash -c "cd '$install_dir' && git pull"
    else
        rm -rf "$install_dir"
        run_cmd "Cloning Uptime-Kuma" git clone https://github.com/louislam/uptime-kuma.git "$install_dir"
    fi

    run_cmd "Installing Uptime-Kuma dependencies" bash -c "cd '$install_dir' && npm install --production"

    chown -R uptime-kuma:uptime-kuma "$install_dir"

    cat <<SERVICE > "$service_file"
[Unit]
Description=Uptime Kuma Service
After=network.target

[Service]
Type=simple
User=uptime-kuma
WorkingDirectory=${install_dir}
ExecStart=/usr/bin/node server/server.js
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
SERVICE

    run_cmd "Reloading systemd daemon" systemctl daemon-reload
    run_cmd "Enabling and starting Uptime-Kuma" systemctl enable --now uptime-kuma

    log_info "Uptime-Kuma installation complete and running at http://localhost:3001."
    return 0
}
