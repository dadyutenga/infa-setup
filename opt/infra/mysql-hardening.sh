#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/infra-setup.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
mkdir -p /opt/infra

usage() {
  cat <<USAGE
Usage: $0 [--root-password <password>] [--app-db <db>] [--app-user <user>] [--app-password <password>]

If parameters are omitted, secure random passwords will be generated automatically.
Credentials will be written to /opt/infra/mysql-credentials.env.
USAGE
}

ROOT_PASSWORD=""
APP_DB="app_db"
APP_USER="app_user"
APP_PASSWORD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root-password)
      ROOT_PASSWORD="$2"
      shift 2
      ;;
    --app-db)
      APP_DB="$2"
      shift 2
      ;;
    --app-user)
      APP_USER="$2"
      shift 2
      ;;
    --app-password)
      APP_PASSWORD="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

random_password() {
  tr -dc 'A-Za-z0-9!@#%^&*()_+-=' </dev/urandom | head -c 24
}

if [[ -z "$ROOT_PASSWORD" ]]; then
  ROOT_PASSWORD="$(random_password)"
fi

if [[ -z "$APP_PASSWORD" ]]; then
  APP_PASSWORD="$(random_password)"
fi

if [[ ${EUID} -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

MYSQL_BIN="$(command -v mysql || true)"
if [[ -z "$MYSQL_BIN" ]]; then
  echo "mysql command not found" >&2
  exit 1
fi

socket_exec() {
  "$MYSQL_BIN" --protocol=socket -uroot "$@"
}

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Starting MySQL hardening" | tee -a "$LOG_FILE" >/dev/null

if ! socket_exec -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${ROOT_PASSWORD}';" >/dev/null 2>&1; then
  socket_exec -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASSWORD}';" >/dev/null 2>&1 || true
fi
socket_exec -e "FLUSH PRIVILEGES;" >/dev/null 2>&1

mysql_exec() {
  "$MYSQL_BIN" --protocol=socket -uroot -p"${ROOT_PASSWORD}" "$@"
}

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Root password updated" | tee -a "$LOG_FILE" >/dev/null

mysql_exec <<'SQL'
DELETE FROM mysql.user WHERE User='';
SQL

mysql_exec <<'SQL'
DROP DATABASE IF EXISTS test;
SQL

mysql_exec <<'SQL'
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
SQL

mysql_exec <<'SQL'
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');
FLUSH PRIVILEGES;
SQL

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Removed test database and anonymous users" | tee -a "$LOG_FILE" >/dev/null

mysql_exec <<SQL
CREATE DATABASE IF NOT EXISTS \`$APP_DB\`;
CREATE USER IF NOT EXISTS '$APP_USER'@'%' IDENTIFIED BY '${APP_PASSWORD}';
GRANT ALL PRIVILEGES ON \`$APP_DB\`.* TO '$APP_USER'@'%';
FLUSH PRIVILEGES;
SQL

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Application database prepared" | tee -a "$LOG_FILE" >/dev/null

cat >/root/.my.cnf <<CNF
[client]
user=root
password=${ROOT_PASSWORD}
CNF
chmod 600 /root/.my.cnf

cat >/opt/infra/mysql-credentials.env <<ENV
ROOT_PASSWORD=${ROOT_PASSWORD}
APP_DB=${APP_DB}
APP_USER=${APP_USER}
APP_PASSWORD=${APP_PASSWORD}
MYSQL_HARDENED=1
ENV
chmod 600 /opt/infra/mysql-credentials.env

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] MySQL hardening complete" | tee -a "$LOG_FILE" >/dev/null
