#!/usr/bin/env puma
# frozen_string_literal: true

directory '/var/www/app/test/dummy/'
rackup '/var/www/app/test/dummy/config.ru'
environment 'development'

tag ''

pidfile '/var/www/app/test/dummy/tmp/pids/puma.pid'
state_path '/var/www/app/test/dummy/tmp/pids/puma.state'
stdout_redirect '/dev/stdout', '/dev/stderr', true

threads 5, 5

bind 'unix:///var/www/app/test/dummy/tmp/sockets/puma.sock'

workers 3

preload_app!

before_fork do
  ActiveRecord::Base.connection_pool.disconnect!
  require 'puma_worker_killer'

  PumaWorkerKiller.config do |config|
    config.ram = 4096 # mb
    config.frequency = 3600 # seconds
    config.percent_usage = 0.9
    config.rolling_restart_frequency = false
  end

  PumaWorkerKiller.start
end

on_worker_boot do
  ActiveSupport.on_load(:active_record) do
    ActiveRecord::Base.establish_connection
  end
end
