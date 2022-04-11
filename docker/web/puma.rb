#!/usr/bin/env puma
# frozen_string_literal: true

application_root = ENV['APPLICATION_ROOT']&.delete_suffix('/') || '/app'
directory "#{application_root}/"
rackup "#{application_root}/config.ru"
environment ENV.fetch('RAILS_ENV') { 'development' }

tag ''

pidfile "#{application_root}/tmp/pids/puma.pid"
state_path "#{application_root}/tmp/pids/puma.state"

if ENV.fetch('RAILS_ENV') { 'development' } == 'development'
  stdout_redirect '/dev/stdout', '/dev/stderr', true
else
  stdout_redirect "#{application_root}/log/puma_access.log", "#{application_root}/log/puma_error.log", true
end

threads 1, ENV.fetch('PUMA_MAX_THREADS') { 5 }.to_i

bind "unix://#{application_root}/tmp/sockets/puma.sock"

if ENV.fetch('WEB_CONCURRENCY') { nil }.nil?
  workers ENV.fetch('PUMA_MAX_WORKERS') { 3 }.to_i
end

preload_app!

before_fork do
  ActiveRecord::Base.connection_pool.disconnect!
  require 'puma_worker_killer'

  PumaWorkerKiller.config do |config|
    config.ram = ENV.fetch('PUMA_MAX_MEMORY') { 4096 }.to_i # mb
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
