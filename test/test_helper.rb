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
    Rails.logger.debug "\n"

    SimpleCov.result.format!

    Rails.logger.debug do
      "\nCOVERAGE: " \
        "#{(100 * SimpleCov.result.covered_lines.to_f / SimpleCov.result.total_lines.to_f).round(2)}% " \
        "(#{SimpleCov.result.covered_lines} / #{SimpleCov.result.total_lines} LOC)"
    end
  end
end

Bundler.require(*Rails.groups)

Dotenv::Rails.load

require File.expand_path('../test/dummy/config/environment.rb', __dir__)
# ActiveRecord::Migrator.migrations_paths = [File.expand_path("../../test/dummy/db/migrate", __FILE__)]
# ActiveRecord::Migrator.migrations_paths << File.expand_path('../../db/migrate', __FILE__)

# Rails 7.0
ActiveRecord.maintain_test_schema = false

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
require 'helpers/active_storage_helper'

if DataCycleCore::TestPreparations.cli_options[:ignore_preparations]
  Rails.backtrace_cleaner.remove_silencers!
else
  # DataCycleCore::TestPreparations.load_dictionaries
  DataCycleCore::TestPreparations.load_classifications(
    [
      Rails.root.join('..', 'data_types', 'data_definitions', 'data_cycle_test')
    ]
  )
  DataCycleCore::TestPreparations.load_external_systems(
    [
      Rails.root.join('..', 'fixtures', 'external_systems')
    ]
  )
  DataCycleCore::TestPreparations.load_templates(
    [
      Rails.root.join('..', 'data_types', 'data_definitions', 'data_cycle_test'),
      Rails.root.join('..', 'data_types', 'attributes'),
      Rails.root.join('..', 'data_types', 'models')
    ]
  )
end

DataCycleCore::TestPreparations.load_dummy_data(
  [
    Rails.root.join('..', 'fixtures', 'data'),
    Rails.root.join('..', 'v4', 'fixtures', 'data')
  ]
)

DataCycleCore::TestPreparations.load_user_roles
DataCycleCore::TestPreparations.create_users
DataCycleCore::TestPreparations.create_user_group
DataCycleCore::PgDictMapping.upsert_missing
