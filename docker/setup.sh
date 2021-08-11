#!/bin/bash
echo "$(hostname -i|sed -r 's/([0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.)[0-9]{1,3}/\11/') dockerhost" >> /etc/hosts

(yarn; yarn upgrade) &> log/yarn.log &

mkdir -p /var/www/app/tmp/{sockets,pids}
rm -f tmp/pids/server.pid

gem install bundler
# bundle update
bundle install

# update project dictionaries if existing in main projects config/configurations/ts_search/
bundle exec rake dc:update:dictionaries &

# RAILS_LOG_TO_STDOUT=true RUBYOPT="-W:no-deprecated -W:no-experimental" bundle exec rails s -b 0.0.0.0 -p 3000
RAILS_LOG_TO_STDOUT=true RUBYOPT="-W:no-deprecated -W:no-experimental" bundle exec puma -C /var/www/app/vendor/gems/data-cycle-core/docker/web/puma.rb
