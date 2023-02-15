#!/bin/bash
DUMP_FORMAT=$1

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

if [ -z "$DUMP_FORMAT" ]; then DUMP_FORMAT=review
fi
REMOTE_DOCKER_HOST=$(read_var REMOTE_DOCKER_HOST $ENV_FILE)
REMOTE_DOCKER_ENV=$(read_var REMOTE_DOCKER_ENV $ENV_FILE)
REMOTE_COMPOSER_PROJECT_NAME=$(read_var REMOTE_COMPOSER_PROJECT_NAME $ENV_FILE)
LOCAL_COMPOSE_PROJECT_NAME=$(read_var COMPOSE_PROJECT_NAME $ENV_FILE)
if [ "$(docker ps -q -f name=^${LOCAL_COMPOSE_PROJECT_NAME}_web_1$)" ]; then LOCAL_WEB_CONTAINER="${LOCAL_COMPOSE_PROJECT_NAME}_web_1";
elif [ "$(docker ps -q -f name=^${LOCAL_COMPOSE_PROJECT_NAME}-web-1$)" ]; then LOCAL_WEB_CONTAINER="${LOCAL_COMPOSE_PROJECT_NAME}-web-1";
else echo "LOCAL_WEB_CONTAINER NOT RUNNING OR NOT FOUND!" && exit 1
fi

print_header_message "ENV vars loaded: $ENV_FILE";
echo "REMOTE_DOCKER_HOST: $REMOTE_DOCKER_HOST"
echo "REMOTE_DOCKER_ENV: $REMOTE_DOCKER_ENV"
echo "REMOTE_COMPOSER_PROJECT_NAME: $REMOTE_COMPOSER_PROJECT_NAME"
echo "LOCAL_COMPOSE_PROJECT_NAME: $LOCAL_COMPOSE_PROJECT_NAME"
echo "LOCAL_WEB_CONTAINER: $LOCAL_WEB_CONTAINER"
echo "DUMP_FORMAT: $DUMP_FORMAT"

if [ ! -d ./db/backups/development ]; then
  echo "creating ./db/backups/development"
  mkdir -p ./db/backups/development;
fi

echo "REMOTE: rake data_cycle_core:db:dump[local_dev_db]"
DOCKER_HOST="$REMOTE_DOCKER_HOST" docker exec -it "$REMOTE_COMPOSER_PROJECT_NAME"_web_1 rake data_cycle_core:db:dump[local_dev_db,dir,"$DUMP_FORMAT"]

echo "REMOTE --> LOCAL cp local_dev_db"
DOCKER_HOST="$REMOTE_DOCKER_HOST" docker cp "$REMOTE_COMPOSER_PROJECT_NAME"_web_1:/app/db/backups/"$REMOTE_DOCKER_ENV"/local_dev_db.dir ./db/backups/development/.

echo "LOCAL: rake data_cycle_core:db:restore[local_dev_db]"
docker exec -it "$LOCAL_WEB_CONTAINER" rake data_cycle_core:db:restore[local_dev_db]
