#!/usr/bin/env bash
#
# Build + start the app, configure Nginx as reverse proxy, and get an SSL cert.
# Run this from inside the repo root, after 01-vps-setup.sh, and after your .env
# file (root of the repo, based on .env.example) is filled in with real secrets.
#
# Re-run any time you deploy an update (git pull already done, or do it first).
#
# Usage:
#   sudo DOMAIN=tutoria.abubakarmunir.dev EMAIL=you@example.com ./deploy/02-deploy.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run this as root (sudo ./deploy/02-deploy.sh)" >&2
  exit 1
fi

DOMAIN="${DOMAIN:-tutoria.abubakarmunir.dev}"
EMAIL="${EMAIL:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -f .env ]]; then
  echo "No .env file at repo root. Copy .env.example to .env and fill in real values first:" >&2
  echo "  DATABASE_URL, JWT_SECRET, QDRANT_API_URL, QDRANT_API_SECRET, GEMINI_API_KEY" >&2
  exit 1
fi

if [[ -z "$EMAIL" ]]; then
  echo "Set EMAIL (for Let's Encrypt registration/renewal notices), e.g.:" >&2
  echo "  sudo EMAIL=you@example.com ./deploy/02-deploy.sh" >&2
  exit 1
fi

echo "==> Building and starting the app (server + ai-service)"
docker compose build
docker compose up -d

echo "==> Waiting for the server to respond on 127.0.0.1:3001"
for _ in $(seq 1 30); do
  if curl -sSf http://127.0.0.1:3001 >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "==> Writing Nginx site config for $DOMAIN"
cat > "/etc/nginx/sites-available/$DOMAIN" <<NGINX
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        # generous timeout — chat requests go through Qdrant + Gemini and can take a while
        proxy_read_timeout 60s;
    }
}
NGINX

ln -sf "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-enabled/$DOMAIN"
nginx -t
systemctl reload nginx

echo "==> Requesting SSL certificate for $DOMAIN"
echo "    (make sure its DNS A record already points at this server's IP, or this fails)"
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect

echo ""
echo "============================================================"
echo " Deployed. https://$DOMAIN"
echo "============================================================"
echo ""
echo "Point the Flutter app's API_BASE_URL at:  https://$DOMAIN"
echo "Certbot installed a systemd timer for automatic renewal — nothing more to do there."
echo "============================================================"
