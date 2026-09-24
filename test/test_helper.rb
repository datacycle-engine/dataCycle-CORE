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
  require 'simplecov-cobertura'
  SimpleCov.start 'rails' do
    # exclude cache folder for gitlab-ci
    skip '/cache/'
    skip 'vendor'
    # A .rake file is a task registry, not a unit: loading one covers its namespace/desc/task lines
    # and never a task body. No test loads them on purpose, but a worker that reaches an unstubbed
    # load_tasks adds all 53, which once took the merged coverage from 95.5% to 87.7%.
    skip 'lib/tasks'
    # Keep the human-readable HTML report and additionally emit a Cobertura XML report
    # (coverage/coverage.xml) that GitLab reads via artifacts:reports:coverage_report
    # to annotate merge-request diffs with per-line coverage.
    formatter SimpleCov::Formatter::MultiFormatter.new(
      [
        SimpleCov::Formatter::HTMLFormatter,
        SimpleCov::Formatter::CoberturaFormatter
      ]
    )
  end
  SimpleCov.at_exit do
    SimpleCov.result.format!

    # Print to stdout (not Rails.logger, which in CI writes to a file at a non-debug
    # level) so GitLab's `coverage` regex can scrape the percentage from the job log
    # for the badge and the coverage-over-time graph. Under parallel_tests each worker
    # prints a line; GitLab uses the last match, i.e. the fully merged result.
    $stdout.puts(
      "\nCOVERAGE: " \
      "#{(100 * SimpleCov.result.covered_lines.to_f / SimpleCov.result.total_lines.to_f).round(2)}% " \
      "(#{SimpleCov.result.covered_lines} / #{SimpleCov.result.total_lines} LOC)"
    )
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
  'rake_helpers/concept_filter_upgrade_helper',
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

# Test-only safety net against sparql, which redefines Hash#deep_dup as
# `inject({}) { |memo, (k, v)| memo.merge(k => v.deep_dup) }` (sparql/algebra/extensions.rb).
# Starting from a bare `{}` drops the receiver's class, so DataCycleCore.features comes back
# a plain Hash with String keys, tests read the copy by SYMBOL
# (`DataCycleCore.features[feature.to_sym]` in Feature.configuration), miss, and get nil for
# the whole feature config.
#
# Only rdf_shacl_conformance_test.rb pulls sparql in, via `require 'shacl'` — but the patch is
# process-wide and permanent from then on, and the worker that ran it goes on to run unrelated
# classes. Re-assert the invariant rather than depending on file order.
module DataCycleCore
  module IndifferentDeepDup
    def deep_dup
      super.with_indifferent_access
    end
  end
end
ActiveSupport::HashWithIndifferentAccess.prepend(DataCycleCore::IndifferentDeepDup)

# Snapshot the freshly-loaded feature configuration before any test can mutate the
# shared global DataCycleCore.features. MinitestHookHelper restores this snapshot
# after every test class, so in-place mutations cannot leak across classes and crash
# unrelated tests scheduled later in the same parallel_tests worker.
DataCycleCore::MinitestHookHelper.capture_pristine_features!

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
require 'helpers/pixie_annotation_test_helper'
require 'helpers/data_helper'
require 'helpers/mongo_helper'
require 'helpers/api_v4_helper'
require 'helpers/active_storage_helper'
require 'helpers/struct_double_helper'
require 'helpers/mcp_test_helper'
require 'helpers/i18n_test_helper'
require 'helpers/asset_preview_double_helper'
require 'helpers/oembed_provider_helper'
require 'helpers/solid_queue_helper'

# The ThingTemplate process-level caches (import performance) hand out shared state for the whole
# process, and a per-test transaction rollback does not touch it. Tests mutate a template's schema as
# setup and persist it with update_column (e.g. set_default_value), which skips the after_commit cache
# invalidation — so the cache instance loaded during that test keeps the mutated schema and, since the
# rollback does not clear the cache, leaks it into the next test. The flagged-compute cache derives from
# the same template data, so the same mutations stale it. Reset before every test to match the DB-level
# isolation. (The ExternalSystem cache needs no reset here: nothing mutates a cached external system in
# place, and the full suite is green without it.)
ActiveSupport::TestCase.setup do
  DataCycleCore::ThingTemplate.reset_template_caches!
end

# NB: nothing is prepared here at boot anymore.
#  - The database preparations (classifications, external systems, templates, user roles, users,
#    user group, pg dict mappings) are loaded once per worker DB by `dc:test:setup`
#    (DataCycleCore::TestPreparations.prepare_database!), so the test DB must be set up via that
#    task before running the suite.
#  - The dummy-data fixtures are an in-memory, per-process cache and now load lazily on first
#    access (DataCycleCore::TestPreparations.dummy_data_hash), so test files that don't use them
#    pay nothing.
Rails.backtrace_cleaner.remove_silencers! if DataCycleCore::TestPreparations.cli_options[:ignore_preparations]
