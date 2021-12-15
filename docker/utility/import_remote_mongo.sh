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
  VAR=$(grep -w "^$1" "$2" | xargs)
  IFS="=" read -ra VAR <<< "$VAR"
  if [ -z "${VAR[1]+x}" ]; then >&2 echo "env var $1 is not set!";  exit 1; fi
  echo "${VAR[1]}"
}

REMOTE_DOCKER_HOST=$(read_var REMOTE_DOCKER_HOST $ENV_FILE)
REMOTE_DOCKER_ENV=$(read_var REMOTE_DOCKER_ENV $ENV_FILE)
REMOTE_COMPOSER_PROJECT_NAME=$(read_var REMOTE_COMPOSER_PROJECT_NAME $ENV_FILE)
LOCAL_COMPOSE_PROJECT_NAME=$(read_var COMPOSE_PROJECT_NAME $ENV_FILE)
LOCAL_MONGO=$(docker exec -it "$LOCAL_COMPOSE_PROJECT_NAME"_web_1 rake data_cycle_core:mongo:name["$MONGO_UUID"] | tail -n 1 | tr -d '[:cntrl:]')
REMOTE_MONGO=$(DOCKER_HOST="$REMOTE_DOCKER_HOST" docker exec -it "$REMOTE_COMPOSER_PROJECT_NAME"_web_1 rake data_cycle_core:mongo:name["$MONGO_UUID"] | tail -n 1 | tr -d '[:cntrl:]')

print_header_message "ENV vars loaded: $ENV_FILE";
echo "REMOTE_DOCKER_HOST          : $REMOTE_DOCKER_HOST"
echo "REMOTE_DOCKER_ENV           : $REMOTE_DOCKER_ENV"
echo "REMOTE_COMPOSER_PROJECT_NAME: $REMOTE_COMPOSER_PROJECT_NAME"
echo "LOCAL_COMPOSE_PROJECT_NAME  : $LOCAL_COMPOSE_PROJECT_NAME"
echo "################## MONGO VARS"
echo "MONGO_UUID                  : $MONGO_UUID"
echo "LOCAL_MONGO                 : $LOCAL_MONGO"
echo "REMOTE_MONGO                : $REMOTE_MONGO"
echo ""

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

echo "dump mongodb ..."
DOCKER_HOST="$REMOTE_DOCKER_HOST" docker exec -it "$REMOTE_COMPOSER_PROJECT_NAME"_mongodb_1 mongodump --db "$REMOTE_MONGO" --archive=/tmp/"$REMOTE_MONGO"_download.archive

echo "downloading ... "
echo "$REMOTE_DOCKER_HOST docker cp ${REMOTE_COMPOSER_PROJECT_NAME}_mongodb_1:/tmp/${REMOTE_MONGO}_download.archive ./db/backups/development/."
DOCKER_HOST="$REMOTE_DOCKER_HOST" docker cp "$REMOTE_COMPOSER_PROJECT_NAME"_mongodb_1:/tmp/"$REMOTE_MONGO"_download.archive ./db/backups/development/.

echo "restoring mongodb local ... "
docker cp ./db/backups/development/"$REMOTE_MONGO"_download.archive "$LOCAL_COMPOSE_PROJECT_NAME"_mongodb_1:/tmp/"$REMOTE_MONGO"_download.archive
docker exec -it "$LOCAL_COMPOSE_PROJECT_NAME"_mongodb_1 mongorestore --archive=/tmp/"$REMOTE_MONGO"_download.archive --drop --nsFrom="$REMOTE_MONGO".* --nsTo="$LOCAL_MONGO".*
