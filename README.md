# Infra Setup Automation Toolkit

This repository delivers a fully self-contained infrastructure automation toolkit. Clone it, run a single script, and receive a production-ready stack featuring containers, web serving, databases, messaging, language runtimes, observability, and firewalling. All activity and generated credentials stay within the repository's `logs/` directory for easy auditing.

## ✅ Supported Operating Systems

| Distribution | Minimum Version | Notes |
|--------------|-----------------|-------|
| Ubuntu       | 20.04 LTS       | 22.04+ recommended for newer packages |
| Debian       | 11 (Bullseye)   | Works with Debian 12 out of the box |
| AlmaLinux    | 9               | Uses DNF, Remi repo for PHP 8.3 |

The toolkit automatically stops with a helpful error if it encounters an unsupported platform.

## 🚀 Quick Start

```bash
git clone https://example.com/infra-setup.git
cd infra-setup
sudo ./infra-setup.sh
```

During execution you will be prompted for:

1. **Primary domain** – used for Nginx vhosts and Let's Encrypt certificates (`api`, `app`, `admin`, `billing`, `files` subdomains are generated automatically).
2. **Email address** – optional, forwarded to Certbot for renewal notices.

The script must run with `sudo` or as `root`. All actions take place relative to the cloned directory, apart from OS package installations and the required `/opt/uptime-kuma` deployment.

## 🧩 Module Overview

Modules execute in the following order. Each module is idempotent and safe to re-run; reruns simply skip already configured components.

| Order | Module | Purpose |
|-------|--------|---------|
| 1 | `os-detect` | Identify distribution, version, and package manager |
| 2 | `docker` | Install Docker Engine and Compose plugin from official repositories |
| 3 | `nginx` | Install Nginx, provision five subdomains, and route logs to `logs/nginx/` |
| 4 | `certbot` | Issue Let's Encrypt certificates and configure automatic renewal |
| 5 | `mysql` | Install MySQL Server (or MariaDB on AlmaLinux) |
| 6 | `mysql-hardening` | Apply secure defaults, rotate root password, create application DB/user |
| 7 | `postgres` | Install PostgreSQL server and start service |
| 8 | `postgres-superuser` | Create/update a secure PostgreSQL superuser |
| 9 | `redis` | Install Redis, enforce local binding, generate access password |
| 10 | `rabbitmq` | Install RabbitMQ, enable management plugin, create administrator |
| 11 | `languages` | Install Node.js LTS, Python 3.12, Go latest, PHP 8.3 with common extensions |
| 12 | `uptime-kuma` | Deploy Uptime-Kuma under `/opt/uptime-kuma` with a systemd service |
| 13 | `firewall` | Configure UFW (Debian/Ubuntu) or Firewalld (AlmaLinux) for common ports |

## 🔧 Customising the Run

### Skipping Modules

Set the `SKIP_MODULES` environment variable before launching the master script. Provide a comma-separated list using module names from the table above (case-insensitive).

```bash
sudo SKIP_MODULES="certbot,uptime-kuma" ./infra-setup.sh
```

`os-detect` is mandatory and cannot be skipped.

### Updating Modules

Each module lives in `modules/<name>.sh`. To update behaviour:

1. Edit the relevant module file.
2. Commit the changes to version control.
3. Re-run `sudo ./infra-setup.sh` – the toolkit automatically picks up your edits.

For one-off experiments, you can run a module directly (they respect the same logging helpers):

```bash
sudo bash -c "source modules/<module>.sh && run_<module>()"
```

## 📝 Logging & Credentials

- Global execution log: `logs/infra-setup-<timestamp>.log` (auto-generated per run).
- Module-specific logs: `logs/<module>-<timestamp>.log`.
- Sensitive credentials (MySQL root/app users, PostgreSQL superuser, Redis password, RabbitMQ admin) are **only** written to their respective module logs; they are not echoed to the console.
- Nginx virtual host access/error logs are redirected to `logs/nginx/` inside the repository.
- The most recent MySQL credentials are also persisted in `logs/mysql-root-latest.txt` for idempotent re-runs.

Rotate or purge the `logs/` directory when you no longer need historical data.

## 🔄 Rerunning Safely

The scripts are idempotent:

- Installed packages are detected and skipped.
- Existing configuration files are updated in place.
- Re-running hardening modules regenerates credentials and records them in fresh logs.
- Certbot renewals are safe; certificates will be reused where valid.

## 🛠 Troubleshooting Tips

| Symptom | Suggested Action |
|---------|------------------|
| `Unsupported distribution` error | Verify you are on Ubuntu ≥20.04, Debian ≥11, or AlmaLinux 9. |
| Certbot failures | Confirm DNS is pointed at this server and ports 80/443 are reachable. Re-run `sudo ./infra-setup.sh` after fixing DNS. |
| Package install timeouts | Ensure outbound HTTPS is allowed to Docker, NodeSource, Sury/Remi, and Go download endpoints. |
| Service fails to start | Check `logs/<module>-<timestamp>.log` first, then systemd journals (`sudo journalctl -u <service>`). |
| Firewall blocks traffic | Re-run the script or manually adjust UFW/Firewalld rules for your custom ports. |

## 🔒 Disabling Optional Components

If you decide later that a component is unnecessary:

1. Stop and disable the related service (`systemctl disable --now <service>`).
2. Remove its configuration files (e.g., `/etc/nginx/sites-available/*`).
3. Delete or archive the module log from `logs/` if credentials are no longer needed.
4. Optionally add the module name to `SKIP_MODULES` before future runs to avoid reconfiguration.

## ♻️ Keeping Dependencies Fresh

- **Docker**: rerun the toolkit; it fetches the latest packages from Docker's official repositories.
- **Language runtimes**: the `languages` module downloads current releases of Go and rebuilds Python 3.12. Edit version constants if you need a specific patch release.
- **Uptime-Kuma**: rerun the module to execute `git pull` and re-run `npm install`.

## 📂 Repository Layout

```
infra-setup.sh        # Master entrypoint
logs/                 # Global and module logs (generated automatically)
modules/
  os-detect.sh
  docker.sh
  nginx.sh
  certbot.sh
  mysql.sh
  mysql-hardening.sh
  postgres.sh
  postgres-superuser.sh
  redis.sh
  rabbitmq.sh
  languages.sh
  uptime-kuma.sh
  firewall.sh
  nginx-templates/
    admin.conf
    api.conf
    app.conf
    billing.conf
    files.conf
```

Clone, run, and enjoy an instantly provisioned DevOps stack with full transparency and localised logging.
