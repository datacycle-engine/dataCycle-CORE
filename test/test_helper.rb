# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'
Warning[:deprecated] = true

# raise on warnings, enable to debug warnings
# module Warning
#   def warn(message, ...)
#     raise message
#   end
# end

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

# Load the Rails frameworks before Rails.groups / Bundler.require are used.
# `rails test` / `rake test` boot the app first, but parallel_tests loads the test
# files in bare ruby processes where Rails is not yet defined. This mirrors what
# the dummy app's config/application.rb does, and runs after SimpleCov so coverage
# is still started before any application code is loaded.
require File.expand_path('dummy/lib/require_rails', __dir__)

Bundler.require(*Rails.groups)

Dotenv::Rails.load

require File.expand_path('../test/dummy/config/environment.rb', __dir__)

# Eagerly load the standalone library helpers (lib/rake_helpers, generators and the
# plain lib/data_cycle_core service objects). They are normally required on demand
# by rake tasks, so in a parallel run only the single worker exercising them records
# coverage while every other worker falls back to a zero-filled SimpleCov stub that
# also marks structural lines (e.g. `end`) as relevant-but-uncovered. Loading them
# here – after SimpleCov.start and the app boot – makes Ruby's Coverage track them
# consistently in every worker so the Libraries group is reported accurately.
[
  'rake_helpers/time_helper',
  'rake_helpers/shell_helper',
  'rake_helpers/db_helper',
  'rake_helpers/parallel_helper',
  'rake_helpers/content_helper',
  'rake_helpers/cleanup_helper',
  'rake_helpers/import_helper',
  'data_cycle_core/acknowledgments',
  'data_cycle_core/rufus_yaml_scheduler',
  'generators/rails/data_migration/data_migration_generator'
].each { |lib| require lib }
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
require 'helpers/struct_double_helper'

# NB: nothing is prepared here at boot anymore.
#  - The database preparations (classifications, external systems, templates, user roles, users,
#    user group, pg dict mappings) are loaded once per worker DB by `dc:test:setup`
#    (DataCycleCore::TestPreparations.prepare_database!), so the test DB must be set up via that
#    task before running the suite.
#  - The dummy-data fixtures are an in-memory, per-process cache and now load lazily on first
#    access (DataCycleCore::TestPreparations.dummy_data_hash), so test files that don't use them
#    pay nothing.
Rails.backtrace_cleaner.remove_silencers! if DataCycleCore::TestPreparations.cli_options[:ignore_preparations]
