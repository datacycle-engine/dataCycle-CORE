# frozen_string_literal: true

# Convenience tasks for running the test suite in parallel via the parallel_tests gem.
# Each worker process gets its own database (…_test, …_test2, …) selected by the
# TEST_ENV_NUMBER env var, which sidesteps the DRb/minitest-hooks incompatibility that
# makes Rails' built-in `parallelize` unusable here. See test/dummy/config/database.yml.
#
# These shell out to child processes (rather than using parallel_tests' rake tasks)
# so they behave the same from the gem root, the dummy app and a host project without
# depending on `parallel_tests/tasks` being loaded into the current rake context.
namespace :dc do
  namespace :test do
    # NB: read args[:count], never args.count — the latter is Enumerable#count (the number
    # of arguments) and would silently pass "1" through as the worker count.

    # The TestPreparations helper lives in the engine's test directory, which is not on the
    # load path in a normal rake/app context, so add it before requiring the helper.
    test_lib = File.expand_path('../../test', __dir__)

    # RAILS_ENV must already be `test` when the process starts — a task cannot flip it in
    # process. config/application.rb runs `Bundler.require(*Rails.groups)` at boot, which
    # both memoizes Rails.env and loads that env's gem groups long before any task body (or
    # even this file) is loaded, so setting ENV['RAILS_ENV'] here would be far too late.
    # CI exports RAILS_ENV=test; the parent tasks below pass it to their child processes
    # explicitly (the `sh` calls) and `setup` clones from the `env_name: 'test'` config, so
    # they are safe to run without a prefix. Guard only the internal DB-mutating tasks so
    # invoking one directly from a non-test shell aborts instead of dropping/seeding the
    # development database.
    ensure_test_env = lambda do
      next if Rails.env.test?

      abort "dc:test:* operate on the test database, but RAILS_ENV=#{Rails.env}. " \
            'Re-run with RAILS_ENV=test (e.g. `RAILS_ENV=test bundle exec rake …`).'
    end

    # Fail the run when the merged line coverage falls below MIN_COVERAGE (a percentage,
    # e.g. 95). Opt-in: with MIN_COVERAGE unset or 0 this is a no-op, so only pipelines
    # that set the variable enforce the gate and host projects keep their current behaviour.
    #
    # It reads coverage/.last_run.json rather than re-implementing SimpleCov's
    # minimum_coverage. The latter runs per process, and under parallel_tests every worker
    # is a bare `rails test` process where SimpleCov.final_result_process? is true, so each
    # would enforce the threshold against its own partial merge and fail the build
    # spuriously. Enforcing once here — after all workers have finished and merged — checks
    # the same complete percentage GitLab scrapes for the coverage badge (the last worker to
    # exit always holds every other worker's result; see test/test_helper.rb).
    check_coverage = lambda do
      require 'json'
      minimum = ENV['MIN_COVERAGE'].to_f
      next unless minimum.positive?

      last_run = File.expand_path('coverage/.last_run.json', Dir.pwd)
      unless File.exist?(last_run)
        abort "MIN_COVERAGE=#{ENV['MIN_COVERAGE']} is set, but #{last_run} is missing — " \
              'was the suite run with coverage enabled (TEST_COVERAGE=1)?'
      end

      covered = JSON.parse(File.read(last_run)).dig('result', 'line')
      abort "could not read line coverage from #{last_run}" if covered.nil?

      abort "Line coverage #{covered.round(2)}% is below the required minimum of #{minimum.round(2)}%." if covered < minimum

      puts "Line coverage #{covered.round(2)}% meets the required minimum of #{minimum.round(2)}%."
    end

    desc 'load the test data (classifications, templates, users, …) into the current test database'
    task prepare_database: :environment do
      ensure_test_env.call
      $LOAD_PATH.unshift(test_lib) unless $LOAD_PATH.include?(test_lib)
      require 'helpers/test_preparations_helper'
      DataCycleCore::TestPreparations.prepare_database!
    end

    # Internal: fully prepare ONE worker database in a single Rails boot —
    # (re)create the database and bring it up to date by running every migration from
    # scratch (instead of loading the committed structure.sql, which has caused schema
    # inconsistencies in CI), load the engine seed (db:seed) and then the test data
    # (dc:test:prepare_database). Picks up TEST_ENV_NUMBER from the env.
    desc 'fully prepare the current worker test database (migrations + engine seed + test data)'
    task setup_worker: :environment do
      ensure_test_env.call
      # Neither db:migrate:reset nor db:migrate can build this database: the former's prerequisite
      # chain (db:drop db:create db:schema:dump db:migrate) dumps over the committed structure.sql
      # whatever dump_schema_after_migration says, the latter loads it into the empty database first
      # (DatabaseTasks#initialize_database) — and a host project's dump describes ITS postgres image,
      # e.g. a text search dictionary whose .ths file no other image has, on which psql aborts the
      # whole load. Run the steps ourselves; the flag still suppresses the post-migrate db:_dump.
      ActiveRecord.dump_schema_after_migration = false
      ['db:drop', 'db:create'].each do |t|
        Rake::Task[t].invoke
        Rake::Task[t].reenable
      end
      # migrate_all minus initialize_database; db:drop above already ran db:load_config.
      ActiveRecord::Tasks::DatabaseTasks.migrate(skip_initialize: true)
      ['db:seed', 'dc:test:prepare_database'].each do |t|
        Rake::Task[t].invoke
        Rake::Task[t].reenable
      end
    end

    desc 'create, load the schema into and seed one test database per parallel worker ([count] defaults to CPU count)'
    task :setup, [:count] => :environment do |_, args|
      require 'etc'
      count = (args[:count] || ENV['PARALLEL_TEST_PROCESSORS'] || Etc.nprocessors).to_i
      # The engine's tasks are prefixed with `app:` when run from the gem (dummy app),
      # but are bare in a host project that mounts the engine. Honour CORE_RAKE_PREFIX
      # if it's set (CI does), otherwise detect which name the child rails will recognise.
      prefix = ENV.fetch('CORE_RAKE_PREFIX', nil) ||
               (Rake::Task.task_defined?('app:dc:test:setup_worker') ? 'app:' : '')
      # Prepare ONLY the first worker database (migrations + engine seed + test data) and
      # clone it for the remaining workers below. Migrating all worker databases
      # concurrently intermittently broke on the initial migration: parallel
      # CREATE EXTENSION (postgis et al.) across databases races on shared catalogs
      # ("tuple concurrently updated"), and parallel CREATE DATABASE fights over template1.
      sh({ 'RAILS_ENV' => 'test', 'TEST_ENV_NUMBER' => nil },
         'bundle', 'exec', 'rails', "#{prefix}dc:test:setup_worker")
      # Build the vite test assets once, up front, for the same reason: the workers'
      # lazy autoBuild (config/vite.json) only guards against concurrent builds with a
      # per-process Mutex, so several worker processes race `vite build` on the shared
      # output directory and one intermittently reads a half-written manifest
      # ("Vite Ruby can't find entrypoints/application.js in the manifests").
      # With a fresh build in place every worker's digest check skips its own build.
      sh({ 'RAILS_ENV' => 'test', 'TEST_ENV_NUMBER' => nil },
         'bundle', 'exec', 'rails', "#{prefix}vite:build")
      next if count <= 1

      # CREATE DATABASE ... TEMPLATE requires that nothing is connected to the template
      # database — drop this process' own connections (under RAILS_ENV=test the rake
      # :environment boot connects to it) and talk to the maintenance DB instead.
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: 'test', name: 'primary')
      template = db_config.database
      ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
      ActiveRecord::Base.establish_connection(
        db_config.configuration_hash.merge(database: 'postgres', schema_search_path: 'public')
      )
      connection = ActiveRecord::Base.connection
      (2..count).each do |worker|
        worker_db = connection.quote_table_name("#{template}#{worker}")
        connection.execute("DROP DATABASE IF EXISTS #{worker_db} WITH (FORCE)") # FORCE needs PostgreSQL >= 13
        connection.execute("CREATE DATABASE #{worker_db} TEMPLATE #{connection.quote_table_name(template)}")
        puts "Cloned #{template} -> #{template}#{worker}"
      end
    end

    desc 'run the whole test suite in parallel across the worker databases ([count] defaults to CPU count)'
    task :run, [:count] => :environment do |_, args|
      n = args[:count] ? ['-n', args[:count].to_s] : []
      # Drop any stale SimpleCov result so the coverage gate below can't pass on a previous
      # run's number if this run produces none (e.g. coverage disabled). SimpleCov rewrites it.
      last_run = File.expand_path('coverage/.last_run.json', Dir.pwd)
      File.delete(last_run) if ENV['MIN_COVERAGE'].to_f.positive? && File.exist?(last_run)
      # system tests need capybara/selenium (not bundled and skipped by `rails test` too).
      # parallel_test is a bare binary, not `rails test`, so nothing forces the env for its
      # workers -- a shell that exports RAILS_ENV (the dev containers set `development`) would
      # otherwise have them boot the development app and run the suite against its database.
      sh({ 'RAILS_ENV' => 'test' },
         'bundle', 'exec', 'parallel_test', 'test/', '-t', 'test', '--exclude-pattern', 'test/system', *n)
      # Only reached when the suite passed (sh raises otherwise) — gate on the merged coverage.
      check_coverage.call
    end

    desc 'fail if the last recorded line coverage is below MIN_COVERAGE (percent; no-op when unset/0)'
    task check_coverage: :environment do
      check_coverage.call
    end

    desc 'set up the worker databases and then run the whole suite in parallel ([count] defaults to CPU count)'
    task :all, [:count] => :environment do |_, args|
      Rake::Task['dc:test:setup'].invoke(args[:count])
      Rake::Task['dc:test:setup'].reenable
      Rake::Task['dc:test:run'].invoke(args[:count])
      Rake::Task['dc:test:run'].reenable
    end
  end
end
