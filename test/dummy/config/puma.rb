# frozen_string_literal: true

port ENV['PORT'] || 3000
environment ENV['RAILS_ENV'] || 'development'

threads 1, ENV["PUMA_MAX_THREADS"]&.to_i || 5

preload_app!

plugin :tmp_restart

on_worker_boot do
  ActiveSupport.on_load(:active_record) do
    ActiveRecord::Base.establish_connection
  end
end

before_fork do
  ActiveRecord::Base.connection_pool.disconnect!
  require 'puma_worker_killer'

  PumaWorkerKiller.config do |config|
    config.ram = ENV["PUMA_MAX_MEMORY"]&.to_i || 4096 # mb
    config.frequency = 3600 # seconds
    config.percent_usage = 0.9
    config.rolling_restart_frequency = false
  end

  PumaWorkerKiller.start
end
