# frozen_string_literal: true

# The boot sequence for a host project's test suite: every part of a project's test/test_helper.rb
# that does not depend on which project it is. A project requires this and adds only what is its
# own - see lib/templates/global/test/test_helper.rb.template for the two-line stub.
#
# The engine's own test/test_helper.rb cannot serve that purpose: it boots the dummy app under
# test/dummy and eager-loads the gem's lib/ so a gem-level run measures its coverage. The two share
# the sequence below by shape, not by file.
#
# Bundler must already be set up (the stub requires the project's config/boot first), and SimpleCov
# starts here rather than in the stub so the application boot below is measured too.
ENV['RAILS_ENV'] = 'test'

unless (ENV['TEST_COVERAGE'] || '1').to_i.zero?
  require 'simplecov'

  SimpleCov.start 'rails' do
    skip '/cache/'
    skip 'vendor'
    skip 'lib/tasks' # a task registry, not a unit: see the SimpleCov block in the engine's test/test_helper.rb
  end

  SimpleCov.at_exit do
    SimpleCov.result.format!

    # Printed to stdout, not through Rails.logger, which writes to log/test.log at a level CI does
    # not show: GitLab scrapes this line out of the job log for the coverage badge (the `coverage:`
    # regex in .gitlab-ci-dc-common.yml). Under parallel_tests every worker prints one and GitLab
    # keeps the last, which is the fully merged result.
    $stdout.puts(
      "\nCOVERAGE: " \
      "#{(100 * SimpleCov.result.covered_lines.to_f / SimpleCov.result.total_lines.to_f).round(2)}% " \
      "(#{SimpleCov.result.covered_lines} / #{SimpleCov.result.total_lines} LOC)"
    )
  end
end

require 'data_cycle_core/require_rails'

Bundler.require(*Rails.groups)

Dotenv::Rails.load

# Bundler.root holds the Gemfile, so the project is found whatever directory the suite started in.
require Bundler.root.join('config', 'environment.rb').to_s

ActiveRecord::Migrator.migrations_paths << DataCycleCore::Engine.root.join('db', 'migrate').to_s

# dc:test:setup builds every worker database by running the migrations, deliberately not by loading
# the project's committed structure.sql, so those databases carry no schema_sha1 marker. Without
# this, rails/test_help below judges them stale and loads that structure.sql over them.
ActiveRecord.maintain_test_schema = false

require 'rails/test_help'

# Filter out Minitest backtrace while allowing backtrace from other libraries to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new

# The engine's test support on the load path, so a project can require the rest of it by the same
# short paths the engine's own suite uses, e.g. `require 'helpers/api_v4_helper'`.
$LOAD_PATH.unshift(DataCycleCore::Engine.root.join('test').to_s)

# The two base classes a project's test files subclass, so `require 'test_helper'` is all they need.
require 'test_cases/active_support_test_case'
require 'test_cases/action_dispatch_integration_test'

require 'helpers/test_preparations_helper'
require 'helpers/dummy_data_helper'
require 'helpers/data_helper'
require 'helpers/mongo_helper'

# A project's own helpers, after the engine's. `test/test_helper.rb` is a template dc:upgrade
# overwrites, so a project has nowhere else to require them from, and the unshift above makes
# `require 'helpers/dummy_data_helper'` reach the engine's copy rather than a project file of that
# name. Loading them last also lets such a file reopen the engine helper it shares a name with, to
# re-point the dummy-data fixtures at the project's own fixtures for instance.
Dir[Bundler.root.join('test', 'helpers', '*.rb')].each { |helper| require helper }

# ThingTemplate caches schemas per process for import performance, and a per-test transaction
# rollback does not touch that. A test that mutates a template and persists it with update_column
# skips the after_commit invalidation, so the mutated schema would leak into the next test.
ActiveSupport::TestCase.setup do
  DataCycleCore::ThingTemplate.reset_template_caches!
end

# NB: nothing is prepared in the database here at boot. The preparations (classifications, external
# systems, templates, user roles, users, user group, pg dict mappings) are loaded once per worker DB
# by `dc:test:setup` (DataCycleCore::TestPreparations.prepare_database!, which resolves a host
# project's own configured paths), so the test DB must be set up with that task first.
#
# The dummy-data fixtures are an in-memory, per-process cache and load lazily on first access
# (DataCycleCore::TestPreparations.dummy_data_hash), so a project that does not read them pays
# nothing and one that needs its own calls load_dummy_data itself.
Rails.backtrace_cleaner.remove_silencers! if DataCycleCore::TestPreparations.cli_options[:ignore_preparations]
