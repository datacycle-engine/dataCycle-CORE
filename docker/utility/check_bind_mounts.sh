#!/bin/bash
set -eu

## mongodb | app | postgres
echo "$BASE_DATA_VOLUME_PATH"
mkdir -p $BASE_DATA_VOLUME_PATH/{app,import,mongodb,postgres}
sudo chgrp -R 1000 $BASE_DATA_VOLUME_PATH/app
sudo chgrp -R 1000 $BASE_DATA_VOLUME_PATH/import

# nginx | app | mongodb
echo "$BASE_LOG_VOLUME_PATH"
mkdir -p $BASE_LOG_VOLUME_PATH/{app,mongodb,nginx}
sudo chgrp -R 1000 $BASE_LOG_VOLUME_PATH/app

## imgproxy_data_cycle | data_cycle
echo "$BASE_CACHE_VOLUME_PATH"
mkdir -p $BASE_CACHE_VOLUME_PATH/{data_cycle,imgproxy_data_cycle}

echo "$BASE_HISTORY_VOLUME_PATH"
mkdir -p $BASE_HISTORY_VOLUME_PATH
sudo chgrp -R 1000 $BASE_HISTORY_VOLUME_PATH

echo "$BASE_BACKUP_VOLUME_PATH"
mkdir -p $BASE_BACKUP_VOLUME_PATH
sudo chgrp -R 1000 $BASE_BACKUP_VOLUME_PATH

echo "### bind mount directories updated ###"
