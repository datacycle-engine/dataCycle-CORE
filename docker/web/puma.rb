#!/usr/bin/env puma
# frozen_string_literal: true

application_root = ENV['APPLICATION_ROOT']&.delete_suffix('/') || '/var/www/app'
directory "#{application_root}/"
rackup "#{application_root}/config.ru"
environment 'development'

tag ''

pidfile "#{application_root}/tmp/pids/puma.pid"
state_path "#{application_root}/tmp/pids/puma.state"
stdout_redirect '/dev/stdout', '/dev/stderr', true

threads 5, 5

bind "unix://#{application_root}/tmp/sockets/puma.sock"

workers 1

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
