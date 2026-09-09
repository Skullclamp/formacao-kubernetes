FROM php:8.4-apache-bookworm AS build

ENV COMPOSER_ALLOW_SUPERUSER=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl git unzip libicu-dev libpq-dev libsqlite3-dev \
    && docker-php-ext-install -j"$(nproc)" intl opcache pdo_pgsql pdo_sqlite \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

COPY app/composer.json app/composer.lock ./
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader

COPY app/ ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader

FROM php:8.4-apache-bookworm AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl libicu72 libpq5 libsqlite3-0 \
    && a2enmod rewrite \
    && printf 'ServerName localhost\n' > /etc/apache2/conf-available/servername.conf \
    && a2enconf servername \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=build /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

WORKDIR /var/www/html
COPY --from=build /var/www/html /var/www/html
COPY formando/docker/000-default.conf /etc/apache2/sites-available/000-default.conf

RUN mkdir -p var/cache var/log \
    && chown -R www-data:www-data var

ARG APP_VERSION=dev
ARG SOURCE_REF=v3.1.0
ARG HEALTH_PATH=/health

ENV APP_ENV=prod \
    APP_VERSION=${APP_VERSION} \
    HEALTH_PATH=${HEALTH_PATH}

LABEL org.opencontainers.image.title="Symfony Demo - Formação Kubernetes" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.source="https://github.com/symfony/demo" \
      org.opencontainers.image.revision="${SOURCE_REF}"

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=5 \
    CMD curl -fsS "http://localhost${HEALTH_PATH}" >/dev/null || exit 1

CMD ["apache2-foreground"]
