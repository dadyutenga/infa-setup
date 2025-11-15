# Infrastructure Setup Automation

This repository provides an OS-aware, idempotent infrastructure automation toolkit capable of provisioning production-ready services on:

- Debian 12 (primary target)
- Debian 11
- Ubuntu 20.04 / 22.04 / 24.04
- AlmaLinux 9

All actions are logged to `/var/log/infra-setup.log` and are safe to re-run.

## Features

- Automatic OS detection with module skip support
- Docker Engine & Compose plugin from official repositories
- Nginx virtual host provisioning with multi-subdomain templates
- Certbot SSL issuance & automated renewals
- MySQL/MariaDB installation plus hardened configuration helper
- PostgreSQL installation with secure superuser bootstrap script
- Redis & RabbitMQ hardening for production workloads
- Language runtimes: Node.js 20.x, Python 3.12, Go 1.22, PHP 8.3
- Uptime Kuma deployment with systemd service
- Firewall configuration using UFW (Debian/Ubuntu) or firewalld (AlmaLinux)

## Repository Layout

```
opt/
  infra/
    infra-setup.sh          # Master entrypoint
    mysql-hardening.sh      # Harden MySQL/MariaDB installations
    postgres-setup.sh       # PostgreSQL superuser/database helper
    modules/                # All setup modules sourced by the master script
```

## Prerequisites

Run the toolkit as `root` on a fresh server. For remote SSH sessions, use `sudo su -` before executing the scripts.

Ensure outbound HTTPS access for package repositories (Docker, NodeSource, Sury, Remi, etc.).

## Usage

1. Copy the `opt/infra` directory to `/opt/infra` on the target host.
2. Run the master script:

```bash
sudo /opt/infra/infra-setup.sh --domain example.com --subdomains "api,app,admin,billing,files"
```

### Command-line options

- `--domain` &mdash; Primary domain used for Nginx and Certbot provisioning.
- `--subdomains` &mdash; Comma-separated list of additional subdomains. Defaults to `api,app,admin,billing,files`.
- `--skip` &mdash; Comma-separated module names to skip (e.g. `--skip certbot,mysql`).

Modules available for skipping: `docker`, `nginx`, `certbot`, `mysql`, `mysql-hardening`, `postgres`, `redis`, `rabbitmq`, `languages`, `uptime-kuma`, `firewall`.

### Environment Variables

- `CERTBOT_EMAIL` &mdash; Email address for certificate registration (default: `admin@<domain>`).
- `MYSQL_ROOT_PASSWORD`, `MYSQL_APP_USER`, `MYSQL_APP_DB`, `MYSQL_APP_PASSWORD` &mdash; Override MySQL hardening credentials.
- `REDIS_MAXMEMORY` &mdash; Override Redis `maxmemory` (default: `256mb`).
- `RABBITMQ_USER`, `RABBITMQ_PASSWORD`, `RABBITMQ_VHOST` &mdash; Customize RabbitMQ provisioning.

## Generated Artifacts

- `/etc/nginx/sites-available/<domain>.conf` + symlinks in `sites-enabled`
- `/etc/cron.d/infra-certbot` for SSL renewals
- `/opt/infra/mysql-credentials.env` and `/opt/infra/postgres-superuser.env`
- `/opt/infra/rabbitmq-credentials.env`
- `/etc/systemd/system/uptime-kuma.service`
- `/etc/profile.d/go.sh` exporting the Go toolchain path

## Re-running

The automation is idempotent. Re-running `infra-setup.sh` will detect existing installations and skip or update them safely, preserving credentials and configuration.

## Support

Review `/var/log/infra-setup.log` for detailed execution output. Each module logs its activity, making troubleshooting straightforward.
