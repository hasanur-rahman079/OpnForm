#!/bin/bash
set -e

echo "=== OpnForm Dokploy Secrets ==="
echo "Copy the following into the Dokploy Environment tab:"
echo ""

# 1. APP_KEY: Laravel encryption key (base64-prefixed 32-byte random)
APP_KEY="base64:$(openssl rand -base64 32)"
echo "APP_KEY=${APP_KEY}"

# 2. JWT_SECRET: 40-character random string
JWT_SECRET=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 40)
echo "JWT_SECRET=${JWT_SECRET}"

# 3. Shared secret for API-Frontend auth (same value for both vars)
SHARED_SECRET=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 40)
echo "FRONT_API_SECRET=${SHARED_SECRET}"
echo "NUXT_API_SECRET=${SHARED_SECRET}"

echo ""
echo "=== Additional required variables ==="
echo "You MUST also set these in the Dokploy Environment tab:"
echo ""
echo "APP_URL=https://your-domain.com     # Your actual domain"
echo "DB_PASSWORD=<strong-password>       # Change from default 'forge'"
echo ""
echo "=== Done ==="
echo "Run this script ONCE. The values persist across redeploys in Dokploy."
