#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_os
ensure_root

if [[ -z "$PRIMARY_DOMAIN" ]]; then
  log WARN "PRIMARY_DOMAIN not provided. Skipping certbot setup."
  exit 0
fi

install_certbot() {
  case "$OS_ID" in
    debian|ubuntu)
      apt_install certbot python3-certbot-nginx
      ;;
    almalinux)
      dnf_install certbot python3-certbot-nginx
      ;;
    *)
      log ERROR "Certbot installation unsupported on this OS: ${OS_ID}"
      exit 1
      ;;
  esac
}

if ! command_exists certbot; then
  log INFO "Installing certbot"
  install_certbot
fi

EMAIL="${CERTBOT_EMAIL:-admin@${PRIMARY_DOMAIN}}"

if [[ -d "/etc/letsencrypt/live/${PRIMARY_DOMAIN}" ]]; then
  log INFO "Certificate already exists for ${PRIMARY_DOMAIN}, skipping issuance."
else
  log INFO "Requesting certificates for ${PRIMARY_DOMAIN} and wildcard"
  certbot --nginx --non-interactive --agree-tos --email "$EMAIL" \
    -d "$PRIMARY_DOMAIN" -d "*.${PRIMARY_DOMAIN}" >>"$LOG_FILE" 2>&1 || {
      log ERROR "Certbot issuance failed. Check ${LOG_FILE} for details."
      exit 1
    }
fi

log INFO "Configuring automatic certificate renewal"
cat >/etc/cron.d/infra-certbot <<CRON
SHELL=/bin/bash
0 3 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx"
CRON

log INFO "Certbot setup complete"
