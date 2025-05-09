#!/bin/bash

# set -e

php -v

# if defined, assume the container is running on Azure
AZURE_DETECTED=$WEBSITES_ENABLE_APP_SERVICE_STORAGE
if [[ $AFD_CUSTOM_DOMAIN ]] && [[ $AFD_ENABLED ]] && [[ "$AFD_ENABLED" == "true" || "$AFD_ENABLED" == >
    CUSTOM_DOMAIN=$AFD_CUSTOM_DOMAIN
fi

# Update application setting from connection string, if available
export WORDPRESS_ADMIN_EMAIL=${CUSTOMCONNSTR_WORDPRESS_ADMIN_EMAIL:-$WORDPRESS_ADMIN_EMAIL}
export WORDPRESS_ADMIN_USER=${CUSTOMCONNSTR_WORDPRESS_ADMIN_USER:-$WORDPRESS_ADMIN_USER}
export WORDPRESS_ADMIN_PASSWORD=${CUSTOMCONNSTR_WORDPRESS_ADMIN_PASSWORD:-$WORDPRESS_ADMIN_PASSWORD}
export WP_EMAIL_CONNECTION_STRING=${CUSTOMCONNSTR_WP_EMAIL_CONNECTION_STRING:-$WP_EMAIL_CONNECTION_STR>
export STORAGE_ACCOUNT_NAME=${CUSTOMCONNSTR_STORAGE_ACCOUNT_NAME:-$STORAGE_ACCOUNT_NAME}
export STORAGE_ACCOUNT_KEY=${CUSTOMCONNSTR_STORAGE_ACCOUNT_KEY:-$STORAGE_ACCOUNT_KEY}
export DATABASE_USERNAME=${CUSTOMCONNSTR_DATABASE_USERNAME:-$DATABASE_USERNAME}
export DATABASE_PASSWORD=${CUSTOMCONNSTR_DATABASE_PASSWORD:-$DATABASE_PASSWORD}

update_php_config() {
        local CONFIG_FILE="${1}"
        local PARAM_NAME="${2}"
        local PARAM_VALUE="${3}"
        local VALUE_TYPE="${4}"
        local PARAM_UPPER_BOUND="${5}"

        if [[ -e $CONFIG_FILE && $PARAM_VALUE ]]; then
                local FINAL_PARAM_VALUE

                if [[ "$VALUE_TYPE" == "NUM" && $PARAM_VALUE =~ ^[0-9]+$ && $PARAM_UPPER_BOUND =~ ^[0->

                        if [[ "$PARAM_VALUE" -le "$PARAM_UPPER_BOUND" ]]; then
                                FINAL_PARAM_VALUE=$PARAM_VALUE
                        else
                                FINAL_PARAM_VALUE=$PARAM_UPPER_BOUND
                        fi

                elif [[ "$VALUE_TYPE" == "MEM" && $PARAM_VALUE =~ ^[0-9]+M$ && $PARAM_UPPER_BOUND =~ ^>

                        if [[ "${PARAM_VALUE::-1}" -le "${PARAM_UPPER_BOUND::-1}" ]]; then
                                FINAL_PARAM_VALUE=$PARAM_VALUE
                        else
                                FINAL_PARAM_VALUE=$PARAM_UPPER_BOUND
                        fi

                elif [[ "$VALUE_TYPE" == "TOGGLE" ]] && [[ "$PARAM_VALUE" == "On" || "$PARAM_VALUE" ==>
                        FINAL_PARAM_VALUE=$PARAM_VALUE
                fi


                if [[ $FINAL_PARAM_VALUE ]]; then
                        echo "updating php config value "$PARAM_NAME
                        sed -i "s/.*$PARAM_NAME.*/$PARAM_NAME = $FINAL_PARAM_VALUE/" $CONFIG_FILE
                fi
        fi
}

temp_server_start() {
    local TEMP_SERVER_TYPE="${1}"
    test ! -d /home/site/temp-root && mkdir -p /home/site/temp-root
    cp -r /usr/src/temp-server/* /home/site/temp-root/

    if [[ "$TEMP_SERVER_TYPE" == "INSTALLATION" ]]; then
        cp /usr/src/nginx/temp-server-installation.conf /etc/nginx/conf.d/default.conf
    elif [[ "$TEMP_SERVER_TYPE" == "MAINTENANCE" ]]; then     
        cp /usr/src/nginx/temp-server-maintenance.conf /etc/nginx/conf.d/default.conf
    else 
        echo "WARN: Unable to start temporary server. Missing parameter."
        return;
    fi

    local try_count=1
    while [ $try_count -le 10 ]
    do 
        /usr/sbin/nginx
        local port=`ss -nlt|grep 80|wc -l`
        local process=`ps -ef |grep nginx|grep -v grep |wc -l`
        if [ $port -ge 1 ] && [ $process -ge 1 ]; then 
            echo "INFO: Temporary Server started... "            
            break
        else            
            echo "INFO: Nginx couldn't start, trying again..."
            pkill nginx 2> /dev/null 
            sleep 5s
        fi
        let try_count+=1 
    done
}

temp_server_stop() {
    #kill any existing nginx processes
    pkill nginx 2> /dev/null 
}

update_phpmyadmin_config_file() {
    chmod 777 "$PHPMYADMIN_HOME/config.inc.php"
    cp "$PHPMYADMIN_SOURCE/config.inc.php" "$PHPMYADMIN_HOME/config.inc.php"
    sed -i '/^BLOWFISH_SECRET_UPDATED$/d' $WORDPRESS_LOCK_FILE
}

setup_phpmyadmin() {

    if [[ $SETUP_PHPMYADMIN ]] && [[ "$SETUP_PHPMYADMIN" == "true" || "$SETUP_PHPMYADMIN" == "TRUE" ||>
        if [ ! $(grep -c "PHPMYADMIN_INSTALLED" $WORDPRESS_LOCK_FILE) -gt 0 ]; then
            if mkdir -p $PHPMYADMIN_HOME \
                && chmod -R 777 $PHPMYADMIN_HOME \
                && cp -R $PHPMYADMIN_SOURCE/phpmyadmin/* $PHPMYADMIN_HOME \
                && mkdir -p $PHPMYADMIN_HOME/sessions \
                && echo "<?php ?>" > $PHPMYADMIN_HOME/sessions/index.php; then
                echo "PHPMYADMIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
            fi
        else
            if [ ! -e "$PHPMYADMIN_HOME/file_session_handler.php" ]; then
                cp "$PHPMYADMIN_SOURCE/file_session_handler.php" "$PHPMYADMIN_HOME/file_session_handle>
                update_phpmyadmin_config_file
            fi

            # Avoid listing of sessions directory (Although being handled at Nginx level as well)
            if [ ! -e "$PHPMYADMIN_HOME/sessions/index.php" ]; then
                if mkdir -p $PHPMYADMIN_HOME/sessions; then
                    echo "<?php ?>" > $PHPMYADMIN_HOME/sessions/index.php
                fi
            fi

            # Update PhpMyAdmin config file with SSL CA certificate
           if [[ $MYSQL_CA_CERT_FILE ]]; then
                if [ ! $(grep -c "MYSQL_CA_CERT_FILE" $PHPMYADMIN_HOME/config.inc.php) -gt 0 ] \
                    || [ ! $(grep -c "^\s*\$cfg\['Servers'\]\[\$i\]\['ssl_ca'\]\s*=\s*getenv('MYSQL_CA>
                    update_phpmyadmin_config_file
                fi
            fi
        fi

        # Updating the blowfish secret in phpmyadmin config file
        if [ ! $(grep -c "BLOWFISH_SECRET_UPDATED" $WORDPRESS_LOCK_FILE) -gt 0 ]; then
            update_phpmyadmin_config_file
            local BLOWFISH=$(openssl rand -base64 64 | tr -dc 'a-zA-Z0-9' | head -c 32)
            if sed -i "s/\(\$cfg\['blowfish_secret'\]\s*=\s*\).*/\1'$BLOWFISH';/" "$PHPMYADMIN_HOME/co>
                echo "BLOWFISH_SECRET_UPDATED" >> $WORDPRESS_LOCK_FILE
            fi
        fi  
        # updating the 555 permissions at the end to avoid race condition  
        chmod 555 "$PHPMYADMIN_HOME/config.inc.php"
    fi
}

translate_welcome_content() {
    if [  $(grep -c "WP_LANGUAGE_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ] &&  [ ! $(grep -c "WP_>
        if [[ $WORDPRESS_LOCALE_CODE ]] && [[ ! "$WORDPRESS_LOCALE_CODE" == "en_US"  ]]; then
            local welcomedatapath="$WORDPRESS_SOURCE/welcome-data/$WORDPRESS_LOCALE_CODE"
            local blogname=$(cat "$welcomedatapath/$WORDPRESS_LOCALE_CODE.blogname" 2>/dev/null)
                local blogdesc=$(cat "$welcomedatapath/$WORDPRESS_LOCALE_CODE.blogdesc" 2>/dev/null)
                local postname=$(cat "$welcomedatapath/$WORDPRESS_LOCALE_CODE.postname" 2>/dev/null)
                local postcontent=$(cat "$welcomedatapath/$WORDPRESS_LOCALE_CODE.postcontent" 2>/dev/n>

            if [[ $postname ]] && [[ $postcontent ]] && [[ $blogname ]] && [[ $blogdesc ]]; then
                if wp option update blogname "$blogname" --path=$WORDPRESS_HOME --allow-root \
                && wp option update blogdescription "$blogdesc" --path=$WORDPRESS_HOME --allow-root \
                && wp post delete 1 --force --path=$WORDPRESS_HOME --allow-root \
                && wp post create --post_content="$postcontent" --post_title="$postname" --post_status>
                    echo "WP_TRANSLATE_WELCOME_DATA_COMPLETED" >> $WORDPRESS_LOCK_FILE
                fi
            else
                echo "WP_TRANSLATE_WELCOME_DATA_COMPLETED" >> $WORDPRESS_LOCK_FILE
            fi
        else
            echo "WP_TRANSLATE_WELCOME_DATA_COMPLETED" >> $WORDPRESS_LOCK_FILE
        fi
    fi
}

setup_cdn_variables() {
    IS_CDN_ENABLED="False"
    if [[ $CDN_ENABLED ]] && [[ "$CDN_ENABLED" == "true" || "$CDN_ENABLED" == "TRUE" || "$CDN_ENABLED">
        IS_CDN_ENABLED="True"
    fi
    
    IS_AFD_ENABLED="False"
    if [[ $AFD_ENABLED ]] && [[ "$AFD_ENABLED" == "true" || "$AFD_ENABLED" == "TRUE" || "$AFD_ENABLED">
        IS_AFD_ENABLED="True"
    fi
    
    IS_BLOB_STORAGE_ENABLED="False"
    if [[ $BLOB_STORAGE_ENABLED ]] && [[ "$BLOB_STORAGE_ENABLED" == "true" || "$BLOB_STORAGE_ENABLED" >
    && [[ $STORAGE_ACCOUNT_NAME ]] && [[ $BLOB_CONTAINER_NAME ]]; then
        if [[ $STORAGE_ACCOUNT_KEY ]] || ([[ "${ENABLE_BLOB_MANAGED_IDENTITY,,}" == "true" ]] && [[ $E>
            IS_BLOB_STORAGE_ENABLED="True"
        fi
    fi

}

initialize_temp_root() {
    #Initialize temporary root
    test ! -d /home/site/temp-root && mkdir -p /home/site/temp-root
    cp -r /usr/src/temp-server/* /home/site/temp-root/

    # update permissions to /home/site/temp-root
    chown -R nginx:nginx /home/site/temp-root
}

setup_wp_installed_page() {
    initialize_temp_root
    
    # update nginx conf to display warning page
    cp /usr/src/nginx/temp-server-wpinstalled.conf /etc/nginx/conf.d/default.conf
}

setup_xmlrpc() {
    if [ -n "$WORDPRESS_ENABLE_XMLRPC" ] && [[ "${WORDPRESS_ENABLE_XMLRPC,,}" == "true" ]]; then
        if [ ! -f /home/site/temp-root/hostingstart_xmlrpc.html ]; then
            initialize_temp_root
        fi
        # remove the xmlrpc block from nginx conf
        local nginx_conf_file="/etc/nginx/conf.d/default.conf"
        if grep -q "# XMLRPC block starts here" "$nginx_conf_file" && grep -q "# XMLRPC block ends her>
            sed -i '/# XMLRPC block starts here/,/# XMLRPC block ends here/d' "$nginx_conf_file"
        fi 
    fi
}

start_at_daemon() {
    service atd start
    service atd status
}

DISPLAY_WP_INSTALLED_WARNING_PAGE="False"
setup_wordpress() {
    if [ ! -d $WORDPRESS_LOCK_HOME ]; then
        mkdir -p $WORDPRESS_LOCK_HOME
    fi

    # Check if wordpress is already installed
    wp core is-installed --path=$WORDPRESS_HOME --allow-root 2> /dev/null
    IS_WP_INSTALLED=$?

    if [ $IS_WP_INSTALLED -ne 0 ]; then
        wp core is-installed --path=$WORDPRESS_SOURCE/wordpress-azure --allow-root 2> /dev/null
        IS_WP_INSTALLED=$?
    fi

    if [ ! -e $WORDPRESS_LOCK_FILE ]; then
        if [ $IS_WP_INSTALLED -eq 0 ]; then
            echo "Could not find status file and wordpress is already installed... Issuing warning pag>
            DISPLAY_WP_INSTALLED_WARNING_PAGE="True"
                return
        else
            echo "INFO: creating a new WordPress status file ..."
            touch $WORDPRESS_LOCK_FILE;
        fi
    else 
        echo "INFO: Found an existing WordPress status file ..."
    fi

    if [ "$IS_TEMP_SERVER_STARTED" == "True" ]; then
        temp_server_stop
    fi

    IS_TEMP_SERVER_STARTED="False"
    #Start server with static webpage until wordpress is installed
    if [ ! $(grep -c "FIRST_TIME_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]; then
        echo "INFO: Starting temporary server while WordPress is being installed"
        IS_TEMP_SERVER_STARTED="True"
        temp_server_start "INSTALLATION"
    fi

    setup_phpmyadmin

    if [ $(grep -c "GIT_PULL_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ] &&  [ ! $(grep -c "WORDPRESS_PUL>
        echo "WORDPRESS_PULL_COMPLETED" >> $WORDPRESS_LOCK_FILE
    fi

    if [ ! $(grep -c "WORDPRESS_PULL_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]; then
        if [ $IS_WP_INSTALLED -eq 0 ]; then
            echo "Did not pull wordpress source code since it is already installed... Issuing warning >
            DISPLAY_WP_INSTALLED_WARNING_PAGE="True"
            return
            fi

        while [ -d $WORDPRESS_HOME ]
        do
            mkdir -p /home/bak
            mv $WORDPRESS_HOME /home/bak/wordpress_bak$(date +%s)            
        done
        
        test ! -d "$WORDPRESS_HOME" && mkdir -p $WORDPRESS_HOME
        echo "INFO: Pulling WordPress code"
        if cp -r $WORDPRESS_SOURCE/wordpress-azure/* $WORDPRESS_HOME; then
            echo "WORDPRESS_PULL_COMPLETED" >> $WORDPRESS_LOCK_FILE
        fi
    fi

    if [ $(grep -c "WORDPRESS_PULL_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ] &&  [ ! $(grep -c "WP_INST>

        if wp core install --url=$WEBSITE_HOSTNAME --title="WordPress on Azure" --admin_user=$WORDPRES>
            echo "WP_INSTALLATION_COMPLETED" >> $WORDPRESS_LOCK_FILE

            # For new installations, Managed Identity setup is available by default
            echo "MANAGED_IDENTITY_SETUP_COMPLETED" >> $WORDPRESS_LOCK_FILE;
        fi

        # one time check for WordPress core minor version update
        if [[ `wp core check-update --minor --path=$WORDPRESS_HOME --allow-root | grep Success | wc -l>
            wp core update --minor --path=$WORDPRESS_HOME --allow-root
        fi
    fi

    if [ $(grep -c "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ] && [ ! $(grep -c "WP_CONF>
        if wp rewrite structure '/%year%/%monthnum%/%day%/%postname%/' --path=$WORDPRESS_HOME --allow->
        && wp option set rss_user_excerpt 1 --path=$WORDPRESS_HOME --allow-root \
        && wp option set page_comments 1 --path=$WORDPRESS_HOME --allow-root \
        && wp option update blogdescription "" --path=$WORDPRESS_HOME --allow-root \
        && wp option set auto_update_core_major disabled --path=$WORDPRESS_HOME --allow-root \
        && wp option set auto_update_core_minor enabled --path=$WORDPRESS_HOME --allow-root \
        && wp option set auto_update_core_dev disabled --path=$WORDPRESS_HOME --allow-root \
        && wp config shuffle-salts --path=$WORDPRESS_HOME --allow-root; then
            echo "WP_CONFIG_UPDATED" >> $WORDPRESS_LOCK_FILE
        fi
    fi

    if [ $(grep -c "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ] && [ ! $(grep -c "SMUSH_P>
        #backward compatibility for previous versions that don't have plugin source code in wordpress >
        if [ $(grep -c "GIT_PULL_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]; then
            if wp plugin install wp-smushit --force --activate --path=$WORDPRESS_HOME --allow-root; th>
                echo "SMUSH_PLUGIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
            fi
        else
            if wp plugin deactivate wp-smushit --quiet --path=$WORDPRESS_HOME --allow-root \
            && wp plugin activate wp-smushit --path=$WORDPRESS_HOME --allow-root; then
                echo "SMUSH_PLUGIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
            fi
        fi
    fi

    if [ $(grep -c "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ] && [ ! $(grep -c "EMAIL_P>
        if wp plugin deactivate app_service_email --quiet --path=$WORDPRESS_HOME --allow-root \
        && wp plugin activate app_service_email --path=$WORDPRESS_HOME --allow-root; then
            echo "EMAIL_PLUGIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
        fi
    fi

    if [ $(grep -c "SMUSH_PLUGIN_INSTALLED" $WORDPRESS_LOCK_FILE) -gt 0 ] && [ ! $(grep -c "SMUSH_PLUG>
        if wp option set skip-smush-setup 1 --path=$WORDPRESS_HOME --allow-root \
        && wp option patch update wp-smush-settings auto 1 --path=$WORDPRESS_HOME --allow-root \
        && wp option patch update wp-smush-settings lossy 0 --path=$WORDPRESS_HOME --allow-root \
        && wp option patch update wp-smush-settings strip_exif 1 --path=$WORDPRESS_HOME --allow-root \
        && wp option patch update wp-smush-settings original 1 --path=$WORDPRESS_HOME --allow-root \
        && wp option patch update wp-smush-settings lazy_load 0 --path=$WORDPRESS_HOME --allow-root \
        && wp option patch update wp-smush-settings usage 0 --path=$WORDPRESS_HOME --allow-root; then
            echo "SMUSH_PLUGIN_CONFIG_UPDATED" >> $WORDPRESS_LOCK_FILE
        fi
    fi

    if [ $(grep -c "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ] && [ ! $(grep -c "W3TC_PL>
        #backward compatibility for previous versions that don't have plugin source code in wordpress >
        if [ $(grep -c "GIT_PULL_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]; then
            if wp plugin install w3-total-cache --force --activate --path=$WORDPRESS_HOME --allow-root>
                echo "W3TC_PLUGIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
            fi
        else
            if wp plugin deactivate w3-total-cache --quiet --path=$WORDPRESS_HOME --allow-root \
            && wp plugin activate w3-total-cache --path=$WORDPRESS_HOME --allow-root; then
                echo "W3TC_PLUGIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
            fi
        fi
    fi

    if [ $(grep -c "W3TC_PLUGIN_INSTALLED" $WORDPRESS_LOCK_FILE) -gt 0 ] && [ ! $(grep -c "W3TC_PLUGIN>
        if mkdir -p $WORDPRESS_HOME/wp-content/cache/tmp \
        && mkdir -p $WORDPRESS_HOME/wp-content/w3tc-config \
        && wp w3-total-cache import $WORDPRESS_SOURCE/w3tc-config.json --path=$WORDPRESS_HOME --allow->
            echo "W3TC_PLUGIN_CONFIG_UPDATED" >> $WORDPRESS_LOCK_FILE
        fi
    fi
    
    setup_cdn_variables
    
    if [ $(grep -c "W3TC_PLUGIN_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) -gt 0 ] && [ ! $(grep -c "BLOB_S>
    && [ ! $(grep -c "FIRST_TIME_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ] && [[ "$IS_BLOB_STORAG>

        if ! [[ $BLOB_STORAGE_URL ]]; then
            BLOB_STORAGE_URL="${STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
        fi

        if [[ "${ENABLE_BLOB_MANAGED_IDENTITY,,}" == "true" ]] && [[ $ENTRA_CLIENT_ID ]]; then
            if wp w3-total-cache import $WORDPRESS_SOURCE/w3tc-blob-config-mi.json --path=$WORDPRESS_H>
            && wp w3-total-cache option set cdn.azuremi.user $STORAGE_ACCOUNT_NAME --path=$WORDPRESS_H>
            && wp w3-total-cache option set cdn.azuremi.container $BLOB_CONTAINER_NAME --path=$WORDPRE>
            && wp w3-total-cache option set cdn.azuremi.clientid $ENTRA_CLIENT_ID --path=$WORDPRESS_HO>
            && wp w3-total-cache option set cdn.enabled true --type=boolean --path=$WORDPRESS_HOME --a>
            && wp w3-total-cache option set cdn.azuremi.cname $BLOB_STORAGE_URL --type=array --path=$W>
            && wp plugin deactivate w3-total-cache --quiet --path=$WORDPRESS_HOME --allow-root \
            && wp plugin activate w3-total-cache --path=$WORDPRESS_HOME --allow-root; then
                echo "BLOB_STORAGE_CONFIGURATION_COMPLETE" >> $WORDPRESS_LOCK_FILE
            fi
        else
            if wp w3-total-cache import $WORDPRESS_SOURCE/w3tc-blob-config.json --path=$WORDPRESS_HOME>
            && wp w3-total-cache option set cdn.azure.user $STORAGE_ACCOUNT_NAME --path=$WORDPRESS_HOM>
            && wp w3-total-cache option set cdn.azure.container $BLOB_CONTAINER_NAME --path=$WORDPRESS>
            && wp w3-total-cache option set cdn.azure.key $STORAGE_ACCOUNT_KEY --path=$WORDPRESS_HOME >
            && wp w3-total-cache option set cdn.enabled true --type=boolean --path=$WORDPRESS_HOME --a>
            && wp w3-total-cache option set cdn.azure.cname $BLOB_STORAGE_URL --type=array --path=$WOR>
            && wp plugin deactivate w3-total-cache --quiet --path=$WORDPRESS_HOME --allow-root \
            && wp plugin activate w3-total-cache --path=$WORDPRESS_HOME --allow-root; then
                echo "BLOB_STORAGE_CONFIGURATION_COMPLETE" >> $WORDPRESS_LOCK_FILE
            fi
        fi
    fi
    
    if [ $(grep -c "W3TC_PLUGIN_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) -gt 0 ] && [ "$IS_CDN_ENABLED" =>
    && [ ! $(grep -c "BLOB_CDN_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) -gt 0 ] && [ ! $(grep -c >
        if [ "$IS_BLOB_STORAGE_ENABLED" == "True" ] && [ $(grep -c "BLOB_STORAGE_CONFIGURATION_COMPLET>
        && [ ! $(grep -c "BLOB_CDN_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) -gt 0 ]; then
            start_at_daemon
            echo "bash /usr/local/bin/w3tc_cdn_config.sh BLOB_CDN" | at now +10 minutes
        elif [ ! $(grep -c "CDN_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) -gt 0 ]; then
            start_at_daemon
            echo "bash /usr/local/bin/w3tc_cdn_config.sh CDN" | at now +10 minutes
        fi
    fi
    
    if [ $(grep -c "W3TC_PLUGIN_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) -gt 0 ] && [ "$IS_AFD_ENABLED" =>
    && [ ! $(grep -c "BLOB_AFD_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) -gt 0 ] && [ ! $(grep -c >
        if [ "$IS_BLOB_STORAGE_ENABLED" == "True" ] && [ $(grep -c "BLOB_STORAGE_CONFIGURATION_COMPLET>
        && [ ! $(grep -c "BLOB_AFD_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) -gt 0 ]; then
            start_at_daemon
            echo "bash /usr/local/bin/w3tc_cdn_config.sh BLOB_AFD" | at now +2 minutes
        elif [ ! $(grep -c "AFD_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) -gt 0 ]; then
            start_at_daemon
            echo "bash /usr/local/bin/w3tc_cdn_config.sh AFD" | at now +2 minutes
        fi
    fi

    if [  $(grep -c "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ] &&  [ ! $(grep -c "WP_LA>
            if [[ $WORDPRESS_LOCALE_CODE ]] && [[ ! "$WORDPRESS_LOCALE_CODE" == "en_US"  ]]; then
            if wp language core install $WORDPRESS_LOCALE_CODE --path=$WORDPRESS_HOME --allow-root \
                && wp site switch-language $WORDPRESS_LOCALE_CODE --path=$WORDPRESS_HOME --allow-root \
                && wp language theme install --all $WORDPRESS_LOCALE_CODE --path=$WORDPRESS_HOME --all>
                && wp language plugin install --all $WORDPRESS_LOCALE_CODE --path=$WORDPRESS_HOME --al>
                && wp language theme update --all --path=$WORDPRESS_HOME --allow-root \
                && wp language plugin update --all --path=$WORDPRESS_HOME --allow-root; then
                echo "WP_LANGUAGE_SETUP_COMPLETED" >> $WORDPRESS_LOCK_FILE
            fi
        else
            echo "WP_LANGUAGE_SETUP_COMPLETED" >> $WORDPRESS_LOCK_FILE
        fi
    fi

    translate_welcome_content
  # temporary change to fix smush plugin bug
  # if [ $(grep -c "W3TC_PLUGIN_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) -gt 0 ] && [ $(grep -c "SMUSH_PL>
    if [ $(grep -c "W3TC_PLUGIN_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) -gt 0 ] &&  [ ! $(grep -c "FIRST>
        echo "FIRST_TIME_SETUP_COMPLETED" >> $WORDPRESS_LOCK_FILE
    fi

    if [[ $(grep -c "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]] && [[ ! $(grep -c "MANA>
        && [[ $SETUP_MANAGED_IDENTITY ]] && [[ "${SETUP_MANAGED_IDENTITY,,}" == "true" ]]; then
        bash /usr/local/bin/managed-identity-setup.sh;
    fi

    if [ ! $AZURE_DETECTED ]; then 
            echo "INFO: NOT in Azure, chown for "$WORDPRESS_HOME 
            chown -R nginx:nginx $WORDPRESS_HOME
    fi
}

initialize_appservice_storage_variable() {
    IS_APPSERVICE_STORAGE_ENABLED="False"
    if [[ $WEBSITES_ENABLE_APP_SERVICE_STORAGE ]] && [[ "$WEBSITES_ENABLE_APP_SERVICE_STORAGE" == "tru>
            IS_APPSERVICE_STORAGE_ENABLED="True"
    fi
}

setup_commandline_startup_script() {
    test ! -d "/opt/startup" && echo "INFO: /opt/startup not found. Creating..." && mkdir -p /opt/star>
    touch /opt/startup/startup.sh
    startupCommandPath="/opt/startup/startup.sh"
    userStartupCommand="$@"
    
    if [ -n "$userStartupCommand" ]; then
        echo "$userStartupCommand" >> /opt/startup/startup.sh
    fi
   
    chmod +x /opt/startup/startup.sh
 }

setup_post_startup_script() {
    test ! -d "/home/dev" && echo "INFO: /home/dev not found. Creating..." && mkdir -p /home/dev
    touch /home/dev/startup.sh
    }

setup_nginx() {
    test ! -d "$NGINX_LOG_DIR" && echo "INFO: Log folder for nginx/php not found. creating..." && mkdi>
}

#echo "Setup openrc ..." && openrc && touch /run/openrc/softlevel

# Initialize variable to represent app service storage state
initialize_appservice_storage_variable

setup_nginx

if ! [[ $SKIP_WP_INSTALLATION ]] || ! [[ "$SKIP_WP_INSTALLATION" == "true" 
    || "$SKIP_WP_INSTALLATION" == "TRUE" || "$SKIP_WP_INSTALLATION" == "True" ]]; then
    if [[ "$IS_APPSERVICE_STORAGE_ENABLED" == "True" ]]; then
        setup_wordpress
    else
        #Update nginx config to display app service storage warning page
        #at end of this startup script
        echo "WEBSITES_ENABLE_APP_SERVICE_STORAGE app setting is disabled... Displaying warning page."
    fi
else 
    echo "INFO: Skipping WP installation..."
fi

# # Runs migrate.sh.. Retries 3 times.
# if [[ $MIGRATION_IN_PROGRESS ]] && [[ "$MIGRATION_IN_PROGRESS" == "true" || "$MIGRATION_IN_PROGRESS">
#     service atd start
#     echo "bash /usr/local/bin/migrate.sh 3" | at now +0 minutes
# fi

afd_update_site_url() {
    if [[ $AFD_ENABLED ]] && [[ "$AFD_ENABLED" == "true" || "$AFD_ENABLED" == "TRUE" || "$AFD_ENABLED">
        AFD_DOMAIN=$WEBSITE_HOSTNAME
        if [[ $CUSTOM_DOMAIN ]]; then
            AFD_DOMAIN=$CUSTOM_DOMAIN
        elif [[ $AFD_ENDPOINT ]]; then
            AFD_DOMAIN=$AFD_ENDPOINT
        fi

        if [ $(grep -c "BLOB_AFD_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) -gt 0 ] || [ $(grep -c >
            || [ $(grep -c "MULTISITE_CONVERSION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]; then
            wp config set WP_HOME "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_H>
            wp config set WP_SITEURL "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRES>
            wp option update SITEURL "https://$AFD_DOMAIN" --path=$WORDPRESS_HOME --allow-root
            wp option update HOME "https://$AFD_DOMAIN" --path=$WORDPRESS_HOME --allow-root

            if [ -e "$WORDPRESS_HOME/wp-config.php" ]; then
                AFD_HEADER_FILE='afd-header-settings.txt'
                AFD_CONFIG_DETECTED=''

                if [[ $(grep -c "MULTISITE_CONVERSION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]] && [[ >
                    AFD_CONFIG_DETECTED=$(grep "^\s*\$_SERVER\['HTTP_HOST'\]\s*=\s*\$_SERVER\['HTTP_X_>
                    AFD_HEADER_FILE='afd-multisite-header-settings.txt'
                    AFD_DOMAIN=''
                else
                    AFD_CONFIG_DETECTED=$(grep "^\s*\$_SERVER\['HTTP_HOST'\]\s*=\s*getenv('AFD_DOMAIN'>
                fi

                if [ -z "$AFD_CONFIG_DETECTED" ]; then
                    SEARCH_STR_I="Using environment variables for memory limits"
                    if [ ! -z "$(grep "${SEARCH_STR_I}" $WORDPRESS_HOME/wp-config.php)" ]; then
                        sed -i "/${SEARCH_STR_I}/e cat $WORDPRESS_SOURCE/$AFD_HEADER_FILE" $WORDPRESS_>
                    else
                        SEARCH_STR_II="Using environment variables for DB connection information"
                        if [ ! -z "$(grep "${SEARCH_STR_II}" $WORDPRESS_HOME/wp-config.php)" ]; then
                            sed -i "/${SEARCH_STR_II}/e cat $WORDPRESS_SOURCE/$AFD_HEADER_FILE" $WORDP>
                        fi
                    fi
                fi
            fi
        fi

        if [[ "$AFD_DOMAIN" == "$WEBSITE_HOSTNAME" ]]; then
            AFD_DOMAIN=''
        fi
    fi
}

# Update AFD URL
afd_update_site_url


# Multi-site conversion
if [[ $(grep -c "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]] && [[ ! $(grep -c "MULTISIT>
    && [[ $WORDPRESS_MULTISITE_CONVERT ]] && [[ "$WORDPRESS_MULTISITE_CONVERT" == "true" || "$WORDPRES>
    && [[ $WORDPRESS_MULTISITE_TYPE ]] && [[ "$WORDPRESS_MULTISITE_TYPE" == "subdirectory" || "$WORDPR>
    && [[ ! "$(wp config get MULTISITE --path=$WORDPRESS_HOME --allow-root 2> /dev/null)" ]]; then

    IS_AFD_ENABLED="False"
    if [[ $AFD_ENABLED ]] && [[ "$AFD_ENABLED" == "true" || "$AFD_ENABLED" == "TRUE" || "$AFD_ENABLED">
        IS_AFD_ENABLED="True"
    fi

    IS_W3TC_ENABLED="False"
    if wp plugin is-active w3-total-cache --path=$WORDPRESS_HOME --allow-root; then
        IS_W3TC_ENABLED="True"
    fi

    IS_SMUSHIT_ENABLED="False"
    if wp plugin is-active wp-smushit --path=$WORDPRESS_HOME --allow-root; then
        IS_SMUSHIT_ENABLED="True"
    fi

    ADD_SUBDOMAIN_FLAG=''
    MULTISITE_DOMAIN=$WEBSITE_HOSTNAME

    if [[ $CUSTOM_DOMAIN ]]; then
        MULTISITE_DOMAIN=$CUSTOM_DOMAIN
        if [[ "$WORDPRESS_MULTISITE_TYPE" == "subdomain" ]]; then
            ADD_SUBDOMAIN_FLAG='true'
        fi
    elif [[ "$IS_AFD_ENABLED" == "True" ]] && [[ $AFD_ENDPOINT ]] && [[ "$WORDPRESS_MULTISITE_TYPE" ==>
        MULTISITE_DOMAIN=$AFD_ENDPOINT
    fi

    if [[ "$WORDPRESS_MULTISITE_TYPE" == "subdomain" && "$MULTISITE_DOMAIN" != "$WEBSITE_HOSTNAME" ]] \
        || [[ "$WORDPRESS_MULTISITE_TYPE" == "subdirectory" ]]; then

        wp config set WP_HOME "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_HOME >
        wp config set WP_SITEURL "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_HO>

        if wp plugin deactivate --all --path=$WORDPRESS_HOME --allow-root \
        && wp core multisite-convert ${ADD_SUBDOMAIN_FLAG:+--subdomains} --url=$MULTISITE_DOMAIN --pat>

            # Removing duplicate occurance of DOMAIN_CURRENT_SITE
            wp config delete DOMAIN_CURRENT_SITE --path=$WORDPRESS_HOME --allow-root 2> /dev/null;
            wp config set DOMAIN_CURRENT_SITE "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=>
            wp config set WP_HOME "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_H>
            wp config set WP_SITEURL "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRES>
            wp option update SITEURL "https://$MULTISITE_DOMAIN" --path=$WORDPRESS_HOME --allow-root 2>
            wp option update HOME "https://$MULTISITE_DOMAIN" --path=$WORDPRESS_HOME --allow-root 2> />
            wp site option update fileupload_maxk 51200 --path=$WORDPRESS_HOME --allow-root 2> /dev/nu>
            echo "MULTISITE_CONVERSION_COMPLETED" >> $WORDPRESS_LOCK_FILE
        fi
    fi

    #Re-activate W3TC & SmushIt plugins
    if [[ "$IS_W3TC_ENABLED" == "True" ]]; then
        wp plugin activate w3-total-cache --path=$WORDPRESS_HOME --allow-root
    fi

    if [[ "$IS_SMUSHIT_ENABLED" == "True" ]]; then
        wp plugin activate wp-smushit --path=$WORDPRESS_HOME --allow-root
    fi

    # Update AFD URL
    afd_update_site_url
fi


# setup server root
if [ ! $AZURE_DETECTED ]; then 
    echo "INFO: NOT in Azure, chown for "$WORDPRESS_HOME 
    chown -R nginx:nginx $WORDPRESS_HOME
fi


# calculate Redis max memory 
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
Redis_Mem_UpperLimit=$(($RAM_KB*2/10))
Redis_Mem_KB=$(($RAM_KB/10))
if [[ $REDIS_MAX_MEMORY_MB =~ ^[0-9][0-9]*$ ]]; then
    if [[ $(($Redis_Mem_UpperLimit - $REDIS_MAX_MEMORY_MB*1024)) -ge 0 ]]; then 
        Redis_Mem_KB=$(($REDIS_MAX_MEMORY_MB*1024))
    else
        Redis_Mem_KB=$(($Redis_Mem_UpperLimit))
    fi
else
    echo "REDIS_MAX_MEMORY_MB must be an integer.."
fi
Redis_Mem_KB="${Redis_Mem_KB}KB"

echo "Starting Redis with Max Memory: ${Redis_Mem_KB}"
redis-server --maxmemory "$Redis_Mem_KB" --maxmemory-policy allkeys-lru &

if [ ! $AZURE_DETECTED ]; then  
    echo "NOT in AZURE, Start crond, log rotate..."     
    cron        
fi 


test ! -d "$SUPERVISOR_LOG_DIR" && echo "INFO: $SUPERVISOR_LOG_DIR not found. creating ..." && mkdir ->
test ! -e /home/50x.html && echo "INFO: 50x file not found. creating..." && cp /usr/share/nginx/html/5>

#Updating php configuration values
if [[ -e $PHP_CUSTOM_CONF_FILE ]]; then
    echo "INFO: Updating PHP configurations..."
    update_php_config $PHP_CUSTOM_CONF_FILE "file_uploads" $FILE_UPLOADS "TOGGLE"
    update_php_config $PHP_CUSTOM_CONF_FILE "memory_limit" $PHP_MEMORY_LIMIT "MEM" $UB_PHP_MEMORY_LIMIT
    update_php_config $PHP_CUSTOM_CONF_FILE "upload_max_filesize" $UPLOAD_MAX_FILESIZE "MEM" $UB_UPLOA>
    update_php_config $PHP_CUSTOM_CONF_FILE "post_max_size" $POST_MAX_SIZE "MEM" $UB_POST_MAX_SIZE
    update_php_config $PHP_CUSTOM_CONF_FILE "max_execution_time" $MAX_EXECUTION_TIME "NUM" $UB_MAX_EXE>
    update_php_config $PHP_CUSTOM_CONF_FILE "max_input_time" $MAX_INPUT_TIME "NUM" $UB_MAX_INPUT_TIME
    update_php_config $PHP_CUSTOM_CONF_FILE "max_input_vars" $MAX_INPUT_VARS "NUM" $UB_MAX_INPUT_VARS
fi

echo "INFO: creating /run/php/php-fpm.sock ..."
test -e /run/php/php-fpm.sock && rm -f /run/php/php-fpm.sock
mkdir -p /run/php
touch /run/php/php-fpm.sock
chown nginx:nginx /run/php/php-fpm.sock
chmod 777 /run/php/php-fpm.sock

#sed -i "s/SSH_PORT/$SSH_PORT/g" /etc/ssh/sshd_config
# starting sshd process
source /opt/startup/ssh_setup.sh
source /opt/startup/startssh.sh
# Install ca-certificates
source /opt/startup/install_ca_certs.sh

echo "Starting SSH ..."
echo "Starting php-fpm ..."
echo "Starting Nginx ..."

UNISON_EXCLUDED_PATH="wp-content/uploads"
IS_LOCAL_STORAGE_OPTIMIZATION_POSSIBLE="False"

if [[ $(grep -c "FIRST_TIME_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]] && [[ $WORDPRESS_LOCAL_STO>
    if [[ "$WEBSITE_SKU" == "LinuxFree" ]]; then
        MAXIMUM_LOCAL_STORAGE_SIZE_BYTES=$MAXIMUM_LOCAL_STORAGE_SIZE_BYTES_FREESKU
    fi

    CURRENT_WP_SIZE="`du -sb --apparent-size $WORDPRESS_HOME/ --exclude="wp-content/uploads" | cut -f1>
    if [ "$CURRENT_WP_SIZE" -lt "$MAXIMUM_LOCAL_STORAGE_SIZE_BYTES" ]; then
        IS_LOCAL_STORAGE_OPTIMIZATION_POSSIBLE="True"
    else
        CURRENT_WP_SIZE="`du -sb --apparent-size $WORDPRESS_HOME/ --exclude="wp-content" | cut -f1`"
        if [ "$CURRENT_WP_SIZE" -lt "$MAXIMUM_LOCAL_STORAGE_SIZE_BYTES" ]; then
            IS_LOCAL_STORAGE_OPTIMIZATION_POSSIBLE="True"
            UNISON_EXCLUDED_PATH="wp-content"
        fi
    fi
fi
export UNISON_EXCLUDED_PATH


IS_AFD_ENABLED="False"
if [[ $AFD_ENABLED ]] && [[ "$AFD_ENABLED" == "true" || "$AFD_ENABLED" == "TRUE" || "$AFD_ENABLED" == >
    IS_AFD_ENABLED="True"
fi

if [[ $IS_APPSERVICE_STORAGE_ENABLED == "True" ]]; then

    if [[ $SETUP_PHPMYADMIN ]] && [[ "$SETUP_PHPMYADMIN" == "true" || "$SETUP_PHPMYADMIN" == "TRUE" ||>
        if [[ $(grep -c "MULTISITE_CONVERSION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]] && [[ $WORDPRE>
            cp /usr/src/nginx/wordpress-subdirectory-multisite-phpmyadmin-server.conf /etc/nginx/conf.>
        elif [[ $(grep -c "MULTISITE_CONVERSION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]] && [[ $WORDP>
            cp /usr/src/nginx/wordpress-subdomain-afd-multisite-phpmyadmin-server.conf /etc/nginx/conf>
        else
            cp /usr/src/nginx/wordpress-phpmyadmin-server.conf /etc/nginx/conf.d/default.conf
        fi
    else
        if [[ $(grep -c "MULTISITE_CONVERSION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]] && [[ $WORDPRE>
            cp /usr/src/nginx/wordpress-subdirectory-multisite-server.conf /etc/nginx/conf.d/default.c>
        elif [[ $(grep -c "MULTISITE_CONVERSION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]] && [[ $WORDP>
            cp /usr/src/nginx/wordpress-subdomain-afd-multisite-server.conf /etc/nginx/conf.d/default.>
        else
            cp /usr/src/nginx/wordpress-server.conf /etc/nginx/conf.d/default.conf
        fi
    fi

    # Initial site's root directory is set to /home/site/wwwroot
    sed -i "s#WORDPRESS_HOME#${WORDPRESS_HOME}#g" /etc/nginx/conf.d/default.conf
else
    # initialize /home/site/temp-root
    initialize_temp_root
    
    # update nginx conf to display warning page at /home/site/temp-root/
    cp /usr/src/nginx/temp-server-appservicestorage.conf /etc/nginx/conf.d/default.conf
fi

if [ $DISPLAY_WP_INSTALLED_WARNING_PAGE == "True" ]; then
     setup_wp_installed_page
fi

if [ "$IS_LOCAL_STORAGE_OPTIMIZATION_POSSIBLE" == "True" ]; then
    cp /usr/src/supervisor/supervisord-stgoptmzd.conf /etc/supervisord.conf
    # updating the placeholders values in other files
    sed -i "s#WORDPRESS_HOME#${WORDPRESS_HOME}#g" /etc/supervisord.conf
    sed -i "s#HOME_SITE_LOCAL_STG#${HOME_SITE_LOCAL_STG}#g" /etc/supervisord.conf
    sed -i "s#UNISON_EXCLUDED_PATH#${UNISON_EXCLUDED_PATH}#g" /etc/supervisord.conf
    sed -i "s#UNISON_EXCLUDED_PATH#${UNISON_EXCLUDED_PATH}#g" /usr/local/bin/inotifywait-perms-service>
else
    cp /usr/src/supervisor/supervisord-original.conf /etc/supervisord.conf
fi

# enabling internal kusto telemetry
if [[ ! $DISABLE_WORDPRESS_TELEMETRY  ]] || [[ "$DISABLE_WORDPRESS_TELEMETRY " != "true" && "$DISABLE_>
    if [[ "$IS_APPSERVICE_STORAGE_ENABLED" == "True" ]]; then

        # Add supervisord config for Wordpress Kusto telemetry
        KUSTO_TELEMETRY_SEARCH_STR=";Kusto telemetry config placeholder"
        if grep -q "${KUSTO_TELEMETRY_SEARCH_STR}" /etc/supervisord.conf; then
            sed -i "/${KUSTO_TELEMETRY_SEARCH_STR}/r /usr/src/supervisor/kusto-telemetry-supervisord-c>
        fi

        # This is used by telemetry script to avoid log generation immediately after container starts >
        echo "$(date +%s%3N)" > "$WORDPRESS_LOCK_HOME/__lastRestartTime.txt"
    fi
fi

if [ "$IS_TEMP_SERVER_STARTED" == "True" ]; then
    temp_server_stop
fi

# Update the nginx configuration if xmlrpc is enabled
setup_xmlrpc

# Get environment variables to show up in SSH session
# This will replace any \ (backslash), " (double quote), $ (dollar sign) and ` (back quote) symbol by >
(printenv | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/\\/\\\\/g' | sed 's/"/\\\"/g' | sed>

setup_commandline_startup_script "$@"

setup_post_startup_script 

cd /usr/bin/
supervisord -c /etc/supervisord.conf
