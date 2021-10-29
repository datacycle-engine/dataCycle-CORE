#!/bin/bash
# ssh helper for gitlab-ci
set -eu

if [ -z "$1" ]
  then
    echo "missing argument 1: path to env file"
    exit 1
fi

if [ -z "$2" ]
  then
    echo "missing argument 2: path to bash script"
    exit 1
fi

PATH_TO_ENV_FILE=$1
PATH_TO_SCRIPT=$2

# load env variables from file
set -a
source <(cat $PATH_TO_ENV_FILE | sed -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/='\1'/g")
set +a


# execute bash script on remote server
ssh $DEPLOY_USER@$DEPLOY_TARGET \
  BASE_DATA_VOLUME_PATH=$BASE_DATA_VOLUME_PATH \
  BASE_LOG_VOLUME_PATH=$BASE_LOG_VOLUME_PATH \
  BASE_CACHE_VOLUME_PATH=$BASE_CACHE_VOLUME_PATH \
  BASE_HISTORY_VOLUME_PATH=$BASE_HISTORY_VOLUME_PATH \
  BASE_BACKUP_VOLUME_PATH=$BASE_BACKUP_VOLUME_PATH \
  'bash -s' < $PATH_TO_SCRIPT
