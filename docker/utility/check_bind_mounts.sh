#!/bin/bash
set -eu

## mongodb | app | postgres
echo "$BASE_DATA_VOLUME_PATH"
mkdir -p $BASE_DATA_VOLUME_PATH/{app,mongodb,postgres}

# nginx | app | mongodb
echo "$BASE_LOG_VOLUME_PATH"
mkdir -p $BASE_LOG_VOLUME_PATH/{app,mongodb,nginx}

## imgproxy_data_cycle | data_cycle
echo "$BASE_CACHE_VOLUME_PATH"
mkdir -p $BASE_CACHE_VOLUME_PATH/{data_cycle,imgproxy_data_cycle}

echo "$BASE_HISTORY_VOLUME_PATH"
mkdir -p $BASE_HISTORY_VOLUME_PATH

echo "$BASE_BACKUP_VOLUME_PATH"
mkdir -p $BASE_BACKUP_VOLUME_PATH

echo "### bind mount directories updated ###"
