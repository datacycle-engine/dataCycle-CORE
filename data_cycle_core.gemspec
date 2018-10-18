# frozen_string_literal: true

require 'date'

$LOAD_PATH.push File.expand_path('lib', __dir__)

# allows bundler to use the gemspec for dependencies
# lib = File.expand_path('../lib', __FILE__)
# $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

# Maintain your gem's version:
require 'data_cycle_core/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'data_cycle_core'
  s.version     = DataCycleCore::VERSION
  s.authors     = ['Michael Dermastia', 'Manuel Mitterer', 'Martin Oehzelt', 'Patrick Rainer', 'Johannes Zlattinger']
  s.email       = ['office@datacycle.at']
  s.homepage    = 'http://git.pixelpoint.biz/data-cycle/data-cycle-core'
  s.summary     = 'dataCycle-Core. Rails engine for dataCycle'
  s.license     = "Copyright 2016-#{Time.now.year} datacycle.at. All rights reserved."

  s.files = Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']

  s.required_ruby_version = '~> 2.5.1'

  # rails
  # s.add_dependency 'jquery-rails'
  s.add_dependency 'rails', '~> 5.1.6'
  s.add_dependency 'rake'
  # database
  s.add_dependency 'activerecord-postgis-adapter'
  s.add_dependency 'acts_as_tree'
  s.add_dependency 'pg', '~> 0.21'
  s.add_dependency 'rgeo'
  s.add_dependency 'rgeo-geojson'
  # mongoDB driver
  s.add_dependency 'mongoid'
  # change mongoid version if bullet gem is used
  # s.add_dependency 'mongoid', '>= 4.0.0', '< 7.0.0'
  # s.add_dependency 'arel-helpers'
  # REST Client
  s.add_dependency 'faraday'
  s.add_dependency 'faraday_middleware'
  # JSON Parser
  s.add_dependency 'multi_json'
  # SOAP Client
  # s.add_dependency 'savon', '~> 2.0'
  # XML Parser
  s.add_dependency 'nokogiri', '~> 1.8.5'
  # s.add_dependency 'activemodel-serializers-xml'
  # authentication
  s.add_dependency 'devise'
  # authorization
  s.add_dependency 'cancancan'
  # pagination
  s.add_dependency 'kaminari'
  # print formatting for e.g. hashes
  s.add_dependency 'awesome_print'
  # validator for json data
  s.add_dependency 'json-schema'
  # simple logger for import/load
  s.add_dependency 'logging'
  # background-jobs
  s.add_dependency 'delayed_job'
  s.add_dependency 'delayed_job_active_record'
  # deamon for delayed_job
  s.add_dependency 'daemons'
  # simple forms
  s.add_dependency 'simple_form'
  # Breadcrumbs
  s.add_dependency 'gretel'

  s.add_dependency 'jbuilder'

  s.add_dependency 'acts_as_paranoid', '~> 0.6.0'
  s.add_dependency 'dry-validation', '~> 0.11'
  s.add_dependency 'hashdiff'
  s.add_dependency 'transproc', '~> 1.0'

  # File Upload
  s.add_dependency 'carrierwave', '~> 0.5'
  s.add_dependency 'carrierwave_backgrounder', '~> 0.4.2'
  s.add_dependency 'mini_magick'
  s.add_dependency 'pdf-reader'
  s.add_dependency 'streamio-ffmpeg'
  s.add_dependency 'taglib-ruby'

  s.add_dependency 'globalize', '~> 5.1.0'
  s.add_dependency 'loofah', '~> 2.2.2'
  s.add_dependency 'rails-html-sanitizer', '>= 1.0.4'
  # cron jobs gem
  s.add_dependency 'whenever'
  # redis
  s.add_dependency 'redis-rails'

  # redcarpet (for rendering markdown)
  s.add_dependency 'redcarpet'

  # phash
  s.add_dependency 'pHash'

  # development gems
  s.add_development_dependency 'better_errors'
  s.add_development_dependency 'binding_of_caller'
  # s.add_development_dependency 'listen'
  # s.add_development_dependency 'spring'
  s.add_development_dependency 'spring-watcher-listen'
  s.add_development_dependency 'web-console'

  s.add_dependency 'dotenv-rails'
  s.add_dependency 'puma', '~> 3.11.0'
  s.add_dependency 'puma_worker_killer'

  # validation gems
  s.add_development_dependency 'brakeman', '4.3.0'
  s.add_development_dependency 'bundler-audit'
  s.add_development_dependency 'gemsurance'
  s.add_development_dependency 'rubocop', '~> 0.56.0'
  # s.add_development_dependency 'capybara'
  # s.add_development_dependency 'selenium-webdriver'
  # s.add_development_dependency 'chromedriver-helper'

  # only activate if required for local testing
  # s.add_development_dependency 'bullet'
  # # rails panel (test)
  # s.add_development_dependency 'meta_request'
end
