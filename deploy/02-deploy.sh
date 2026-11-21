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
  echo "  DATABASE_URL, JWT_SECRET, QDRANT_API_URL, QDRANT_API_SECRET, GEMINI_API_KEY (or OPENAI_API_KEY with LLM_PROVIDER=openai)" >&2
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

echo "==> Building the website and the admin dashboard"
# Built inside a throwaway Node container so the VPS needs no Node install. Output goes to
# /var/www/tutoria, which Nginx serves directly: the site at /, the dashboard at /admin.
WEB_ROOT=/var/www/tutoria
rm -rf admin/dist
docker run --rm -v "$REPO_ROOT/admin":/app -w /app -e VITE_API_URL=/api node:22-alpine \
  sh -c "npm install -g pnpm@10 >/dev/null && pnpm install --frozen-lockfile && pnpm build"
mkdir -p "$WEB_ROOT"
rm -rf "$WEB_ROOT/admin"
cp -r site/. "$WEB_ROOT/"
cp -r admin/dist "$WEB_ROOT/admin"
# the container ran as root; hand the build output back so later git/pnpm runs aren't blocked
chown -R "$(stat -c '%u:%g' "$REPO_ROOT")" admin/dist admin/node_modules 2>/dev/null || true
chmod -R a+rX "$WEB_ROOT"

echo "==> Writing Nginx site config for $DOMAIN"
cat > "/etc/nginx/sites-available/$DOMAIN" <<NGINX
server {
    listen 80;
    server_name $DOMAIN;
    # Homework photos and voice recordings are uploads; nginx's 1 MB default would reject them.
    client_max_body_size 12m;

    root /var/www/tutoria;

    # The public website and its legal pages.
    location = / { try_files /index.html =404; }
    location ~ ^/(privacy|terms)/?$ { try_files /\$1/index.html =404; }
    location = /style.css { expires 1h; }
    location = /Nunito-Variable.ttf { expires 30d; }
    location /img/ { expires 30d; }

    # The admin dashboard (a single-page app). It reaches the API through /api below, because
    # the API's own /admin/... routes would otherwise collide with this path.
    location = /admin { return 301 /admin/; }
    location /admin/ { try_files \$uri \$uri/ /admin/index.html; }
    location /admin/assets/ { expires 1y; add_header Cache-Control "public, immutable"; }

    # /api/foo -> the server's /foo (used by the dashboard).
    location /api/ {
        rewrite ^/api/(.*)\$ /\$1 break;
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 60s;
    }

    # Everything else is the API the mobile app talks to, unchanged.
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
echo " Deployed. https://$DOMAIN   (admin: https://$DOMAIN/admin/)"
echo "============================================================"
echo ""
echo "Point the Flutter app's API_BASE_URL at:  https://$DOMAIN"
echo "Certbot installed a systemd timer for automatic renewal — nothing more to do there."
echo "============================================================"
