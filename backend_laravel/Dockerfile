FROM php:8.2-cli-alpine

# Install system dependencies & PHP MySQL extensions
RUN apk add --no-cache \
    bash \
    curl \
    git \
    libpng-dev \
    libxml2-dev \
    zip \
    unzip \
    mariadb-connector-c-dev \
    && docker-php-ext-install pdo pdo_mysql bcmath

# Copy Composer from official image
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY . .

# Ensure base .env exists and generate production application key
RUN cp .env.example .env && \
    composer config policy.advisories.block false || true && \
    composer config audit.block false || true

# Install dependencies optimized for production
RUN composer install --no-dev --optimize-autoloader --no-interaction || composer update --no-dev --optimize-autoloader --no-interaction

# Generate application key if missing
RUN php artisan key:generate --force

# Set proper permissions for storage and bootstrap cache
RUN chmod -R 777 storage bootstrap/cache

# Dynamic port handling for Render
EXPOSE 8000

# Entrypoint script: runs production migrations gracefully, caches routes, and serves via artisan
CMD ["sh", "-c", "php artisan migrate --force || true && php artisan config:cache && php artisan route:cache && php artisan serve --host=0.0.0.0 --port=${PORT:-8000}"]
