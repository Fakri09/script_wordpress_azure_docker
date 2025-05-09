#!/bin/bash

set -ex
apt-get update
apt-get install -y --no-install-recommends libnginx-mod-http-brotli 

# Create directory for PHP extension brotli
mkdir -p /tmp/php-ext-brotli
cd /tmp/php-ext-brotli

# Clone the repository
git clone --recursive --depth=1 https://github.com/kjdev/php-ext-brotli.git /tmp/php-ext-brotli

# Build and install the extension
phpize
./configure
make
make install

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/php-ext-brotli
