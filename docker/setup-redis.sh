#!/bin/sh

mkdir -p /etc/redis
envsubst < /tmp/redis/redis.conf > /etc/redis/redis.conf

redis-server /etc/redis/redis.conf