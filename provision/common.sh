#!/bin/bash
set -e

echo "=== Common provisioning ==="

# Обновление системы и базовые утилиты
apt update && apt upgrade -y

apt install -y \
  curl wget git vim htop net-tools \
  ca-certificates gnupg lsb-release

# Docker
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com | sh
  usermod -aG docker vagrant
fi

# Docker Compose
if ! command -v docker-compose &> /dev/null; then
  curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) \
    -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

echo "=== Common provisioning done ==="
