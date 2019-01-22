# frozen_string_literal: true

source 'https://rubygems.org'

ruby '~> 2.5.1'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

# Declare your gem's dependencies in data_cycle_core.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# NOTE: Axlsx has been pending release for a long time. You must specify the master on github to support Rubyzip 1.2.1.
gem 'rubyzip', '>= 1.2.1'
gem 'axlsx', git: 'https://github.com/randym/axlsx.git', ref: 'c8ac844'
gem 'axlsx_rails'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

gem 'dotenv-rails'

gem 'jb'

group :development, :test, :review do
  gem 'listen'
  gem 'spring'

  gem 'byebug'
  gem 'pry'

  gem 'capistrano-rails'
  gem 'capistrano-rvm'
  gem 'capistrano3-delayed-job'
  gem 'capistrano3-puma'

  gem 'simplecov', require: false

  # gem 'jb'

  # activate for performance profiling
  # performance profiling
  # gem 'rack-mini-profiler'
  # For memory profiling
  # gem 'memory_profiler'
  # For call-stack profiling flamegraphs
  # gem 'flamegraph'
  # gem 'stackprof'
end
