#!/bin/bash

# This script can be used to apply the complete configuration of this Biosphere app
# to a virtual machine

source /etc/os-release
LOCUSER=$ID # Set this variable according to the used distrib: ubuntu debian centos rocky

APP_NAME="ebame-viromics"
APP_REPO="https://github.com/quadram-institute-bioscience/ebame-ubuntu-viromics.git"
APP_DIR="/ifb/apprepo/$APP_NAME"
APP_ENABLE_DOCKER=True
# APP_ENABLE_REMOTEDESKTOP=True

# git not installed by default in some linux distributions
if [[ $LOCUSER = "debian" ]]; then
    apt-get update --allow-releaseinfo-change
    apt-get install -y git
elif [[ $LOCUSER = "rocky" || $LOCUSER = "centos" ]]; then
    yum install -y git
fi

git -c http.sslVerify=false clone ${APP_REPO} ${APP_DIR}
# git -c http.sslVerify=false clone --branch devel ${APP_REPO} ${APP_DIR}
cd ${APP_DIR}
source install.sh
source deploy.sh