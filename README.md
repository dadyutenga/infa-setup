# Infra Setup Automation Toolkit

This repository provisions a complete server stack on supported Linux distributions with a single non-interactive command. The master script detects the operating system, installs required repositories, configures services, and enables firewalls without ever prompting for user input.

## ✅ Supported Operating Systems

| Distribution | Minimum Version | Package Manager |
|--------------|-----------------|-----------------|
| Debian       | 11 (Bullseye)   | apt |
| Debian       | 12 (Bookworm)   | apt |
| Ubuntu       | 20.04 LTS       | apt |
| Ubuntu       | 22.04 LTS       | apt |
| AlmaLinux    | 9               | dnf |

The script exits with a clear error if it encounters an unsupported platform.

## 🚀 Quick Start

```bash
git clone <repo-url>/infra-setup.git
cd infra-setup
sudo ./infra-setup.sh
```

Running as `root` or through `sudo` is required because packages, services, and firewall rules are managed system-wide. No environment variables or interactive answers are needed.

## 🔄 What Gets Installed

Modules execute sequentially to provide the following components:

| Order | Module | Purpose |
|-------|--------|---------|
| 1 | `os-detect` | Identify distribution, version, and package manager |
| 2 | `docker` | Install Docker Engine, Buildx, and Compose plugin from official repositories |
| 3 | `nginx` | Install and enable the Nginx web server |
| 4 | `mysql` | Install MySQL Server (MariaDB on AlmaLinux) |
| 5 | `postgres` | Install PostgreSQL server and contrib packages |
| 6 | `redis` | Install Redis server |
| 7 | `rabbitmq` | Install RabbitMQ server from official repositories and enable management plugin |
| 8 | `languages` | Install Node.js LTS, Python 3, Go (latest), and PHP 8.3 with common extensions |
| 9 | `uptime-kuma` | Deploy Uptime-Kuma into `/opt/uptime-kuma` with a systemd service |
| 10 | `firewall` | Configure UFW (Debian/Ubuntu) or firewalld (AlmaLinux) with required ports |

Each module checks whether the target software already exists. If it does, the module prints `[SKIP]` and moves on after ensuring the associated service is enabled.

## 📝 Logging

- **Global log:** `logs/infra-install.log` captures every console message across runs.
- **Module logs:** `logs/<module>.log` include detailed command output for each module execution.

Log files are overwritten on each run to keep the repository tidy. Retain copies if you need historical records.

## 🔐 Firewall Rules

The `firewall` module automatically opens the following TCP ports:

- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)
- 3001 (Uptime-Kuma)
- 5672 (RabbitMQ)
- 6379 (Redis)

UFW is used on Debian/Ubuntu systems and firewalld is used on AlmaLinux.

## 🧰 Repository Layout

```
infra-setup.sh        # Master entrypoint
logs/                 # Log directory (populated at runtime)
modules/
  os-detect.sh
  docker.sh
  nginx.sh
  mysql.sh
  postgres.sh
  redis.sh
  rabbitmq.sh
  languages.sh
  uptime-kuma.sh
  firewall.sh
```

Clone, execute, and receive a fully bootstrapped infrastructure stack with zero manual steps.
