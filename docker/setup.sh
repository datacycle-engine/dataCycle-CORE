#!/bin/bash
echo "$(ip route|awk '/default/ { print $3 }') dockerhost" >> /etc/hosts

mkdir -p /var/www/app/tmp/{sockets,pids}
chown -R 1000:1000 /var/www/app/tmp
rm -f tmp/pids/server.pid

gem install bundler
# bundle update
bundle install

RUBYOPT="-W:no-deprecated -W:no-experimental" rails s -b 0.0.0.0 -p 3000
