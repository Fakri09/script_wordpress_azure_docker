#!/bin/bash
set -ex
curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.>
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(ls>
apt-get update
apt-get install -y --no-install-recommends redis-server libwebp-dev 
docker-php-source extract
tar xfz /tmp/redis.tar.gz -C /usr/src/php/ext/
rm /tmp/redis.tar.gz
mv /usr/src/php/ext/phpredis-${PHPREDIS_VERSION} /usr/src/php/ext/redis
docker-php-ext-configure gd --with-jpeg --with-webp
docker-php-ext-install -j$(nproc) gd zip redis
docker-php-source delete
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/*
mkdir -p ${MYSQL_CA_CERT_DIR}
wget https://dl.cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem -O ${MYSQL_CA_CERT_FILE}
