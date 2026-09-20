#!/usr/bin/env bash
#
# One-time VPS provisioning: Docker, native PostgreSQL, Nginx, Certbot, firewall.
# Run once on a fresh Ubuntu/Debian VPS, as root (or via sudo).
#
# Usage: sudo ./01-vps-setup.sh
#
# After this, run 02-deploy.sh to build/start the app and set up the domain + SSL.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run this as root (sudo ./01-vps-setup.sh)" >&2
  exit 1
fi

echo "==> Updating system packages"
apt-get update -y
apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg ufw openssl

echo "==> Installing Docker Engine + Compose plugin"
if ! command -v docker &>/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
else
  echo "Docker already installed, skipping."
fi

echo "==> Installing PostgreSQL (native, not containerized)"
if ! command -v psql &>/dev/null; then
  apt-get install -y postgresql postgresql-contrib
fi
systemctl enable --now postgresql

PG_VERSION=$(psql -V | grep -oP '\d+' | head -1)
PG_CONF_DIR="/etc/postgresql/${PG_VERSION}/main"

if [[ ! -d "$PG_CONF_DIR" ]]; then
  echo "Could not find Postgres config dir at $PG_CONF_DIR — check your Postgres version/paths manually." >&2
  exit 1
fi

echo "==> Configuring PostgreSQL to accept connections from Docker containers"
# listen on all interfaces (the Docker bridge included) — not exposed publicly since
# we never open 5432 in the firewall below, only local/Docker-bridge traffic can reach it.
sed -i "s/^#\?listen_addresses.*/listen_addresses = '*'/" "$PG_CONF_DIR/postgresql.conf"

# Allow the default Docker bridge subnet to authenticate with a password. This covers
# both the docker0 bridge (172.17.0.0/16) and Compose's per-project bridges (172.18-31.x),
# which is what `host.docker.internal` resolves through via the extra_hosts host-gateway.
if ! grep -q "docker-bridge-access" "$PG_CONF_DIR/pg_hba.conf"; then
  {
    echo "# docker-bridge-access — added by 01-vps-setup.sh"
    echo "host    all             all             172.16.0.0/12           scram-sha-256"
  } >> "$PG_CONF_DIR/pg_hba.conf"
fi

systemctl restart postgresql

echo "==> Creating the tutoria database + role"
DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -base64 24 | tr -d '/+=\n')}"

sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'tutoria') THEN
    CREATE ROLE tutoria WITH LOGIN PASSWORD '${DB_PASSWORD}';
  ELSE
    ALTER ROLE tutoria WITH PASSWORD '${DB_PASSWORD}';
  END IF;
END
\$\$;
SQL

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='tutoria'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE DATABASE tutoria OWNER tutoria;"
fi

echo "==> Installing Nginx + Certbot"
apt-get install -y nginx certbot python3-certbot-nginx

echo "==> Configuring firewall (ufw)"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo ""
echo "============================================================"
echo " VPS provisioning complete."
echo "============================================================"
echo ""
echo "Postgres database 'tutoria' created. Your DATABASE_URL is:"
echo ""
echo "  postgresql://tutoria:${DB_PASSWORD}@host.docker.internal:5432/tutoria?schema=public"
echo ""
echo "Save that now — the password is not stored anywhere else by this script."
echo "Put it in the repo's root .env file (see .env.example) along with your"
echo "other secrets (JWT_SECRET, QDRANT_*, GEMINI_*), then run 02-deploy.sh."
echo ""
echo "Before running 02-deploy.sh: point your domain's DNS A record at this"
echo "server's IP address, or the SSL step will fail."
echo "============================================================"
