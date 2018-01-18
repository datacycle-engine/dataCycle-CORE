$LOAD_PATH.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "data_cycle_core/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "data_cycle_core"
  s.version     = DataCycleCore::VERSION
  s.authors     = ["Martin Oehzelt"]
  s.email       = ["oehzelt@pixelpoint.at"]
  s.homepage    = "http://git.pixelpoint.biz/data-cycle/data-cycle-core"
  s.summary     = "DataCycleCore. Rails Engine for the DataCycle project"
  s.description = "DataCycleCore. "
  s.license     = "Copyright 2017 pixelpoint.at. All rights reserved."

  s.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.md"]

  # rails
  s.add_dependency 'jquery-rails'
  s.add_dependency 'rails', '~> 5.0.0', '>= 5.0.0.1'
  s.add_dependency 'rake', '~> 12.1.0'
  s.add_dependency 'sass-rails', '~> 5.0'
  # Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
  s.add_dependency 'turbolinks', '~> 5'
  # database
  s.add_dependency 'activerecord-postgis-adapter'
  s.add_dependency 'acts_as_tree'
  s.add_dependency 'pg'
  s.add_dependency 'rgeo'
  # mongoDB driver
  s.add_dependency 'mongoid'
  # s.add_dependency 'arel-helpers'
  # REST Client
  s.add_dependency 'faraday'
  # JSON Parser
  s.add_dependency 'multi_json'
  # SOAP Client
  # s.add_dependency 'savon', '~> 2.0'
  # XML Parser
  s.add_dependency 'nokogiri', '~> 1.8.1'
  # s.add_dependency 'activemodel-serializers-xml'
  # authentication
  s.add_dependency 'devise'
  # authorization
  s.add_dependency 'cancancan'
  # foundation helper
  s.add_dependency 'devise-foundation-views'
  s.add_dependency 'foundation-rails', '~> 6.2.4' # 23.2.17 -> bug in  6.3.0 (prevents precompile the SCSS asset)
  s.add_dependency 'foundation_rails_helper', '>= 3.0.0.rc2', '< 4.0'
  # google material icons wrapper
  s.add_dependency 'material_icons'
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

  s.add_dependency 'acts_as_paranoid', '~> 0.5.0'
  s.add_dependency 'dry-validation', '~> 0.11'
  s.add_dependency 'hashdiff'
  s.add_dependency 'transproc', '~> 1.0'

  # File Upload
  s.add_dependency 'carrierwave', '~> 0.5'
  s.add_dependency 'carrierwave_backgrounder', '~> 0.4.2'
  s.add_dependency 'mini_magick'

  # development tools
  s.add_development_dependency 'better_errors'
  s.add_development_dependency 'binding_of_caller'
  s.add_development_dependency 'listen', '~> 3.0.5'
  s.add_development_dependency 'rubocop', '~> 0.52.1'
  s.add_development_dependency 'spring'
  s.add_development_dependency 'spring-watcher-listen', '~> 2.0.0'
  s.add_development_dependency 'web-console'
  # admin db-interface

  # test dependencies
  s.add_dependency 'rspec'
  s.add_dependency 'rspec-rails'
end
