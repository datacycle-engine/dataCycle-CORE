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

  s.required_ruby_version = '~> 2.7.1'

  # rails
  s.add_dependency 'rails', '~> 6.1'
  s.add_dependency 'rake'
  # Frontend Asset Handling
  # s.add_dependency 'sprockets', '4.0.0'
  s.add_dependency 'vite_rails', '~> 2.0' # 3.0 has a bug, trying to find entrypoints/application.js
  # database
  s.add_dependency 'activerecord-postgis-adapter'
  s.add_dependency 'acts_as_tree'
  # s.add_dependency 'pg', '~> 0.21'
  s.add_dependency 'pg'
  s.add_dependency 'rgeo'
  s.add_dependency 'rgeo-geojson'
  s.add_dependency 'rgeo-proj4'
  s.add_dependency 'rgeo-shapefile'
  # mongoDB driver
  s.add_dependency 'mongoid', '~> 7.0.6'
  # REST Client
  s.add_dependency 'faraday'
  s.add_dependency 'faraday_middleware'
  # JSON Parser
  s.add_dependency 'multi_json'
  # XML Parser
  s.add_dependency 'nokogiri'
  # authentication
  s.add_dependency 'devise'
  s.add_dependency 'jwt'
  # authorization
  s.add_dependency 'cancancan', '>= 3.3.0'
  # pagination
  s.add_dependency 'kaminari'
  # print formatting for e.g. hashes
  s.add_dependency 'amazing_print'
  # validator for json data
  s.add_dependency 'json-schema'
  # background-jobs
  s.add_dependency 'delayed_job_active_record'
  # deamon for delayed_job
  s.add_dependency 'daemons'
  # simple forms
  s.add_dependency 'simple_form'
  # Breadcrumbs
  s.add_dependency 'gretel'

  s.add_dependency 'jbuilder'

  s.add_dependency 'acts_as_paranoid'
  s.add_dependency 'dry-transformer'
  s.add_dependency 'dry-validation'
  s.add_dependency 'hashdiff', '>= 0.4.0'
  s.add_dependency 'transproc', '~> 1.0'

  # gems for event-schedules
  s.add_dependency 'ice_cube'

  s.add_dependency 'mini_mime'

  # File Upload
  s.add_dependency 'carrierwave', '~> 0.5'
  s.add_dependency 'carrierwave_backgrounder', '~> 0.4.2'
  s.add_dependency 'mini_magick'
  s.add_dependency 'pdf-reader'
  s.add_dependency 'streamio-ffmpeg'
  s.add_dependency 'taglib-ruby'

  # Image Optimization
  s.add_dependency 'image_optim'
  s.add_dependency 'image_optim_pack'

  s.add_dependency 'rails-html-sanitizer', '>= 1.0.4'
  # cron jobs gem
  s.add_dependency 'whenever'
  # rufus scheduler
  s.add_dependency 'rufus-scheduler'
  # redis
  s.add_dependency 'hiredis'
  s.add_dependency 'redis'

  # redcarpet (for rendering markdown)
  s.add_dependency 'redcarpet'

  # phash
  s.add_dependency 'pHash'

  # progress bar
  s.add_dependency 'ruby-progressbar'

  # URI (https://tools.ietf.org/html/rfc3986) and IRI (https://tools.ietf.org/html/rfc3987) Parser
  s.add_dependency 'addressable'

  s.add_dependency 'puma'
  s.add_dependency 'puma-status'
  s.add_dependency 'puma_worker_killer'

  # Google Cloud Services
  s.add_dependency 'google-cloud-translate'
  s.add_dependency 'google-cloud-vision'

  # premailer
  s.add_dependency 'premailer'

  # support for ED25519 SSH Keys
  s.add_dependency 'bcrypt_pbkdf'
  s.add_dependency 'ed25519'

  # Better distance_of_time_in_words (https://github.com/radar/distance_of_time_in_words)
  s.add_dependency 'dotiw'

  s.add_dependency 'holidays'

  s.add_dependency 'mini_exiftool_vendored'
end
