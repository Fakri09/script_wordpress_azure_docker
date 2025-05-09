#!/bin/bash

test ! -d $FILESYNC_STATUS_FILE_DIR && mkdir -p $FILESYNC_STATUS_FILE_DIR
touch $FILESYNC_STATUS_FILE_PATH

trycount=1

while [ $trycount -le 3 ]
do
        #initial copy from /home/site/wwwroot to /var/www/wordpress
        if [ ! $(grep -c "RSYNC_COMPLETED" $FILESYNC_STATUS_FILE_PATH) -gt 0 ]; then
                rsync -a $WORDPRESS_HOME/ $HOME_SITE_LOCAL_STG/ --exclude $UNISON_EXCLUDED_PATH
                exit_code=$?
                if [ $exit_code -eq 0 ] || [ $exit_code -eq 24 ]; then
                        echo "RSYNC_COMPLETED" >> $FILESYNC_STATUS_FILE_PATH
                fi
        fi
        
        #run synchronous unison command that generates checksums for faster asynchronous unison filesy>
        #faster asynchronous unison ensures filesync happens before nginx is started after 10 min
        if [ $(grep -c "RSYNC_COMPLETED" $FILESYNC_STATUS_FILE_PATH) -gt 0 ] && [ ! $(grep -c "SYNCHRO>
        && unison WORDPRESS_HOME HOME_SITE_LOCAL_STG -auto -batch -times -copythreshold 1000 -prefer W>
                echo "SYNCHRONOUS_UNISON_COMPLETED" >> $FILESYNC_STATUS_FILE_PATH
        fi

        # Update file permissions an directory ownership after initial copy
        if [ $(grep -c "SYNCHRONOUS_UNISON_COMPLETED" $FILESYNC_STATUS_FILE_PATH) -gt 0 ] && [ ! $(gre>
        && ln -s $WORDPRESS_HOME/$UNISON_EXCLUDED_PATH $HOME_SITE_LOCAL_STG/$UNISON_EXCLUDED_PATH \
        && chown -R nginx:nginx $HOME_SITE_LOCAL_STG \
        && chmod -R 777 $HOME_SITE_LOCAL_STG; then
                echo "INITIAL_FILESYNC_COMPLETED" >> $FILESYNC_STATUS_FILE_PATH
        fi

        # start unison for continuous filesync
        if [ $(grep -c "INITIAL_FILESYNC_COMPLETED" $FILESYNC_STATUS_FILE_PATH) -gt 0 ] && [ ! $(grep >
        && supervisorctl start unison \
        && supervisorctl start perms-service \
        && supervisorctl start inotifywait-perms-service \
        && supervisorctl start unison-cleanup-service; then
                echo "UNISON_PROCESS_STARTED" >> $FILESYNC_STATUS_FILE_PATH
        fi

        if [ $(grep -c "UNISON_PROCESS_STARTED" $FILESYNC_STATUS_FILE_PATH) -gt 0 ] && [ ! $(grep -c ">
                sleep 180       # wait 3min for unison to sync fileserver and local storage before rel>
                if sed -i "s#${WORDPRESS_HOME}#${HOME_SITE_LOCAL_STG}#g" /etc/nginx/conf.d/default.con>
                        && /usr/sbin/nginx -s reload; then
                        echo "NGINX_CONFIG_UPDATED" >> $FILESYNC_STATUS_FILE_PATH
                        break
                fi
        fi

        trycount=$(($trycount+1))
done
