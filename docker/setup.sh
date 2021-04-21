#!/bin/bash
echo "$(ip route|awk '/default/ { print $3 }') dockerhost" >> /etc/hosts

mkdir -p /var/www/app/tmp/{sockets,pids}
chown -R 1000:1000 /var/www/app/tmp
rm -f tmp/pids/server.pid

gem install bundler
# bundle update
bundle install
(yarn; yarn upgrade data-cycle-core) &> log/yarn.log &

# RAILS_LOG_TO_STDOUT=true RUBYOPT="-W:no-deprecated -W:no-experimental" bundle exec rails s -b 0.0.0.0 -p 3000
RAILS_LOG_TO_STDOUT=true RUBYOPT="-W:no-deprecated -W:no-experimental" bundle exec puma -C /var/www/app/vendor/gems/data-cycle-core/docker/web/puma.rb
