#!/bin/bash
#trap "kill -- -$$" EXIT

MIN_VERSION="3.21.9.0"
CURR_VERSION=$(inotifywait -h | head -1 | awk '{print $2}')
TIMEOUT_SECONDS=0
if [ $(echo -e "${CURR_VERSION}\n${MIN_VERSION}" | sort -V | head -1) != "${MIN_VERSION}" ]; then
        TIMEOUT_SECONDS=-1
fi

inotifywait -mrq -e CREATE -e MOVED_TO -e CLOSE_WRITE -t ${TIMEOUT_SECONDS} --format %w%f "$HOME_SITE_>
do
        chown nginx:nginx $FILE
        chmod 777 $FILE
done