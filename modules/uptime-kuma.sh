#!/bin/bash
### MODULE: Uptime Kuma

run_uptime_kuma() {
    local install_dir="/opt/uptime-kuma"
    local service_file="/etc/systemd/system/uptime-kuma.service"

    update_package_index
    install_packages git

    if systemctl list-unit-files | grep -q '^uptime-kuma.service'; then
        log_skip "Uptime-Kuma service already present. Ensuring it is running."
        run_cmd "Ensuring Uptime-Kuma service" systemctl enable --now uptime-kuma
        return 0
    fi

    if ! command -v npm >/dev/null 2>&1; then
        log_error "npm is required for Uptime-Kuma. Ensure Node.js installation succeeded."
        return 1
    fi

    if ! id uptime-kuma >/dev/null 2>&1; then
        run_cmd "Creating uptime-kuma user" useradd --system --home "$install_dir" --shell /usr/sbin/nologin uptime-kuma
    fi

    rm -rf "$install_dir"
    run_cmd "Cloning Uptime-Kuma" git clone https://github.com/louislam/uptime-kuma.git "$install_dir"
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

    log_ok "Uptime-Kuma installed and running."
    return 0
}
