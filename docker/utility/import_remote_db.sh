#!/bin/bash
set -e

read_var() {
  VAR=$(grep -w $1 $2 | xargs)
  IFS="=" read -ra VAR <<< "$VAR"
  echo ${VAR[1]}
}

DOCKER_HOST=$(read_var REMOTE_DOCKER_HOST .env)
DOCKER_ENV=$(read_var REMOTE_DOCKER_ENV .env)
DOCKER_COMPOSE_PROJECT_NAME=$(read_var REMOTE_COMPOSER_PROJECT_NAME .env)

COMPOSE_PROJECT_NAME=$(read_var COMPOSE_PROJECT_NAME .env)

DOCKER_HOST="$DOCKER_HOST" docker exec -it "$DOCKER_COMPOSE_PROJECT_NAME"_web_1 rake data_cycle_core:db:dump[local_dev_db]
DOCKER_HOST="$DOCKER_HOST" docker cp "$DOCKER_COMPOSE_PROJECT_NAME"_web_1:/app/db/backups/"$DOCKER_ENV"/local_dev_db.dir ./db/backups/development/.

docker exec -it "$COMPOSE_PROJECT_NAME"_web_1 rake data_cycle_core:db:restore[local_dev_db]
