# -------------------------
# STAGE 1 — BUILD
# -------------------------
# Usa PHP 8.4 + Apache como base de construção. Este stage contém ferramentas
# que são necessárias para preparar a aplicação, mas não precisam de ficar
# na imagem final de runtime.
FROM php:8.4-apache-bookworm AS build

# Permite ao Composer correr como root durante o build e força o ambiente
# Symfony de produção durante a instalação das dependências. Isto é importante
# porque usamos --no-dev: os bundles exclusivos de dev/test não são instalados
# e, por isso, os auto-scripts do Composer devem correr com APP_ENV=prod.
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    APP_ENV=prod \
    APP_DEBUG=0

# Instala ferramentas de build e bibliotecas de desenvolvimento:
# - curl/git/unzip suportam download e preparação de dependências;
# - libicu-dev, libpq-dev e libsqlite3-dev permitem compilar extensões PHP;
# - docker-php-ext-install compila intl, opcache, pdo_pgsql e pdo_sqlite;
# - -j"$(nproc)" paraleliza a compilação pelos CPUs disponíveis;
# - no fim remove a cache apt para reduzir o conteúdo da layer.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl git unzip libicu-dev libpq-dev libsqlite3-dev \
    && docker-php-ext-install -j"$(nproc)" intl opcache pdo_pgsql pdo_sqlite \
    && rm -rf /var/lib/apt/lists/*

# Obtém o Composer a partir da imagem oficial, copiando apenas o binário.
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Define a raiz da aplicação.
WORKDIR /var/www/html

# Copia primeiro apenas os ficheiros que descrevem as dependências e as recipes
# Symfony. Esta ordem permite reutilizar a cache do composer install quando o
# código muda mas composer.json/composer.lock/symfony.lock permanecem iguais.
COPY app/composer.json app/composer.lock app/symfony.lock ./

# Primeira passagem: instala dependências de produção sem executar scripts.
# Nesta fase ainda não foi copiado o restante código da aplicação.
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader

# Só depois copia o restante código da aplicação e executa novamente Composer,
# agora com os auto-scripts da aplicação disponíveis e APP_ENV=prod.
COPY app/ ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader

# Prepara explicitamente os assets para runtime de produção:
# - sass:build gera o CSS resultante dos ficheiros Sass;
# - asset-map:compile compila/copía os assets versionados para public/assets;
# - o teste final faz o build falhar se o manifest não tiver sido criado.
# Isto evita produzir uma imagem funcional em PHP mas incompleta no browser.
RUN php bin/console sass:build --no-interaction \
    && php bin/console asset-map:compile --no-interaction \
    && test -f public/assets/manifest.json

# -------------------------
# STAGE 2 — RUNTIME
# -------------------------
# Recomeça de uma imagem PHP + Apache limpa. As ferramentas de compilação do
# stage anterior não são levadas para produção.
FROM php:8.4-apache-bookworm AS runtime

# Instala apenas bibliotecas necessárias em runtime e configura Apache:
# - curl é usado pelo HEALTHCHECK;
# - libicu72/libpq5/libsqlite3-0 suportam as extensões já compiladas;
# - mod_rewrite é ativado para routing Symfony;
# - a cache apt é removida no fim.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl libicu72 libpq5 libsqlite3-0 \
    && a2enmod rewrite \
    && printf 'ServerName localhost\n' > /etc/apache2/conf-available/servername.conf \
    && a2enconf servername \
    && rm -rf /var/lib/apt/lists/*

# Copia do stage build as extensões PHP compiladas e respetiva configuração.
COPY --from=build /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=build /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Copia a aplicação já preparada no stage build, incluindo public/assets,
# e instala o VirtualHost Apache.
WORKDIR /var/www/html
COPY --from=build /var/www/html /var/www/html
COPY formando/docker/000-default.conf /etc/apache2/sites-available/000-default.conf

# Garante que Symfony consegue escrever em cache e logs durante a execução.
RUN mkdir -p var/cache var/log \
    && chown -R www-data:www-data var

# Argumentos recebidos no build para identificar o artefacto e parametrizar
# o endpoint utilizado pelo HEALTHCHECK.
ARG APP_VERSION=dev
ARG SOURCE_REF=v3.1.0
ARG HEALTH_PATH=/health

# Variáveis persistidas na configuração final da imagem.
ENV APP_ENV=prod \
    APP_DEBUG=0 \
    APP_VERSION=${APP_VERSION} \
    HEALTH_PATH=${HEALTH_PATH}

# Labels OCI: metadata útil para identificar título, versão, origem e revisão
# do código usado na construção da imagem.
LABEL org.opencontainers.image.title="Symfony Demo - Formação Kubernetes" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.source="https://github.com/symfony/demo" \
      org.opencontainers.image.revision="${SOURCE_REF}"

# Documenta a porta HTTP esperada dentro do container.
EXPOSE 80

# Avalia a saúde do container através do caminho definido em HEALTH_PATH.
# A versão 1.2.0-rc1 usa deliberadamente um caminho incorreto para demonstrar
# diagnóstico e rollback no laboratório integrado.
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=5 \
    CMD curl -fsS "http://localhost${HEALTH_PATH}" >/dev/null || exit 1

# Mantém Apache em foreground como processo principal do container.
CMD ["apache2-foreground"]
