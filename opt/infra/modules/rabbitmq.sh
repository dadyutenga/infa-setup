#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_os
ensure_root

case "$OS_ID" in
  debian|ubuntu)
    apt_install rabbitmq-server
    ;;
  almalinux)
    dnf_install rabbitmq-server
    ;;
  *)
    log ERROR "RabbitMQ installation unsupported on ${OS_ID}"
    exit 1
    ;;
esac

systemctl_enable_start rabbitmq-server

log INFO "Enabling RabbitMQ management plugin"
rabbitmq-plugins enable --offline rabbitmq_management >>"$LOG_FILE" 2>&1 || true
systemctl restart rabbitmq-server >>"$LOG_FILE" 2>&1

USER="${RABBITMQ_USER:-infra_admin}"
PASSWORD="${RABBITMQ_PASSWORD:-$(random_password)}"
VHOST="${RABBITMQ_VHOST:-/infra}"

if rabbitmqctl list_users | grep -q "^${USER}\b"; then
  log INFO "RabbitMQ user ${USER} already exists"
  rabbitmqctl change_password "$USER" "$PASSWORD" >>"$LOG_FILE" 2>&1
else
  log INFO "Creating RabbitMQ user ${USER}"
  rabbitmqctl add_user "$USER" "$PASSWORD" >>"$LOG_FILE" 2>&1
fi

if ! rabbitmqctl list_vhosts | grep -q "^${VHOST}$"; then
  log INFO "Creating RabbitMQ vhost ${VHOST}"
  rabbitmqctl add_vhost "$VHOST" >>"$LOG_FILE" 2>&1
fi

rabbitmqctl set_permissions -p "$VHOST" "$USER" '.*' '.*' '.*' >>"$LOG_FILE" 2>&1
rabbitmqctl set_user_tags "$USER" administrator >>"$LOG_FILE" 2>&1

cat >/opt/infra/rabbitmq-credentials.env <<ENV
RABBITMQ_USER=${USER}
RABBITMQ_PASSWORD=${PASSWORD}
RABBITMQ_VHOST=${VHOST}
ENV
chmod 600 /opt/infra/rabbitmq-credentials.env

log INFO "RabbitMQ configured"
