#!/bin/bash
echo "$(ip route|awk '/default/ { print $3 }') dockerhost" >> /etc/hosts
cd test/dummy
mkdir -p /var/www/app/test/dummy/tmp/{sockets,pids}
chown -R 1000:1000 /var/www/app/test/dummy/tmp
rm -f tmp/pids/server.pid

gem install bundler
# bundle update
bundle install

# RUBYOPT="--jit-verbose=1" rails s -b 0.0.0.0 -p 3000
#rails s -b 0.0.0.0 -p 3000
#export RUBYOPT="-W:no-deprecated -W:no-experimental"
#RUBYOPT="-W:no-deprecated -W:no-experimental" rails s -b 0.0.0.0 -p 3000
RAILS_LOG_TO_STDOUT=true RUBYOPT="-W:no-deprecated -W:no-experimental" bundle exec puma -C /var/www/app/docker/web/puma.rb