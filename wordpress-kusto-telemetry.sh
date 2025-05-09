#!/bin/bash
while true;
do
# logs from this path are pushed to kusto
WP_TELEMETRY_PATH="/home/LogFiles/wordpresslogs"
if [ ! -d "$WP_TELEMETRY_PATH" ]; then
    mkdir -p "$WP_TELEMETRY_PATH" || exit 1
fi

# delete log files which were modified more than 24 hours ago
find "$WP_TELEMETRY_PATH" -name 'wordpress*.log' -type f -mtime +0 | while read -r expired_file; do
    rm -f "$expired_file"
done

# Logging window is set to 12 hours for lower SKUs and 6 hours for higher SKUs.
# Initial delay is set to 15 minutes for all SKUs except LinuxFree/Free/Shared.
LOG_WINDOW_IN_MS=21600000
INITIAL_DELAY_IN_MS=900000
if [[ "$WEBSITE_SKU" == "Basic" || "$WEBSITE_SKU" == "LinuxFree" || "$WEBSITE_SKU" == "Free" || "$WEBSITE_SKU" == "Shared" ]]; then
    LOG_WINDOW_IN_MS=43200000
    if [[ "$WEBSITE_SKU" != "Basic" ]]; then
        INITIAL_DELAY_IN_MS=0
    fi
fi

# Wait for at least 15 minutes after the container start up before generating logs.
RESTART_STATUS_FILE="$WORDPRESS_LOCK_HOME/__lastRestartTime.txt"
if [[ -f "$RESTART_STATUS_FILE" ]]; then
    LAST_RESTART_TIME=$(head -n 1 "$RESTART_STATUS_FILE")
    if [[ "$LAST_RESTART_TIME" =~ ^[0-9]+$ ]] && [[ $(($(date +%s%3N) - $LAST_RESTART_TIME)) -lt $INITIAL_DELAY_IN_MS ]]; then
        sleep 3600
        continue
    fi
fi

# check __lastLogGenTime.txt file to get the last logging timestamp
# if it is not present or less than 6 hours, then exit
WORDPRESS_LOG_STATUS_FILE="$WORDPRESS_LOCK_HOME/__lastLogGenTime.txt"
if [[ -f "$WORDPRESS_LOG_STATUS_FILE" ]]; then
    LAST_LOG_GEN_TIME=$(head -n 1 "$WORDPRESS_LOG_STATUS_FILE")
    if  [[ "$LAST_LOG_GEN_TIME" =~ ^[0-9]+$ ]] && [[ $(($(date +%s%3N) - $LAST_LOG_GEN_TIME)) -lt $LOG_WINDOW_IN_MS ]]; then
        sleep 3600
        continue 
    fi
fi 

# populate commond attributes
EVENT_START_IN_MILLIS=$(date +%s%3N)
START_OF_DAY_IN_MILLIS=$(($(date -d "today 00:00:00" +"%s") * 1000))
EVENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S.%3N")
SITE_NAME=$(echo "$WEBSITE_SITE_NAME" | sed 's/,/ /g')
PHP_VERSION=$(php -v | head -1 | awk '{print $2}' | sed 's/,/ /g')
OS_DETAILS=$(cat /etc/os-release | grep PRETTY_NAME | cut -d "=" -f 2 | sed 's/"//g' | sed 's/,/ /g')
WP_VERSION=$(wp core version --path="$WORDPRESS_HOME" --quiet --allow-root 2> /dev/null | sed 's/,/ /g')
FX_VERSION=$(echo "$LINUX_FX_VERSION" | sed 's/,/ /g')
ANT_VERSION=$(echo "$PLATFORM_VERSION" | sed 's/,/ /g')
LOG_LEVEL="1"

