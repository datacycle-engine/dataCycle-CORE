#!/bin/bash
MONGO_UUID=$1

set -e

function print_header_message {
    echo "###############################################################
################## $1"
}

ENV_FILE=$2
if [ -z "$ENV_FILE" ]; then ENV_FILE='.env'; fi

set -eu

function read_var() {
  VAR=$(grep -w "^$1" $2 | xargs)
  IFS="=" read -ra VAR <<< "$VAR"
  if [ -z ${VAR[1]+x} ]; then >&2 echo "env var $1 is not set!";  exit 1; fi
  echo ${VAR[1]}
}

REMOTE_DOCKER_HOST=$(read_var REMOTE_DOCKER_HOST $ENV_FILE)
REMOTE_DOCKER_ENV=$(read_var REMOTE_DOCKER_ENV $ENV_FILE)
REMOTE_COMPOSER_PROJECT_NAME=$(read_var REMOTE_COMPOSER_PROJECT_NAME $ENV_FILE)
LOCAL_COMPOSE_PROJECT_NAME=$(read_var COMPOSE_PROJECT_NAME $ENV_FILE)

# local mongodb name
LOCAL_MONGO=$(docker exec -it "$LOCAL_COMPOSE_PROJECT_NAME"_web_1 rake data_cycle_core:mongo:name[$MONGO_UUID] | tail -n 1)

# remote mongodb name
# REMOTE_MONGO=$(DOCKER_HOST="$REMOTE_DOCKER_HOST" docker exec -it "$REMOTE_COMPOSER_PROJECT_NAME"_web_1 rake data_cycle_core:mongo:name[$MONGO_UUID] | tail -n 1)
REMOTE_MONGO="data_cycle_production_$MONGO_UUID"


print_header_message "ENV vars loaded: $ENV_FILE";
echo "REMOTE_DOCKER_HOST          : $REMOTE_DOCKER_HOST"
echo "REMOTE_DOCKER_ENV           : $REMOTE_DOCKER_ENV"
echo "REMOTE_COMPOSER_PROJECT_NAME: $REMOTE_COMPOSER_PROJECT_NAME"
echo "LOCAL_COMPOSE_PROJECT_NAME  : $LOCAL_COMPOSE_PROJECT_NAME"
echo "MONGO_UUID                  : $MONGO_UUID"
echo "LOCAL_MONGO                 : $LOCAL_MONGO"
echo "REMOTE_MONGO                : $REMOTE_MONGO"

ERROR="Id is not a valid external System."
NOT_DEF="(See full trace by running task with --trace)"

if [ "$LOCAL_MONGO" == "$ERROR" ] || [ "$LOCAL_MONGO" == "$NOT_DEF" ]; then
  echo "Illegal local mongo db."
  exit 1
fi

if [ "$REMOTE_MONGO" == "$ERROR" ] || [ "$REMOTE_MONGO" == "$NOT_DEF" ]; then
  echo "Illegal remote mongo db."
  exit 1
fi

if [ ! -d ./db/backups/development/mongo/download ]; then
  echo "creating ./db/backups/development/mongo/download"
  mkdir -p ./db/backups/development/mongo/download;
fi


DOCKER_HOST="$REMOTE_DOCKER_HOST" docker exec -it "$REMOTE_COMPOSER_PROJECT_NAME"_mongodb_1 mongodump --db $REMOTE_MONGO --archive > /tmp/"$REMOTE_MONGO"_download.archive
DOCKER_HOST="$REMOTE_DOCKER_HOST" docker cp "$REMOTE_COMPOSER_PROJECT_NAME"_mongodb_1:tmp/"$REMOTE_MONGO"_download.archive ./db/backups/development/.

docker exec -it "$LOCAL_COMPOSE_PROJECT_NAME"_mongodb_1 mongorestore --archive=./db/backups/development/"$REMOTE_MONGO"_download.archive --drop --nsFrom="$REMOTE_MONGO".* --nsTo="$LOCAL_MONGO".*
