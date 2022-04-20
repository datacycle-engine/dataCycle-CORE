#!/bin/bash
set -eu

## mongodb | postgres
echo "$BASE_DATA_VOLUME_PATH"
mkdir -p $BASE_DATA_VOLUME_PATH/{mongodb,postgres}

## app
echo "$BASE_DC_PUBLIC_UPLOADS_VOLUME_PATH"
mkdir -p $BASE_DC_PUBLIC_UPLOADS_VOLUME_PATH/app
sudo chgrp -R 1000 $BASE_DC_PUBLIC_UPLOADS_VOLUME_PATH/app
sudo chmod -R g+w $BASE_DC_PUBLIC_UPLOADS_VOLUME_PATH/app

## import
echo "$BASE_DC_IMPORT_VOLUME_PATH"
mkdir -p $BASE_DC_IMPORT_VOLUME_PATH/import
sudo chgrp -R 1000 $BASE_DC_IMPORT_VOLUME_PATH/import
sudo chmod -R g+w $BASE_DC_IMPORT_VOLUME_PATH/import

# nginx | app | mongodb
echo "$BASE_LOG_VOLUME_PATH"
mkdir -p $BASE_LOG_VOLUME_PATH/app
sudo chgrp -R 1000 $BASE_LOG_VOLUME_PATH/app
sudo chmod -R g+w $BASE_LOG_VOLUME_PATH/app

## imgproxy_data_cycle | data_cycle
echo "$BASE_CACHE_VOLUME_PATH"
mkdir -p $BASE_CACHE_VOLUME_PATH/{data_cycle,imgproxy_data_cycle}

echo "$BASE_HISTORY_VOLUME_PATH"
mkdir -p $BASE_HISTORY_VOLUME_PATH
sudo chgrp -R 1000 $BASE_HISTORY_VOLUME_PATH
sudo chmod -R g+w $BASE_HISTORY_VOLUME_PATH

echo "$BASE_BACKUP_VOLUME_PATH"
mkdir -p $BASE_BACKUP_VOLUME_PATH
sudo chgrp -R 1000 $BASE_BACKUP_VOLUME_PATH
sudo chmod -R g+w $BASE_BACKUP_VOLUME_PATH

echo "### bind mount directories updated ###"
