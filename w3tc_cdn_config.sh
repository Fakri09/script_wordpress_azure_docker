cdn_type="$1"

afd_update_site_url() {
        AFD_DOMAIN=$WEBSITE_HOSTNAME
        if [[ $CUSTOM_DOMAIN ]]; then
            AFD_DOMAIN=$CUSTOM_DOMAIN
        elif [[ $AFD_ENDPOINT ]]; then
            AFD_DOMAIN=$AFD_ENDPOINT
        fi

        wp config set WP_HOME "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_HOME --allow-root
        wp config set WP_SITEURL "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_HOME --allow-root
        wp option update SITEURL "https://$AFD_DOMAIN" --path=$WORDPRESS_HOME --allow-root
        wp option update HOME "https://$AFD_DOMAIN" --path=$WORDPRESS_HOME --allow-root

        if [ -e "$WORDPRESS_HOME/wp-config.php" ]; then
            AFD_HEADER_FILE='afd-header-settings.txt'
            AFD_CONFIG_DETECTED=''

            if [[ $(grep -c "MULTISITE_CONVERSION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]] && [[ $WORDPRESS_MULTISITE_TYPE ]] && [[ "$WORDPRESS_MULTISITE_TYPE" == "subdomain" ]] && [[ $C>
                AFD_CONFIG_DETECTED=$(grep "^\s*\$_SERVER\['HTTP_HOST'\]\s*=\s*\$_SERVER\['HTTP_X_FORWARDED_HOST'\];" $WORDPRESS_HOME/wp-config.php)
                AFD_HEADER_FILE='afd-multisite-header-settings.txt'
                AFD_DOMAIN=''
            else
                AFD_CONFIG_DETECTED=$(grep "^\s*\$_SERVER\['HTTP_HOST'\]\s*=\s*getenv('AFD_DOMAIN');" $WORDPRESS_HOME/wp-config.php)
            fi

            if [ -z "$AFD_CONFIG_DETECTED" ]; then
                SEARCH_STR_I="Using environment variables for memory limits"
                if [ ! -z "$(grep "${SEARCH_STR_I}" $WORDPRESS_HOME/wp-config.php)" ]; then
                    sed -i "/${SEARCH_STR_I}/e cat $WORDPRESS_SOURCE/$AFD_HEADER_FILE" $WORDPRESS_HOME/wp-config.php
                else
                    SEARCH_STR_II="Using environment variables for DB connection information"
                    if [ ! -z "$(grep "${SEARCH_STR_II}" $WORDPRESS_HOME/wp-config.php)" ]; then
                        sed -i "/${SEARCH_STR_II}/e cat $WORDPRESS_SOURCE/$AFD_HEADER_FILE" $WORDPRESS_HOME/wp-config.php
                    fi
                fi
            fi
        fi

        if [[ "$AFD_DOMAIN" == "$WEBSITE_HOSTNAME" ]]; then
            AFD_DOMAIN=''
        fi

        echo "${cdn_type}_CONFIGURATION_COMPLETE" >> $WORDPRESS_LOCK_FILE
}

cname_parameter="cdn.azure.cname"
if [[ "${ENABLE_BLOB_MANAGED_IDENTITY,,}" == "true" ]] && [[ $ENTRA_CLIENT_ID ]]; then
    cname_parameter="cdn.azuremi.cname"
fi

#Configure CDN settings 
if [[ "$cdn_type" == "BLOB_CDN" ]] && [[ $CDN_ENDPOINT ]] && [ ! $(grep "BLOB_CDN_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] \
&& [[ $(curl --write-out '%{http_code}' --silent --output /dev/null {https://$CDN_ENDPOINT}) == "200" ]] \
&& wp plugin activate w3-total-cache --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set $cname_parameter $CDN_ENDPOINT --type=array --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set cdn.includes.enable true --type=boolean --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set cdn.theme.enable true --type=boolean --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set cdn.custom.enable true --type=boolean --path=$WORDPRESS_HOME --allow-root; then
    echo "BLOB_CDN_CONFIGURATION_COMPLETE" >> $WORDPRESS_LOCK_FILE
    service atd stop
    redis-cli flushall
elif [[ "$cdn_type" == "CDN" ]] && [[ $CDN_ENDPOINT ]] && [ ! $(grep "CDN_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] \
&& [[ $(curl --write-out '%{http_code}' --silent --output /dev/null {https://$CDN_ENDPOINT}) == "200" ]] \
&& wp plugin activate w3-total-cache --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set cdn.enabled true --type=boolean --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set cdn.engine "mirror" --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set cdn.mirror.domain $CDN_ENDPOINT --type=array --path=$WORDPRESS_HOME --allow-root; then
    echo "CDN_CONFIGURATION_COMPLETE" >> $WORDPRESS_LOCK_FILE
    service atd stop
    redis-cli flushall
elif [[ "$cdn_type" == "BLOB_AFD" ]] && [[ $AFD_ENDPOINT ]] && [ ! $(grep "BLOB_AFD_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] \
&& [[ $(curl --write-out '%{http_code}' --silent --output /dev/null {https://$AFD_ENDPOINT}) == "200" ]] \
&& wp plugin activate w3-total-cache --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set $cname_parameter $AFD_ENDPOINT --type=array --path=$WORDPRESS_HOME --allow-root; then
    afd_update_site_url
    service atd stop
    redis-cli flushall
elif [[ "$cdn_type" == "AFD" ]] && [[ $AFD_ENDPOINT ]] && [ ! $(grep "AFD_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] \
&& [[ $(curl --write-out '%{http_code}' --silent --output /dev/null {https://$AFD_ENDPOINT}) == "200" ]]; then
    afd_update_site_url
    service atd stop
    redis-cli flushall
else
    service atd start
    echo "bash /usr/local/bin/w3tc_cdn_config.sh $cdn_type" | at now +2 minutes
fi
