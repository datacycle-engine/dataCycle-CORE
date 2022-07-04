# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'
Warning[:deprecated] = false

unless (ENV['TEST_COVERAGE'] || '1').to_i.zero?
  require 'simplecov'
  SimpleCov.start 'rails' do
    # exclude cache folder for gitlab-ci
    add_filter '/cache/'
    add_filter 'vendor'
  end
  SimpleCov.at_exit do
    puts "\n"

    SimpleCov.result.format!

    puts "\nCOVERAGE: " \
         "#{(100 * SimpleCov.result.covered_lines.to_f / SimpleCov.result.total_lines.to_f).round(2)}% " \
         "(#{SimpleCov.result.covered_lines} / #{SimpleCov.result.total_lines} LOC)"
  end
end

Bundler.require(*Rails.groups)

Dotenv::Railtie.load

require File.expand_path('../test/dummy/config/environment.rb', __dir__)
# ActiveRecord::Migrator.migrations_paths = [File.expand_path("../../test/dummy/db/migrate", __FILE__)]
# ActiveRecord::Migrator.migrations_paths << File.expand_path('../../db/migrate', __FILE__)

# Rails 7.0
# ActiveRecord.maintain_test_schema = false
ActiveRecord::Base.maintain_test_schema = false

require 'rails/test_help'
require 'test_cases/active_support_test_case'
require 'test_cases/action_dispatch_integration_test'

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new

# FIX for delayed_jobs in TEST environment with rails 6.x:
# https://github.com/rails/rails/issues/37270
(ActiveJob::Base.descendants << ActiveJob::Base).each(&:disable_test_adapter)

# # Load fixtures from the engine
# if ActiveSupport::TestCase.respond_to?(:fixture_path=)
#   ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__)
#   ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
#   ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
#   ActiveSupport::TestCase.fixtures :all
# end

require 'helpers/test_preparations_helper'
require 'helpers/dummy_data_helper'
require 'helpers/data_helper'
require 'helpers/mongo_helper'
require 'helpers/api_v4_helper'

if DataCycleCore::TestPreparations.cli_options.dig(:ignore_preparations)
  Rails.backtrace_cleaner.remove_silencers!
else
  # DataCycleCore::TestPreparations.load_dictionaries
  DataCycleCore::TestPreparations.load_classifications(
    [
      Rails.root.join('..', 'dummy', 'config', 'data_definitions'),
      Rails.root.join('..', 'data_types', 'data_definitions', 'feature_auto_translation')
    ]
  )
  DataCycleCore::TestPreparations.load_external_systems(
    [
      Rails.root.join('..', 'dummy', 'config', 'external_systems')
    ]
  )
  DataCycleCore::TestPreparations.load_templates(
    [
      Rails.root.join('..', 'data_types', 'data_definitions', 'data_cycle_basic'),
      Rails.root.join('..', 'data_types', 'data_definitions', 'data_cycle_media'),
      Rails.root.join('..', 'data_types', 'data_definitions', 'data_cycle_creative_content'),
      Rails.root.join('..', 'data_types', 'data_definitions', 'feature_container'),
      Rails.root.join('..', 'data_types', 'data_definitions', 'feature_releasable'),
      Rails.root.join('..', 'data_types', 'data_definitions', 'feature_life_cycle'),
      Rails.root.join('..', 'data_types', 'data_definitions', 'feature_auto_translation'),
      Rails.root.join('..', 'data_types', 'data_definitions', 'external_source_bergfex'),
      Rails.root.join('..', 'data_types', 'data_definitions', 'external_source_karriere_at'),
      Rails.root.join('..', 'data_types', 'data_definitions', 'external_source_google_places'),
      Rails.root.join('..', 'data_types', 'data_definitions', 'external_source_gip'),
      Rails.root.join('..', 'data_types', 'attributes'),
      Rails.root.join('..', 'data_types', 'models')
    ]
  )
end

DataCycleCore::TestPreparations.load_dummy_data(
  [
    Rails.root.join('..', 'dummy_data'),
    Rails.root.join('..', 'v4', 'dummy_data')
  ]
)

DataCycleCore::TestPreparations.load_user_roles
DataCycleCore::TestPreparations.create_users
DataCycleCore::TestPreparations.create_user_group
