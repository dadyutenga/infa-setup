#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] Docker is required for Uptime-Kuma"
  return 1
fi

if docker ps -a --format '{{.Names}}' | grep -qw uptime-kuma; then
  echo "[SKIP] Uptime-Kuma container already exists"
  return 0
fi

echo "[INFO] Deploying Uptime-Kuma container"
mkdir -p /opt/uptime-kuma

docker run -d --restart=always \
  -p 3001:3001 \
  -v /opt/uptime-kuma:/app/data \
  --name uptime-kuma \
  louislam/uptime-kuma:latest

echo "[OK] Uptime-Kuma container deployed"
