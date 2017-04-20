# rails essentials
require 'rails'
require 'sass-rails'
require 'turbolinks'
require 'jquery-rails'

# Databases
require 'pg'
require 'activerecord-postgis-adapter'
require 'acts_as_tree'
require 'rgeo'
require 'mongoid'

# authentication
require 'devise'

# authorization
require 'cancancan'

# foundation helper
require 'foundation-rails'
require 'foundation_rails_helper'
require 'devise-foundation-views'

# google material icons wrapper
require 'material_icons'
# pagination
require 'kaminari'
# print formatting for e.g. hashes
require 'awesome_print'
# validator for json data
require 'json-schema'
# backgound-jobs
require 'delayed_job'
require 'delayed_job_active_record'

# REST-client
require 'faraday'
# simple logger
require 'logging'

# i18n for db
require 'globalize'

module DataCycleCore
  class Engine < ::Rails::Engine
    isolate_namespace DataCycleCore

    config.assets.precompile += ['data_cycle_core/*']

    # use active_record as orm (!not mongoid)
    config.app_generators.orm = :active_record
    config.active_record.schema_format = :sql

    # backend for active_job is delayed_job
    config.active_job.queue_adapter = :delayed_job

    # set default language and no errors for non standard languages
    config.i18n.enforce_available_locales = false
    config.i18n.default_locale = :de
    # fallbacks for i18n and Globalize
    config.i18n.fallbacks = true


    # append engine migration path -> no installation of migrations required
    initializer :append_migrations do |app|
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    # include rake_tasks
    rake_tasks do
      Dir[File.join(File.dirname(__FILE__),'tasks/*.rake')].each { |f| load f }
    end

    config.to_prepare do      
      Dir.glob(Rails.root + "app/decorators/**/*_decorator*.rb").each do |c|
        require_dependency(c)
      end
    end
  end
end
