# frozen_string_literal: true

source 'https://rubygems.org'

ruby '~> 2.7.1'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

# Declare your gem's dependencies in data_cycle_core.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

gem 'translations', path: 'vendor/gems/translations'

gem 'appsignal'

# Excel Generator
gem 'caxlsx'
gem 'caxlsx_rails'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

gem 'dotenv-rails'

gem 'jb'

group :test do
  gem 'minitest-hooks'
end

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'web-console'
  gem 'brakeman', '>= 4.5.1', require: false
  gem 'bundler-audit', require: false
  gem 'faker'
  gem 'fasterer', require: false
  gem 'rubocop', '~> 0.84.0', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false

  # only activate if required for local testing
  # gem 'bullet'
  # # rails panel (test)
  # gem 'meta_request'
end

group :development, :test, :review do
  gem 'listen'
  gem 'spring'
  gem 'spring-watcher-listen'

  gem 'pry'
  gem 'pry-byebug'
  gem 'rb-readline'

  gem 'capistrano-rails'
  gem 'capistrano-rvm'
  gem 'capistrano3-delayed-job'
  gem 'capistrano3-puma'

  gem 'simplecov', require: false

  # activate for performance profiling
  # performance profiling
  # gem 'rack-mini-profiler'
  # For memory profiling
  # gem 'memory_profiler'
  # For call-stack profiling flamegraphs
  # gem 'flamegraph'
  # gem 'stackprof'
  #
  # for API benchmark testing
  # gem 'rails_api_benchmark'
  # gem 'pronto', '~> 0.9.5'
  # gem 'pronto-rubocop', '~> 0.9.1', require: false
end
