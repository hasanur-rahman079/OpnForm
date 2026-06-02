# Dokploy Deployment Guide

This guide covers deploying OpnForm using [Dokploy](https://dokploy.com), a self-hosted PaaS that manages Docker Compose applications.

## Prerequisites

- A Dokploy instance with a server connected
- A domain name pointing to your server (for production)
- Git repository access (your OpnForm fork)

## Quick Start

### 1. Create a New Application in Dokploy

1. Go to **Applications** → **Create Application**
2. Give it a name (e.g., "opnform")
3. Point it to your OpnForm git repository
4. For the compose file, select `docker-compose.dokploy.yml`

### 2. Generate Secrets

Run this on your local machine (requires `openssl`):

```bash
bash scripts/generate-dokploy-secrets.sh
```

You'll get output like:

```
APP_KEY=base64:abc123...
JWT_SECRET=xYz789...
FRONT_API_SECRET=def456...
NUXT_API_SECRET=def456...
```

Note: `FRONT_API_SECRET` and `NUXT_API_SECRET` are the same value — this is intentional. They form a shared secret between the API and frontend.

### 3. Configure Environment Variables

In Dokploy's **Environment** tab, add the following variables:

#### Required (copy from step 2)

| Variable | Value |
|---|---|
| `APP_KEY` | Paste from script output |
| `JWT_SECRET` | Paste from script output |
| `FRONT_API_SECRET` | Paste from script output |
| `NUXT_API_SECRET` | Paste from script output |
| `APP_URL` | `https://your-domain.com` |
| `DB_PASSWORD` | Choose a strong database password |

#### Optional (override defaults)

| Variable | Default | Notes |
|---|---|---|
| `DB_DATABASE` | `forge` | Database name |
| `DB_USERNAME` | `forge` | Database user |
| `APP_NAME` | `OpnForm` | Application display name |
| `APP_PORT` | `80` | Public HTTP port |
| `NGINX_MAX_BODY_SIZE` | `64m` | Max file upload size |

### 4. Deploy

Click **Deploy**. Dokploy will:

1. Clone your repository
2. Build the Docker images (this takes a few minutes on first run)
3. Start all 7 services
4. Run database migrations automatically

Wait for all services to show as **healthy**, then visit your domain.

## Architecture

The stack consists of 7 containers:

| Service | Image | Purpose |
|---|---|---|
| `db` | `postgres:16` | Primary database |
| `redis` | `redis:7` | Cache, queue, and session store |
| `api` | Built from `./api` | Laravel PHP-FPM backend |
| `api-worker` | Same as api | Async queue worker |
| `api-scheduler` | Same as api | Scheduled tasks (cleanup, telemetry) |
| `ui` | Built from `./client` | Nuxt 3 SSR frontend |
| `ingress` | Built from `./docker` | NGINX reverse proxy |

Volumes are used for PostgreSQL data, Redis data, and uploaded files (storage). These persist across redeploys.

## Environment Variables Reference

### Tier 1 — Required (no defaults)

These must be set in Dokploy's Environment tab:

- `APP_KEY` — Laravel encryption key (format: `base64:<32-bytes>`)
- `JWT_SECRET` — JWT token signing key
- `FRONT_API_SECRET` — API-side shared secret for frontend-auth
- `NUXT_API_SECRET` — Client-side shared secret (must equal `FRONT_API_SECRET`)

### Tier 2 — Infrastructure (recommend changing defaults)

- `APP_URL` (default: `http://localhost`) — Public URL of your instance
- `DB_DATABASE` (default: `forge`)
- `DB_USERNAME` (default: `forge`)
- `DB_PASSWORD` (default: `forge`) — **Change this for production**
- `REDIS_PASSWORD` (default: empty)

### Tier 3 — Application Tuning

- `APP_ENV` (default: `production`)
- `APP_DEBUG` (default: `false`)
- `CACHE_DRIVER` (default: `redis`)
- `QUEUE_CONNECTION` (default: `redis`)
- `SESSION_DRIVER` (default: `redis`)
- `FILESYSTEM_DRIVER` (default: `local`)
- `JWT_TTL` (default: `1440` minutes)
- `LOG_CHANNEL` (default: `errorlog`)
- `PHP_MEMORY_LIMIT` (default: `1G`)
- `PHP_MAX_EXECUTION_TIME` (default: `600`)
- `PHP_UPLOAD_MAX_FILESIZE` (default: `64M`)
- `PHP_POST_MAX_SIZE` (default: `64M`)
- `SHOW_OFFICIAL_TEMPLATES` (default: `true`)
- `OPNFORM_ANONYMOUS_TELEMETRY_DISABLED` (default: `false`)

### Tier 4 — Optional Integrations

Mail, captcha, AI, OAuth, S3, and other integrations — leave empty if not using.

| Variable | Purpose |
|---|---|
| `MAIL_MAILER` | `smtp` for real email (default: `log`) |
| `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_ENCRYPTION` | SMTP settings |
| `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME` | Sender address |
| `H_CAPTCHA_SITE_KEY`, `H_CAPTCHA_SECRET_KEY` | hCaptcha |
| `RE_CAPTCHA_SITE_KEY`, `RE_CAPTCHA_SECRET_KEY` | reCaptcha |
| `OPEN_AI_API_KEY` | OpenAI for AI form generation |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | Google OAuth login |
| `GOOGLE_FONTS_API_KEY` | Google Fonts in form builder |
| `TELEGRAM_BOT_ID`, `TELEGRAM_BOT_TOKEN` | Telegram notifications |
| `SLACK_BOT_TOKEN` | Slack notifications |
| `STRIPE_KEY`, `STRIPE_SECRET`, `STRIPE_WEBHOOK_SECRET` | Stripe payments |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `AWS_BUCKET` | S3 file storage |
| `SENTRY_LARAVEL_DSN`, `SENTRY_DSN_PUBLIC` | Error tracking |
| `IPINFO_TOKEN` | IP geolocation |
| `ZAPIER_ENABLED` | Zapier integration (set to `true`) |

## Using Pre-Built Images

By default, the compose file builds from source using `build:` sections. To use pre-built Docker Hub images instead (faster deploys, no build step), edit `docker-compose.dokploy.yml`:

For `api`, `api-worker`, and `api-scheduler` services:
```yaml
# Comment out:
# build:
#   context: .
#   dockerfile: docker/Dockerfile.api

# Uncomment:
image: jhumanj/opnform-api:latest
```

For `ui`:
```yaml
# Comment out build: section
image: jhumanj/opnform-client:latest
```

For `ingress`:
```yaml
# Comment out build: section
image: nginx:1
# Note: using the plain nginx image requires mounting nginx.conf.
# The custom Dockerfile.nginx approach (build from source) is easier
# since it bakes the config into the image.
```

## Updating

When you want to update to the latest OpnForm (or your fork):

1. Pull upstream changes: `git pull upstream main` (or merge into your fork)
2. Resolve any merge conflicts
3. Push to your repository
4. In Dokploy, click **Redeploy**

Dokploy rebuilds images and restarts services. Database migrations run automatically on the new `api` container startup. Environment variables persist across redeploys — you don't need to reconfigure them.

## Backups

The following Docker volumes contain persistent data:

| Volume | Content | Backup Priority |
|---|---|---|
| `postgres-data` | All database tables | **Critical** — back up regularly |
| `opnform_storage` | User uploads, file cache | High |
| `redis-data` | Cache and session data | Low — can be recreated |

### Database Backup

```bash
# From the Dokploy server
docker exec opnform-db pg_dump -U forge forge > opnform-backup-$(date +%Y%m%d).sql
```

### Volume Backup

Dokploy provides built-in backup functionality. Configure it in the Dokploy UI under your application's **Backups** settings.

## Troubleshooting

### Services stuck on "starting"

Check the logs in Dokploy's **Logs** tab. Common issues:

- **API can't connect to DB**: Verify `DB_PASSWORD` is set correctly. The default is `forge`.
- **Missing secrets**: API container will fail if `APP_KEY`, `JWT_SECRET`, or `FRONT_API_SECRET` are not set.
- **Port conflict**: Change `APP_PORT` if port 80 is already in use.

### Database migrations fail

The API container runs `php artisan migrate --force` on startup. If this fails:

```bash
docker exec opnform-api php artisan migrate:status
```

Check for migration errors in the API container logs.

### "base64:" prefix on APP_KEY

Laravel expects the `APP_KEY` to use the format `base64:<random-bytes>`. The `generate-dokploy-secrets.sh` script produces this format automatically. If generating manually, use:

```bash
echo "base64:$(openssl rand -base64 32)"
```

### Frontend can't reach API

Check that `NUXT_PRIVATE_API_BASE` is set to `http://ingress/api` (the default). This is the internal Docker network URL the Nuxt server uses to reach the API.

### Custom domain SSL

OpnForm supports custom domains for forms. This requires configuring a Caddy reverse proxy in front of the ingress. See the main deployment documentation for Caddy setup instructions.
