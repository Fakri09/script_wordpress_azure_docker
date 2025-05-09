#!/bin/bash
set -ex
# Update package list and install necessary packages
apt-get update

# Create nginx user and group
addgroup --system nginx
adduser --system --home /var/cache/nginx --shell /sbin/nologin --ingroup nginx nginx

# Move envsubst and clean up apt lists and temporary files
rm -rf /var/lib/apt/lists/* /tmp/*

echo "Forwarding request and error logs to docker log collector......."
# Forward request and error logs to docker log collector
ln -sf /dev/stdout /var/log/nginx/access.log
ln -sf /dev/stderr /var/log/nginx/error.log

# Change default root path to $HOME_SITE
mkdir -p /etc/nginx/conf.d
mkdir -p ${HOME_SITE}
mkdir -p ${HOME_SITE_LOCAL_STG}
echo "<?php phpinfo();" > ${HOME_SITE}/index.php
chown -R nginx:nginx ${HOME_SITE} ${HOME_SITE_LOCAL_STG}
chmod -R 777 ${HOME_SITE} ${HOME_SITE_LOCAL_STG}

# Create php-fpm log directory
mkdir -p ${PHP_FPM_LOG_DIR}
chown -R nginx:nginx ${PHP_FPM_LOG_DIR}
chmod -R 777 ${PHP_FPM_LOG_DIR}

# Configure log rotate
(echo "*       *       *       *       *       sh /usr/local/bin/triage-rotate.sh") | crontab -
#(crontab -l; echo "* * * * * sh /usr/local/bin/triage-rotate.sh") | crontab -

# Clean up and create necessary directories
rm -rf /var/log/nginx /var/log/supervisor /etc/logrotate.d /usr/src/supervisor
mkdir -p /etc/logrotate.d /usr/src/supervisor /opt/startup/
