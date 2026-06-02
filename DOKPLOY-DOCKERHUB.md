# Dokploy + Docker Hub Deployment Plan

## Why

The Nuxt SSR build needs 8GB+ memory. Your VPS has 8GB total and runs other apps.
Build images on a machine with enough RAM (your local WSL), push to Docker Hub,
then Dokploy just pulls and runs — no build step on the VPS.

## Architecture

```
┌─────────────────────┐     docker push     ┌──────────────┐
│  Local WSL (12GB)   │ ──────────────────> │  Docker Hub  │
│  Build images here  │                     │              │
└─────────────────────┘                     └──────┬───────┘
                                                   │ docker pull
                                                   ▼
                                            ┌──────────────┐
                                            │  Dokploy VPS │
                                            │  (2 vCPU,    │
                                            │   8 GB RAM)  │
                                            │  Run only    │
                                            └──────────────┘
```

## Step 1 — Build images locally

```bash
# Set required env vars
export APP_KEY="base64:$(openssl rand -base64 32)"
export JWT_SECRET="$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 40)"
export FRONT_API_SECRET="$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 40)"
export NUXT_API_SECRET="$FRONT_API_SECRET"
export APP_URL="https://your-domain.com"
export DB_PASSWORD="forge"
export NODE_MEMORY=8192

# Build all images
docker compose -f docker-compose.dokploy.yml build
```

## Step 2 — Push to Docker Hub

```bash
# Login (if not already)
docker login

# Tag images with your Docker Hub username
docker tag opnform-api:latest       yourusername/opnform-api:latest
docker tag opnform-ui:latest        yourusername/opnform-client:latest

# Push
docker push yourusername/opnform-api:latest
docker push yourusername/opnform-client:latest
```

## Step 3 — Switch compose file to pre-built images

Edit `docker-compose.dokploy.yml`. For each service, comment out `build:` and uncomment `image:`:

```yaml
# api service
  api:
    # build:                          # <-- comment this
    #   context: .
    #   dockerfile: docker/Dockerfile.api
    image: yourusername/opnform-api:latest  # <-- uncomment this

# api-worker service (same change)
# api-scheduler service (same change)

# ui service
  ui:
    # build:                          # <-- comment this
    #   context: .
    #   dockerfile: docker/Dockerfile.client
    image: yourusername/opnform-client:latest  # <-- uncomment this

# ingress — keep building from source (it's 2 lines, instant)
```

## Step 4 — Deploy on Dokploy

1. Push the updated compose file to your repo
2. In Dokploy's **Environment** tab, set:
   - `APP_KEY`, `JWT_SECRET`, `FRONT_API_SECRET`, `NUXT_API_SECRET` (from step 1)
   - `APP_URL=https://your-domain.com`
   - `DB_PASSWORD=<strong-password>`
3. In Dokploy's **Domain** tab, add your domain pointing to `ingress` port `80`
   - Dokploy's built-in Traefik handles SSL and routes traffic internally
   - No host port binding needed — no port conflicts with other apps
4. Deploy — Dokploy pulls images and starts containers (no build)

## Runtime resources (on VPS)

| Service | RAM (idle) |
|---|---|
| nuxt client | ~215 MB |
| postgres | ~70 MB |
| php-fpm api | ~62 MB |
| queue worker | ~58 MB |
| scheduler | ~45 MB |
| nginx | ~8 MB |
| redis | ~5 MB |
| **Total** | **~460 MB** |

Under moderate load: **1-1.5 GB**. Peak: **~2 GB**.

## Updating

When you want to update OpnForm:

1. Pull latest changes: `git pull upstream main`
2. Rebuild locally: `docker compose -f docker-compose.dokploy.yml build --no-cache`
3. Push new images: `docker push yourusername/opnform-api:latest && docker push yourusername/opnform-client:latest`
4. In Dokploy, click **Redeploy**

## Alternative — GitHub Actions (free CI builds)

Instead of building locally, use GitHub Actions to build and push images automatically on every push. See the [GitHub Actions setup guide](https://docs.github.com/en/actions/publishing-packages/publishing-docker-images) for publishing to GitHub Container Registry (ghcr.io). This eliminates the local build step entirely.
