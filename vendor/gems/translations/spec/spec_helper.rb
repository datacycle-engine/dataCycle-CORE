# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

ENV['RAILS_VERSION'] ||= '5.2'

orm = ENV['ORM'] || 'none'
require 'active_record' if orm == 'active_record'

db = ENV['DB'] || 'none'

require 'pry-byebug'
require 'i18n'
require 'i18n/backend/fallbacks' if ENV['I18N_FALLBACKS']
require 'rspec'
require 'allocation_stats' if ENV['TEST_PERFORMANCE']
require 'json'
require 'awesome_print'

require 'translations'
require 'translations/backends/null'

# Enable default plugins
Translations.configure do |config|
  config.plugins(:query, :cache, :attribute_methods)
  # :dirty,
  # :presence
end

I18n.enforce_available_locales = true
I18n.available_locales = [:en, :'en-US', :ja, :fr, :de, :'de-DE', :cz, :pl, :pt, :'pt-BR']
I18n.default_locale = :en

Dir[File.expand_path('./spec/support/**/*.rb')].each { |f| require f }

unless orm == 'none'
  require 'database'
  require "#{orm}/schema"

  require 'database_cleaner'
  DatabaseCleaner.strategy = :transaction

  DB = Translations::Test::Database.connect(orm)
  # for in-memory sqlite database
  Translations::Test::Database.auto_migrate

  require "#{orm}/models"
end

RSpec.configure do |config|
  config.include Helpers
  config.include Translations::Util
  if defined?(ActiveSupport)
    require 'active_support/testing/time_helpers'
    config.include ActiveSupport::Testing::TimeHelpers
  end

  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before :each do |example|
    if (version = example.metadata[:rails_version_geq]) && (ENV['RAILS_VERSION'] < version)
      skip "Unsupported for Rails < #{version}"
    end
    # Always clear I18n.fallbacks to avoid "leakage" between specs
    reset_i18n_fallbacks
    I18n.locale = :en
    # Translations.locale = :en
  end

  unless orm == 'none'
    config.before :each do
      DatabaseCleaner.start
    end
    config.after :each do
      DatabaseCleaner.clean
    end
  end

  config.order = 'random'
  config.filter_run_excluding orm: ->(v) { ![*v].include?(orm.to_sym) }, db: ->(v) { ![*v].include?(db.to_sym) }
end

class TestAttributes < Translations::Attributes
end
