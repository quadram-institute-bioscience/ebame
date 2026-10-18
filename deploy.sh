#!/bin/bash

# This script is executed on the virtual machine during the *Deployment* phase.
# It is used to apply parameters specific to the current deployment.
# It is executed secondly during a cloud deployement in IFB-Biosphere, after the *Installation* phase.

source /etc/os-release
LOCUSER=$ID # Set this variable according to the used distrib: ubuntu debian centos rocky
LOCUSER_HOME=`eval echo "~$LOCUSER"`

if [[ -r /etc/profile.d/ifb.sh ]]; then
  source /etc/profile.d/ifb.sh
else
  echo No readable profile 'ifb.sh'.
  return 1
fi

# Configure  default user
# IFB_DATADIR is set in profile ‘ifb.sh'
ln -s $IFB_DATADIR $LOCUSER_HOME/data

# Manage ephemeral disk
EPHEM_DIR=`df | grep vdb | awk '{print $6}'`
LOCALDATA_SUBDIR='mydatalocal'
if [ -n "$EPHEM_DIR" ]; then
  # Link local data dir to ephemeral disk subdir
  mkdir -p $EPHEM_DIR/$LOCALDATA_SUBDIR
  chown $LOCUSER:$LOCUSER $EPHEM_DIR/$LOCALDATA_SUBDIR
  ln -s $EPHEM_DIR/$LOCALDATA_SUBDIR $IFB_DATADIR/$LOCALDATA_SUBDIR

  # Move docker data dir to ephemeral disk
  if [[ ! -z "${APP_ENABLE_DOCKER}" ]]; then
    DOCKER_DJSON=/etc/docker/daemon.json
    export DOCKER_DATADIR=${EPHEM_DIR}/docker-data
    mkdir $DOCKER_DATADIR
    if [ -e $DOCKER_DJSON ]
    then
      curjson="$(jq '."data-root"=env.DOCKER_DATADIR' $DOCKER_DJSON)"
      echo "${curjson}" > $DOCKER_DJSON
    else
      echo -e "{\n  \"data-root\": \"$DOCKER_DATADIR\"\n}" > $DOCKER_DJSON
    fi
    systemctl restart docker
  fi

else
  mkdir $IFB_DATADIR/$LOCALDATA_SUBDIR
  chown $LOCUSER:$LOCUSER $IFB_DATADIR/$LOCALDATA_SUBDIR
fi

# Mount IFB remote shared volumes
APP_SHARED_VOLUMES=$(ss-get --timeout=5 ifb_share_endpoints)
if [ -n "$APP_SHARED_VOLUMES" ]; then
  python3 configure-remote-fs.py --dst=$IFB_DATADIR $APP_SHARED_VOLUMES
  ansible-playbook -c local -i 127.0.0.1, -b -e 'ansible_python_interpreter=/usr/bin/python3' ansible-remotefs.yaml
  systemctl daemon-reload
  systemctl restart remote-fs.target

  # Change owner of remote volumes to default user
  for curdir in $( ls $IFB_DATADIR ); do
    # ls -l $IFB_DATADIR/$curdir
    chown $LOCUSER:$LOCUSER $IFB_DATADIR/$curdir
  done
fi

# Fix Docker MTU bug with local openstack subnets using VXLAN
# Docker set by default a MTU of 1500 which may be larger than the VXLAN one.
# --clamp-mss-to-pmtu tells iptable to discover the maximum MTU
# https://superuser.com/questions/1778644/how-iptables-clamp-mss-to-pmtu-calculates-pmtu
CLOUD_NAME=$( curl http://169.254.169.254/2009-04-04/user-data | grep SLIPSTREAM_CONNECTOR_INSTANCE  | awk -F '=' {' print $2 '} )
if [ ! -z "${CLOUD_NAME}" ] && ! [[ $CLOUD_NAME =~ 'core-cloudbis' || $CLOUD_NAME =~ 'bird-stack' ]]
then
  echo "Discovering the largest MTU..."
  iptables -t mangle -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
fi

# EBAME user-level setup
source ebame-setup.sh