# find out whether single site, multisite subdomain or multisite subdirectory
WP_SITE_TYPE="single_site"
if [[ "$(wp config get WP_ALLOW_MULTISITE --path="$WORDPRESS_HOME" --quiet --allow-root 2> /dev/null)" == "1" ]] && [[ "$(wp config get MULTISITE --path="$WORDPRESS_HOME" --allow-root 2> >
    SUBDOMAIN_INSTALL_VALUE=$(wp config get SUBDOMAIN_INSTALL --path="$WORDPRESS_HOME" --quiet --allow-root 2> /dev/null)
    if [[ $? -eq 0 ]]; then
        if [[ "$SUBDOMAIN_INSTALL_VALUE" == "1" ]]; then
            WP_SITE_TYPE="multisite_subdomain"
        else
            WP_SITE_TYPE="multisite_subdirectory"
        fi
    fi
fi

generate_general_logs() {
    local GENERAL_LOG_TYPE="general_logs"

    local IS_CDN_CONFIGURED="false"
    if [[ $CDN_ENABLED ]] && [[ "$CDN_ENABLED" == "true" || "$CDN_ENABLED" == "TRUE" || "$CDN_ENABLED" == "True" ]] && [[ $CDN_ENDPOINT ]]; then
        IS_CDN_CONFIGURED="true"
    fi
    
    local IS_AFD_CONFIGURED="false"
    if [[ $AFD_ENABLED ]] && [[ "$AFD_ENABLED" == "true" || "$AFD_ENABLED" == "TRUE" || "$AFD_ENABLED" == "True" ]] && [[ $AFD_ENDPOINT ]]; then
        IS_AFD_CONFIGURED="true"
    fi
    
    local IS_BLOB_STORAGE_CONFIGURED="false"
    if [[ $BLOB_STORAGE_ENABLED ]] && [[ "$BLOB_STORAGE_ENABLED" == "true" || "$BLOB_STORAGE_ENABLED" == "TRUE" || "$BLOB_STORAGE_ENABLED" == "True" ]] \
    && [[ $STORAGE_ACCOUNT_NAME ]] && [[ $STORAGE_ACCOUNT_KEY ]] && [[ $BLOB_CONTAINER_NAME ]]; then
            IS_BLOB_STORAGE_CONFIGURED="true"
    fi

    local IS_EMAIL_CONFIGURED="false"
    if [[ $WP_EMAIL_CONNECTION_STRING ]] ; then
        IS_EMAIL_CONFIGURED="true"
    fi

    local IS_LOCAL_STORAGE_CACHE_CONFIGURED="false"
    if [[ $WORDPRESS_LOCAL_STORAGE_CACHE_ENABLED ]] && [[ "$WORDPRESS_LOCAL_STORAGE_CACHE_ENABLED" == "1" || "$WORDPRESS_LOCAL_STORAGE_CACHE_ENABLED" == "true" || "$WORDPRESS_LOCAL_STORAG>
        IS_LOCAL_STORAGE_CACHE_CONFIGURED="true"
    fi

    local IS_PHPMYADMIN_CONFIGURED="false"
    if [[ $SETUP_PHPMYADMIN ]] && [[ "$SETUP_PHPMYADMIN" == "true" || "$SETUP_PHPMYADMIN" == "TRUE" || "$SETUP_PHPMYADMIN" == "True" ]]; then
        IS_PHPMYADMIN_CONFIGURED="true"
    fi
    
    local IS_MI_INTEGRATED_WITH_APPSERVICE="false"
    if [[ $IDENTITY_ENDPOINT ]] && [[ $IDENTITY_HEADER ]]; then
        IS_MI_INTEGRATED_WITH_APPSERVICE="true"
    fi

    local IS_MYSQL_MANAGED_IDENTITY_ENABLED="false"
    local IS_MYSQL_TOKEN_UTILITY_FILE_PRESENT="false"
    if [[ $ENABLE_MYSQL_MANAGED_IDENTITY ]] && [[ "$ENABLE_MYSQL_MANAGED_IDENTITY" == "true" || "$ENABLE_MYSQL_MANAGED_IDENTITY" == "TRUE" || "$ENABLE_MYSQL_MANAGED_IDENTITY" == "True" ]]>
        IS_MYSQL_MANAGED_IDENTITY_ENABLED="true"
        if [[ -f "$WORDPRESS_HOME/class_entra_database_token_utility.php" ]]; then
            IS_MYSQL_TOKEN_UTILITY_FILE_PRESENT="true"
        fi
    fi

    local IS_EMAIL_MANAGED_IDENTITY_ENABLED="false"
    local IS_EMAIL_TOKEN_UTILITY_FILE_PRESENT="false"
    if [[ $ENABLE_EMAIL_MANAGED_IDENTITY ]] && [[ "$ENABLE_EMAIL_MANAGED_IDENTITY" == "true" || "$ENABLE_EMAIL_MANAGED_IDENTITY" == "TRUE" || "$ENABLE_EMAIL_MANAGED_IDENTITY" == "True" ]]>
        IS_EMAIL_MANAGED_IDENTITY_ENABLED="true"
        if [[ -f "$WORDPRESS_HOME/wp-content/plugins/app_service_email/admin/mailer/class_entra_email_token_utility.php" ]]; then
            IS_EMAIL_TOKEN_UTILITY_FILE_PRESENT="true"
        fi
    fi


    local IS_MULTISITE_CONFIGURED="false"
    local MULTISITE_TYPE_CONFIGURED="none"
    if [[ $WORDPRESS_MULTISITE_CONVERT ]] && [[ "$WORDPRESS_MULTISITE_CONVERT" == "true" || "$WORDPRESS_MULTISITE_CONVERT" == "TRUE" || "$WORDPRESS_MULTISITE_CONVERT" == "True" ]] \
        && [[ $WORDPRESS_MULTISITE_TYPE ]] && [[ "$WORDPRESS_MULTISITE_TYPE" == "subdirectory" || "$WORDPRESS_MULTISITE_TYPE" == "subdomain" ]]; then
        IS_MULTISITE_CONFIGURED="true"
        MULTISITE_TYPE_CONFIGURED="$WORDPRESS_MULTISITE_TYPE"
    fi

    local WP_DEPLOYMENT_STATUS_DATA="\"\""
    if [[ -f "$WORDPRESS_LOCK_FILE" ]]; then
        # Escape special characters to add with JSON
        WP_DEPLOYMENT_STATUS_DATA=$(jq -Rsa . "$WORDPRESS_LOCK_FILE")
    fi

    # Use WP CLI to get themes and plugins stats. If it is not working, then use find command
    local LIST_OF_THEMES=$(wp theme list --format=json --quiet --path="$WORDPRESS_HOME" --allow-root 2> /dev/null)
    local LIST_OF_PLUGINS=$(wp plugin list --format=json --quiet --path="$WORDPRESS_HOME" --allow-root 2> /dev/null)

    #check if LIST_OF_THEMES and LIST_OF_PLUGINS are valid json strings
    echo "$LIST_OF_THEMES" | jq empty 2> /dev/null
    if [[ $? -ne 0 ]]; then
        LIST_OF_THEMES="[]"
    fi
    echo "$LIST_OF_PLUGINS" | jq empty 2> /dev/null
    if [[ $? -ne 0 ]]; then
        LIST_OF_PLUGINS="[]"
    fi

    local NUMBER_OF_THEMES=$(echo "$LIST_OF_THEMES" | grep -o \"name\" | wc -l)
    local NUMBER_OF_PLUGINS=$(echo "$LIST_OF_PLUGINS" | grep -o \"name\" | wc -l)
    local NUMBER_OF_ACTIVE_THEMES=$(echo "$LIST_OF_THEMES" | grep -o \"status\":\"active\" | wc -l)
    local NUMBER_OF_ACTIVE_PLUGINS=$(echo "$LIST_OF_PLUGINS" | grep -o \"status\":\"active\" | wc -l)
    
    if [[ $NUMBER_OF_PLUGINS -eq 0 ]]; then
        LIST_OF_PLUGINS=$(find "$WORDPRESS_HOME/wp-content/plugins" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; 2> /dev/null | jq -Rnc '[inputs | {"name": .}]')
        NUMBER_OF_PLUGINS=$(find "$WORDPRESS_HOME/wp-content/plugins" -maxdepth 1 -mindepth 1 -type d 2> /dev/null | wc -l)
    fi
    
    if [[ $NUMBER_OF_THEMES -eq 0 ]]; then
        LIST_OF_THEMES=$(find "$WORDPRESS_HOME/wp-content/themes" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; 2> /dev/null | jq -Rnc '[inputs | {"name": .}]')
        NUMBER_OF_THEMES=$(find "$WORDPRESS_HOME/wp-content/themes" -maxdepth 1 -mindepth 1 -type d 2> /dev/null | wc -l)
    fi

    # defining timeout (secs) for file stat commands as they can take longer time
    local MAX_CMD_TIMEOUT=180

    # number of files and total size in $WORDPRESS_HOME/wp-content/uploads
    local UPLOADS_FILES=$(timeout $MAX_CMD_TIMEOUT bash -c 'find "$WORDPRESS_HOME/wp-content/uploads" -type f 2> /dev/null | wc -l')
    local UPLOADS_SIZE=$(timeout $MAX_CMD_TIMEOUT bash -c 'du -sb --apparent-size "$WORDPRESS_HOME/wp-content/uploads" 2> /dev/null | awk '\''{print $1}'\''')

    # number of files and total size in $WORDPRESS_HOME/wp-content/themes
    local THEMES_FILES=$(timeout $MAX_CMD_TIMEOUT bash -c 'find "$WORDPRESS_HOME/wp-content/themes" -type f 2> /dev/null | wc -l')
    local THEMES_SIZE=$(timeout $MAX_CMD_TIMEOUT bash -c 'du -sb --apparent-size "$WORDPRESS_HOME/wp-content/themes" 2> /dev/null | awk '\''{print $1}'\''')

    # number of files and total size in $WORDPRESS_HOME/wp-content/plugins
    local PLUGINS_FILES=$(timeout $MAX_CMD_TIMEOUT bash -c 'find "$WORDPRESS_HOME/wp-content/plugins" -type f 2> /dev/null | wc -l')
    local PLUGINS_SIZE=$(timeout $MAX_CMD_TIMEOUT bash -c 'du -sb --apparent-size "$WORDPRESS_HOME/wp-content/plugins" 2> /dev/null | awk '\''{print $1}'\''')

    # number of files and total size in $WORDPRESS_HOME/wp-content
    local WP_CONTENT_FILES=$(timeout $MAX_CMD_TIMEOUT bash -c 'find "$WORDPRESS_HOME/wp-content" -type f 2> /dev/null | wc -l')
    local WP_CONTENT_SIZE=$(timeout $MAX_CMD_TIMEOUT bash -c 'du -sb --apparent-size "$WORDPRESS_HOME/wp-content" 2> /dev/null | awk '\''{print $1}'\''')

    # number of files and total size in $WORDPRESS_HOME excluding wp-content
    local WP_CORE_FILES=$(timeout $MAX_CMD_TIMEOUT bash -c 'find "$WORDPRESS_HOME" -type f ! -path "$WORDPRESS_HOME/wp-content/*" 2> /dev/null | wc -l')
    local WP_CORE_SIZE=$(timeout $MAX_CMD_TIMEOUT bash -c 'du -sb --apparent-size "$WORDPRESS_HOME" --exclude="wp-content" 2> /dev/null | awk '\''{print $1}'\''')

    # check if the nginx config file is pointing to '/var/www/wordpress'
    local IS_LOCAL_STORAGE_CACHE_INITIALIZED="false"
    if [[ -f "/etc/nginx/conf.d/default.conf" ]] && [[ $HOME_SITE_LOCAL_STG ]]; then
        if [[ $(grep -v '^[[:space:]]*#' /etc/nginx/conf.d/default.conf | grep -m1 -c "root $HOME_SITE_LOCAL_STG") -gt 0 ]]; then
            IS_LOCAL_STORAGE_CACHE_INITIALIZED="true"
        fi
    fi

    # check if /home/dev/startup.sh is being used
    local CUSTOM_START_SCRIPT_USED="false"
    if [[ -s "/home/dev/startup.sh" ]] && grep -q "\S" "/home/dev/startup.sh"; then
        CUSTOM_START_SCRIPT_USED="true"
    fi

    # time taken to prepare the data
    local TIME_TAKEN_IN_MS=$(($(date +%s%3N) - $EVENT_START_IN_MILLIS))

    local GENERAL_LOG_DATA="{ \
            \"TimeTakenInMs\": $TIME_TAKEN_IN_MS, \
            \"IsBlobConfigured\": \"$IS_BLOB_STORAGE_CONFIGURED\", \
            \"IsAFDConfigured\": \"$IS_AFD_CONFIGURED\", \
            \"IsCDNConfigured\": \"$IS_CDN_CONFIGURED\", \
            \"IsEmailConfigured\": \"$IS_EMAIL_CONFIGURED\", \
            \"IsMultisiteConfigured\": \"$IS_MULTISITE_CONFIGURED\", \
            \"MultisiteTypeConfigured\": \"$MULTISITE_TYPE_CONFIGURED\", \
            \"IsLocalStorageCacheConfigured\": \"$IS_LOCAL_STORAGE_CACHE_CONFIGURED\", \
            \"IsLocalStorageCacheInitialized\": \"$IS_LOCAL_STORAGE_CACHE_INITIALIZED\", \
            \"IsPhpMyAdminConfigured\": \"$IS_PHPMYADMIN_CONFIGURED\", \
            \"CustomStartScriptUsed\": \"$CUSTOM_START_SCRIPT_USED\", \
            \"IsManagedIdentityIntegratedWithAppService\": \"$IS_MI_INTEGRATED_WITH_APPSERVICE\", \
            \"IsMySQLManagedIdentityEnabled\": \"$IS_MYSQL_MANAGED_IDENTITY_ENABLED\", \
            \"IsMySQLTokenUtilityFilePresent\": \"$IS_MYSQL_TOKEN_UTILITY_FILE_PRESENT\", \
            \"IsEmailManagedIdentityEnabled\": \"$IS_EMAIL_MANAGED_IDENTITY_ENABLED\", \
            \"IsEmailTokenUtilityFilePresent\": \"$IS_EMAIL_TOKEN_UTILITY_FILE_PRESENT\", \
            \"SKUType\": \"$WEBSITE_SKU\", \
            \"OSDetails\": \"$OS_DETAILS\", \
            \"NumberOfThemes\": \"$NUMBER_OF_THEMES\", \
            \"NumberOfPlugins\": \"$NUMBER_OF_PLUGINS\", \
            \"ActiveThemesCount\": \"$NUMBER_OF_ACTIVE_THEMES\", \
            \"ActivePluginsCount\": \"$NUMBER_OF_ACTIVE_PLUGINS\", \
            \"UploadsFilesCount\": \"$UPLOADS_FILES\", \
            \"UploadsSize\": \"$UPLOADS_SIZE\", \
            \"ThemesFilesCount\": \"$THEMES_FILES\", \
            \"ThemesSize\": \"$THEMES_SIZE\", \
            \"PluginsFilesCount\": \"$PLUGINS_FILES\", \
            \"PluginsSize\": \"$PLUGINS_SIZE\", \
            \"WPContentFilesCount\": \"$WP_CONTENT_FILES\", \
            \"WPContentSize\": \"$WP_CONTENT_SIZE\", \
            \"WPCoreFilesCount\": \"$WP_CORE_FILES\", \
            \"WPCoreSize\": \"$WP_CORE_SIZE\", \
            \"DeploymentStatusData\": $WP_DEPLOYMENT_STATUS_DATA, \
            \"ListOfThemes\": $LIST_OF_THEMES, \
            \"ListOfPlugins\": $LIST_OF_PLUGINS \
        }"

    local GENERAL_LOG_REGEX="${EVENT_TIME},${SITE_NAME},${GENERAL_LOG_TYPE},${LOG_LEVEL},${FX_VERSION},${PHP_VERSION},${WP_VERSION},${WP_SITE_TYPE},${ANT_VERSION},${GENERAL_LOG_DATA}"
    echo "$GENERAL_LOG_REGEX" >> "${WP_TELEMETRY_PATH}/wordpress_${START_OF_DAY_IN_MILLIS}.log"
    echo "$EVENT_START_IN_MILLIS" > "$WORDPRESS_LOG_STATUS_FILE"
}

generate_general_logs
sleep 3600
done
