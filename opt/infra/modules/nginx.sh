#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_os
ensure_root

if command_exists apache2; then
  log WARN "Apache detected. Stopping and disabling to prevent conflicts."
  systemctl stop apache2 >>"$LOG_FILE" 2>&1 || true
  systemctl disable apache2 >>"$LOG_FILE" 2>&1 || true
fi

case "$OS_ID" in
  debian|ubuntu)
    apt_install nginx
    ;;
  almalinux)
    dnf_install epel-release
    dnf_install nginx
    ;;
  *)
    log ERROR "Nginx installation unsupported on this OS: ${OS_ID}"
    exit 1
    ;;
esac

systemctl_enable_start nginx

if [[ -z "$PRIMARY_DOMAIN" ]]; then
  log WARN "PRIMARY_DOMAIN not provided. Skipping nginx virtual host provisioning."
  exit 0
fi

IFS=',' read -r -a SUBDOMAINS <<<"$SUBDOMAIN_LIST"

SITES_AVAILABLE="/etc/nginx/sites-available"
SITES_ENABLED="/etc/nginx/sites-enabled"
mkdir -p "$SITES_AVAILABLE" "$SITES_ENABLED"

CONF_PATH="${SITES_AVAILABLE}/${PRIMARY_DOMAIN}.conf"

log INFO "Generating nginx configuration at ${CONF_PATH}"

cat >"$CONF_PATH" <<CONF
## Managed by infra-setup
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    listen [::]:80;
    server_name ${PRIMARY_DOMAIN};

    root /var/www/${PRIMARY_DOMAIN}/html;
    index index.html index.htm;

    access_log /var/log/nginx/${PRIMARY_DOMAIN}_access.log;
    error_log  /var/log/nginx/${PRIMARY_DOMAIN}_error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
CONF

mkdir -p "/var/www/${PRIMARY_DOMAIN}/html"
if [[ ! -f "/var/www/${PRIMARY_DOMAIN}/html/index.html" ]]; then
  cat >"/var/www/${PRIMARY_DOMAIN}/html/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>${PRIMARY_DOMAIN}</title></head>
<body><h1>${PRIMARY_DOMAIN}</h1><p>Provisioned by infra-setup.</p></body>
</html>
HTML
fi

for sub in "${SUBDOMAINS[@]}"; do
  sub_trimmed="${sub// /}"
  [[ -z "$sub_trimmed" ]] && continue
  host="${sub_trimmed}.${PRIMARY_DOMAIN}"
  cat >>"$CONF_PATH" <<CONF

server {
    listen 80;
    listen [::]:80;
    server_name ${host};

    root /var/www/${host}/html;
    index index.html index.htm;

    access_log /var/log/nginx/${host}_access.log;
    error_log  /var/log/nginx/${host}_error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
CONF
  mkdir -p "/var/www/${host}/html"
  if [[ ! -f "/var/www/${host}/html/index.html" ]]; then
    cat >"/var/www/${host}/html/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>${host}</title></head>
<body><h1>${host}</h1><p>Provisioned by infra-setup.</p></body>
</html>
HTML
  fi
done

ln -sf "$CONF_PATH" "${SITES_ENABLED}/${PRIMARY_DOMAIN}.conf"

if [[ -f /etc/nginx/sites-enabled/default ]]; then
  rm -f /etc/nginx/sites-enabled/default
fi

log INFO "Validating nginx configuration"
nginx -t >>"$LOG_FILE" 2>&1

log INFO "Reloading nginx"
systemctl reload nginx >>"$LOG_FILE" 2>&1

log INFO "Nginx configuration complete"
