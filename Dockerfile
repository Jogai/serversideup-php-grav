# Grav CMS on FrankenPHP: Caddy and PHP 8.5 in one process, based on serversideup/php.
# Pulled from ghcr.io (the same images as on Docker Hub) to stay clear of Docker Hub's pull limits.
# Renovate bumps the version and digest below when serversideup publishes a release or rebuilds the tag.
FROM ghcr.io/serversideup/php:8.5-frankenphp-alpine-v5.0.3@sha256:fd5c5d89585f322c62d2baa4df5eed418ecd19197ffe6626f7011f6c6ab7965e

USER root

# serversideup already ships zip, sodium, pdo_sqlite (Grav's lazy page index) and OPcache.
# Added: gd (Grav's image processing), apcu (Grav's cache), intl and exif.
# Removed: the database, queue and process-control extensions Grav never uses.
# git is for the git-sync plugin.
RUN apk add --no-cache git \
 && install-php-extensions gd apcu intl exif \
 && cd /usr/local/etc/php/conf.d \
 && rm docker-php-ext-pdo_mysql.ini docker-php-ext-pdo_pgsql.ini docker-php-ext-redis.ini docker-php-ext-pcntl.ini

COPY grav.caddyfile /etc/frankenphp/caddyfile-server.d/grav.caddyfile
COPY grav.ini /usr/local/etc/php/conf.d/zzz-grav.ini

USER www-data

# Grav's defaults; all of them can be overridden per container
ENV CADDY_SERVER_ROOT=/var/www/html \
    # only the front controller runs: no {path}/index.php lookup (see grav.caddyfile)
    CADDY_PHP_SERVER_OPTIONS="try_files {path} index.php" \
    # 4 PHP threads; each can use up to PHP_MEMORY_LIMIT
    FRANKENPHP_CONFIG="num_threads 4" \
    # behind a reverse proxy on a Docker network (serversideup defaults to Cloudflare's ranges)
    TRUSTED_PROXY=local \
    SHOW_WELCOME_MESSAGE=false \
    PHP_MEMORY_LIMIT=256M \
    PHP_MAX_EXECUTION_TIME=120 \
    PHP_POST_MAX_SIZE=64M \
    PHP_UPLOAD_MAX_FILE_SIZE=64M \
    # OPcache halves Grav's request time and memory; Grav + Admin is ~3,400 PHP files.
    # Timestamps stay validated because Grav rewrites its compiled config files.
    PHP_OPCACHE_ENABLE=1 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
    PHP_OPCACHE_MEMORY_CONSUMPTION=128 \
    PHP_OPCACHE_INTERNED_STRINGS_BUFFER=16 \
    PHP_OPCACHE_MAX_ACCELERATED_FILES=10000 \
    # Grav's cache driver "auto" picks APCu, shared by all PHP threads
    PHP_APC_SHM_SIZE=64M
