# VPS Deployment

Two scripts, run in order, on a fresh Ubuntu/Debian VPS.

## Prerequisites

- A fresh Ubuntu or Debian VPS with root/sudo access
- This repo cloned onto it (`git clone git@github.com:abubakarmunir712/tutoria.git && cd tutoria`)
- Your domain's DNS A record pointed at the VPS's IP address (needed before step 2, for SSL)

## 1. Provision the machine (once)

```bash
sudo ./deploy/01-vps-setup.sh
```

Installs Docker, native PostgreSQL (not containerized — matches local dev), Nginx, Certbot, and configures the firewall. At the end it prints a `DATABASE_URL` with a freshly generated password — **copy it**, it's not saved anywhere else.

## 2. Configure secrets

```bash
cp .env.example .env
```

Fill in `.env` with:
- `DATABASE_URL` — from step 1's output
- `JWT_SECRET` — generate one: `openssl rand -hex 48`
- `QDRANT_API_URL`, `QDRANT_API_SECRET` — your Qdrant Cloud cluster
- `GEMINI_API_KEY` — your Gemini key

## 3. Deploy

```bash
sudo DOMAIN=tutoria.abubakarmunir.dev EMAIL=you@example.com ./deploy/02-deploy.sh
```

Builds and starts `server` + `ai-service` via Docker Compose, sets up Nginx as a reverse proxy (only the app port is bound to `127.0.0.1`, Nginx on 80/443 is the real public entry point), and gets an SSL cert via Certbot (auto-renews via the systemd timer Certbot installs).

## Redeploying after code changes

```bash
git pull
sudo ./deploy/02-deploy.sh   # DOMAIN/EMAIL only needed again if unset in your shell
```

`docker compose build` + `up -d` picks up the new code; Nginx/SSL config is untouched (safe to re-run, it's idempotent).
