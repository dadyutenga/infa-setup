# Infrastructure Setup Automation

This repository provisions a common infrastructure stack (Docker, Nginx, MariaDB, PostgreSQL, Redis, developer languages, Uptime-Kuma, and firewall hardening) across multiple Linux distributions with a single non-interactive script.

## Supported Operating Systems
- Debian 12 (primary target)
- Debian 11
- Ubuntu 20.04 LTS
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- AlmaLinux 9

## Quick Start
Clone the repository and run the master script with elevated privileges:

```bash
sudo ./infra-setup.sh
```

The script automatically detects the host operating system, installs each module only when required, and logs all actions. No user prompts are shown during execution.

## Repository Layout
```
infra-setup/
  infra-setup.sh         # Master automation script
  logs/                  # Aggregated and per-module logs
  modules/               # Self-contained module installers
    os-detect.sh         # OS detection and exports
    docker.sh            # Docker Engine + plugins
    nginx.sh             # Nginx web server
    mysql.sh             # MariaDB server
    postgres.sh          # PostgreSQL database
    redis.sh             # Redis cache
    languages.sh         # Node.js, Python, Go, PHP toolchain
    uptime-kuma.sh       # Uptime-Kuma container deployment
    firewall.sh          # UFW/Firewalld configuration
```

## Modules Overview
Each module is sourced by `infra-setup.sh`, logs to `logs/infra.log` and its own file in `logs/modules/`, and performs idempotent installation:

| Module | Description |
| ------ | ----------- |
| os-detect | Exports `OS_FAMILY` and `OS_VERSION` for downstream modules. |
| docker | Installs Docker Engine, Buildx, Compose plugin, and starts the daemon. |
| nginx | Installs and starts Nginx. |
| mysql | Installs MariaDB (or MySQL if present) and enables the service. |
| postgres | Installs PostgreSQL and initializes the service. |
| redis | Installs Redis and ensures it is running. |
| languages | Installs Node.js/npm, Python3/pip, Go (tarball), and PHP 8.3. |
| uptime-kuma | Deploys the Uptime-Kuma Docker container with persistent data under `/opt/uptime-kuma`. |
| firewall | Configures UFW (Debian/Ubuntu) or firewalld (AlmaLinux) with the required ports. |

Every module first checks whether its component already exists. When it is already present, the module prints `[SKIP]` and exits without changes.

## Logging
- `logs/infra.log` aggregates the combined output from all modules.
- `logs/modules/<module>.log` contains the detailed log for each individual module.
- Logs are appended on every run. Remove the files if you need a clean slate before re-running the installer.

## Customising Modules
The execution order is defined inside `infra-setup.sh` in the `modules` array. To disable a module temporarily, remove it from the list or comment it out:

```bash
modules=(
  "os-detect"
  "docker"
  # "nginx"        # Example: disable Nginx
  "mysql"
  ...
)
```

Ensure that `os-detect` remains first so that other modules receive `OS_FAMILY` and `OS_VERSION` exports.

## Troubleshooting
- **Script exits immediately**: Confirm you are running with `sudo` so that package managers and systemd can make changes.
- **Package installation fails**: Check the relevant log file under `logs/modules/` for detailed error output. Re-run after resolving repository or network issues.
- **Firewall configuration errors**: Ensure no other firewall service is conflicting (e.g., disable third-party firewalls before running the script).
- **Docker commands fail**: Verify that the Docker service is active (`systemctl status docker`) and re-run the module if needed.
- **Uptime-Kuma already running**: The module prints `[SKIP]` when the Docker container named `uptime-kuma` already exists.

## Updating the Repository
1. Pull the latest changes: `git pull`.
2. Review updates in `infra-setup.sh` and the `modules/` directory.
3. Run `sudo ./infra-setup.sh` again to apply enhancements. All modules remain idempotent and will skip components that are already present.

