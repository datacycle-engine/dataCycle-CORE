# frozen_string_literal: true

require 'date'

$LOAD_PATH.push File.expand_path('lib', __dir__)

version = File.read(File.expand_path('./GEM_VERSION', __dir__)).strip

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'data_cycle_core'
  s.version     = version
  s.authors     = ['Manuel Mitterer', 'Martin Oehzelt', 'Benjamin Preisig', 'Patrick Rainer', 'Johannes Zlattinger']
  s.email       = ['office@datacycle.at']
  s.homepage    = 'https://datacycle.info'
  s.summary     = 'dataCycle CORE - management system for linked data'
  s.license     = 'AGPLv3'

  s.files = Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']

  s.required_ruby_version = '~> 3.2.2'

  # rails
  s.add_dependency 'rails', '~> 6.1'
  s.add_dependency 'rake'
  # Translations
  s.add_dependency 'mobility'
  # Frontend Asset Handling
  s.add_dependency 'vite_rails', '>= 3.0.12'
  # database
  s.add_dependency 'activerecord-postgis-adapter'
  s.add_dependency 'acts_as_tree'
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
  s.add_dependency 'dry-transformer', '>= 1.0'
  s.add_dependency 'dry-validation'
  s.add_dependency 'hashdiff', '>= 0.4.0'
  s.add_dependency 'transproc', '~> 1.0'

  # gems for event-schedules
  s.add_dependency 'ice_cube'

  s.add_dependency 'mini_mime'

  # File Upload
  s.add_dependency 'mini_magick'
  s.add_dependency 'pdf-reader'
  s.add_dependency 'streamio-ffmpeg'
  s.add_dependency 'taglib-ruby'

  s.add_dependency 'rails-html-sanitizer', '>= 1.0.4'
  # rufus scheduler
  s.add_dependency 'rufus-scheduler'
  # redis
  s.add_dependency 'hiredis'
  s.add_dependency 'redis', '< 5'

  # redcarpet (for rendering markdown)
  s.add_dependency 'redcarpet'

  # phash
  s.add_dependency 'pHash'

  # progress bar
  s.add_dependency 'ruby-progressbar'

  # URI (https://tools.ietf.org/html/rfc3986) and IRI (https://tools.ietf.org/html/rfc3987) Parser
  s.add_dependency 'addressable'

  s.add_dependency 'puma', '< 6'
  s.add_dependency 'puma-status'
  s.add_dependency 'puma_worker_killer'

  # premailer
  s.add_dependency 'premailer'

  # Better distance_of_time_in_words (https://github.com/radar/distance_of_time_in_words)
  s.add_dependency 'dotiw'

  s.add_dependency 'holidays'

  s.add_dependency 'mini_exiftool_vendored'

  s.add_dependency 'image_processing', '>= 1.2'

  s.add_dependency 'zip_tricks'

  # read CSV and XLSX Files
  s.add_dependency 'roo'

  # render PDFs
  s.add_dependency 'pdfkit'
  s.add_dependency 'wkhtmltopdf-binary'

  # ruby 3.2
  s.add_dependency 'net-ftp'
  s.add_dependency 'net-imap'
  s.add_dependency 'net-pop'
  s.add_dependency 'net-smtp'
end
