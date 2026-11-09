#!/usr/bin/env bash
# Exit on error
set -o errexit

echo "==> Deploying AdoptMatch API to Render..."

# Install Composer dependencies
echo "==> Installing PHP composer dependencies (optimized for production)..."
composer install --no-dev --optimize-autoloader --no-interaction

# Generate app key if not set
if [ -z "$APP_KEY" ]; then
  echo "==> Generating Application Key..."
  php artisan key:generate --force
fi

# Run Database Migrations on Clever Cloud MySQL
echo "==> Running production database migrations..."
php artisan migrate --force

# Seed database with initial demo data if needed
# php artisan db:seed --force

# Cache routes and configuration for sub-millisecond response latency
echo "==> Optimizing configuration & route caches..."
php artisan config:cache
php artisan route:cache

echo "==> AdoptMatch API build successfully completed!"

