source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

# Declare your gem's dependencies in data_cycle_core.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec
gem 'globalize', github: 'globalize/globalize'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

group :development, :test do
  gem 'byebug'
  gem 'dotenv-rails'
  gem 'pry'

  gem 'capistrano-rails'
  gem 'capistrano-rvm'
  gem 'capistrano3-delayed-job'
  gem 'capistrano3-puma'
end
