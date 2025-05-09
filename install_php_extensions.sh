#!/bin/bash

set -ex

# Install necessary packages
apt-get update
apt-get install -y --no-install-recommends \
    libpcre3-dev \
    tini \
    libintl-perl \
    postgresql-server-dev-all \
    libmemcached-dev \
    libmagick++-dev \
    libc-dev \
    libpcre3 \
    libgeoip-dev

# Extract PHP source and install PHP extensions
docker-php-source extract
pecl install xdebug-beta apcu
docker-php-ext-install exif soap bcmath
docker-php-ext-install -j"$(nproc)" mysqli opcache pdo_mysql pdo_pgsql
docker-php-ext-enable apcu

# Install runtime dependencies
runDeps="$(scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
    | tr ',' '\n' \
    | sort -u \
    | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }')"
apt-get install -y $runDeps

# Set SSH password
echo "$SSH_PASSWD" | chpasswd

# Install Imagick
if [[ "${PHP_VERSION:0:3}" = "8.3" ]]; then
    mkdir -p imagick-build
    curl -L -o /tmp/imagick.tar.gz https://github.com/Imagick/imagick/archive/7088edc353f53c4bc644573a>
    tar --strip-components=1 -xf /tmp/imagick.tar.gz -C ./imagick-build
    cd imagick-build
    phpize
    ./configure
    make
    make install
    docker-php-ext-enable imagick
    cd ..
    rm -rf imagick-build
    rm -rf /tmp/imagick.tar.gz
else
    pecl install imagick || true
    docker-php-ext-enable imagick
fi

# Clean up
apt-get remove -y --purge $(dpkg -l | awk '/^rc/ { print $2 }')
apt-get clean
rm -rf /var/lib/apt/lists/*
docker-php-source delete
mkdir -p /usr/local/php/tmp
chmod 777 /usr/local/php/tmp
apt-get purge -y --auto-remove \
    libmemcached-dev \
    postgresql-server-dev-all
