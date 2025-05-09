#!/bin/bash

set -ex

# Install dependencies
apt-get update
apt-get install -y --no-install-recommends inotify-tools coreutils rsync build-essential ocaml wget un>

# Download and install Unison
cd /tmp
wget -O unison-${UNISON_VERSION}.tar.gz https://github.com/bcpierce00/unison/archive/${UNISON_VERSION}>
tar -xzvf unison-${UNISON_VERSION}.tar.gz
rm unison-${UNISON_VERSION}.tar.gz
cd unison-${UNISON_VERSION}
make
cp ./src/unison /usr/local/bin
cp ./src/unison-fsmonitor /usr/local/bin
cd /tmp
rm -rf unison-${UNISON_VERSION}

# Configure directories
mkdir -p ${UNISON}
mkdir -p ${UNISON_LOG_DIR}

# Cleanup unnecessary packages
apt-get purge -y --auto-remove build-essential ocaml
apt-get clean
rm -rf /var/lib/apt/lists/*