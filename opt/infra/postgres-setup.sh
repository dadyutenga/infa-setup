#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/infra-setup.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
mkdir -p /opt/infra

usage() {
  cat <<USAGE
Usage: $0 [--superuser <name>] [--database <db>] [--password <password>]
Creates or updates a PostgreSQL superuser and optionally a database.
USAGE
}

SUPERUSER="infra_admin"
DATABASE="appdb"
PASSWORD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --superuser)
      SUPERUSER="$2"
      shift 2
      ;;
    --database)
      DATABASE="$2"
      shift 2
      ;;
    --password)
      PASSWORD="$2"
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

if [[ -z "$PASSWORD" ]]; then
  PASSWORD="$(random_password)"
fi

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script as root" >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql command not found" >&2
  exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Configuring PostgreSQL" | tee -a "$LOG_FILE" >/dev/null

sudo -u postgres psql <<SQL
DO
$$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${SUPERUSER}') THEN
      CREATE ROLE ${SUPERUSER} WITH LOGIN SUPERUSER CREATEDB CREATEROLE PASSWORD '${PASSWORD}';
   ELSE
      ALTER ROLE ${SUPERUSER} WITH SUPERUSER CREATEDB CREATEROLE PASSWORD '${PASSWORD}';
   END IF;
END
$$;
SQL

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Superuser ${SUPERUSER} ensured" | tee -a "$LOG_FILE" >/dev/null

sudo -u postgres psql <<SQL
DO
$$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DATABASE}') THEN
      CREATE DATABASE ${DATABASE} OWNER ${SUPERUSER};
   END IF;
END
$$;
SQL

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Database ${DATABASE} ensured" | tee -a "$LOG_FILE" >/dev/null

cat >/opt/infra/postgres-superuser.env <<ENV
POSTGRES_SUPERUSER=${SUPERUSER}
POSTGRES_PASSWORD=${PASSWORD}
POSTGRES_DATABASE=${DATABASE}
ENV
chmod 600 /opt/infra/postgres-superuser.env

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] PostgreSQL configuration complete" | tee -a "$LOG_FILE" >/dev/null
