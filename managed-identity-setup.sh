#!/bin/bash

# if wordpress_lock_file doesn't exists, then exit
if [ ! -f $WORDPRESS_LOCK_FILE ]; then
    echo "Wordpress status file not found";
    exit 1;
fi

# If Wordpress installation is not completed, then exit
if [ ! $(grep -c "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]; then
    echo "Wordpress installation not completed";
    exit 1;
fi

# iIf Managed Identity setup is already completed, then exit
if [ $(grep -c "MANAGED_IDENTITY_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) -gt 0 ]; then
    echo "Managed Identity setup is already completed";
    exit 0;
fi

# Update PhpMyAdmin code to relax password length limit
PHPMYADMIN_UPDATED="false";
if [ ! -f $PHPMYADMIN_HOME/libraries/classes/Plugins/Auth/AuthenticationCookie.php ] \
    || cp $PHPMYADMIN_SOURCE/phpmyadmin/libraries/classes/Plugins/Auth/AuthenticationCookie.php $PHPMY>
    PHPMYADMIN_UPDATED="true"
fi


WP_CONFIG_UPDATED="false";
DB_ENTRA_TOKEN_UTILITY_FILE_UPDATED="false";

# Copy the database entra token utility file
if cp $WORDPRESS_SOURCE/wordpress-azure/class_entra_database_token_utility.php $WORDPRESS_HOME/class_e>
    DB_ENTRA_TOKEN_UTILITY_FILE_UPDATED="true";
fi
# Update wp-config.php file to fetch token using managed identity
MANAGED_IDENTITY_WP_CONFIG_FILE=$WORDPRESS_SOURCE/managed-identity-wp-config.txt
if [ ! $(grep -c "Using managed identity to fetch MySQL access token" $WORDPRESS_HOME/wp-config.php) ->
    SEARCH_STR_I="^\s*\$connectstr_dbpassword\s*=\s*getenv('DATABASE_PASSWORD');"
    if [ ! -z "$(grep "${SEARCH_STR_I}" $WORDPRESS_HOME/wp-config.php)" ]; then
        sed -i "/${SEARCH_STR_I}/r $MANAGED_IDENTITY_WP_CONFIG_FILE" $WORDPRESS_HOME/wp-config.php
        WP_CONFIG_UPDATED="true";
    else
        SEARCH_STR_II="\/\*\* MySQL database password \*\/"
        if [ ! -z "$(grep "${SEARCH_STR_II}" $WORDPRESS_HOME/wp-config.php)" ]; then
            sed -i "/${SEARCH_STR_II}/r $MANAGED_IDENTITY_WP_CONFIG_FILE" $WORDPRESS_HOME/wp-config.php
            WP_CONFIG_UPDATED="true";
        fi
    fi
else
    WP_CONFIG_UPDATED="true";
fi


# Update App Service Email Plugin
EMAIL_PLUGIN_UPDATED="false";
if [ -d $WORDPRESS_HOME/wp-content/plugins/app_service_email ]; then
    # Deactivate and remove existing Email plugin
    wp plugin deactivate app_service_email --quiet --path=$WORDPRESS_HOME --allow-root;
    wp plugin delete app_service_email --path=$WORDPRESS_HOME --allow-root;
    rm -rf $WORDPRESS_HOME/wp-content/plugins/app_service_email;
    #sleep 5;
fi
# Copy the new plugin and activate it    
if cp -r $WORDPRESS_SOURCE/wordpress-azure/wp-content/plugins/app_service_email $WORDPRESS_HOME/wp-con>
    if [[ $WP_EMAIL_CONNECTION_STRING ]]; then
        wp plugin activate app_service_email --path=$WORDPRESS_HOME --allow-root;
    fi
    EMAIL_PLUGIN_UPDATED="true";
fi


# Update Wordpress lock file
if [ $PHPMYADMIN_UPDATED == "true" ] && [ $EMAIL_PLUGIN_UPDATED == "true" ] && [ $WP_CONFIG_UPDATED ==>
    echo "MANAGED_IDENTITY_SETUP_COMPLETED" >> $WORDPRESS_LOCK_FILE;
    echo "Managed Identity setup completed successfully";
fi
