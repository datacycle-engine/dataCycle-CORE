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

    desc 'load the test data (classifications, templates, users, …) into the current test database'
    task prepare_database: :environment do
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
      # Don't let the migration run rewrite the committed structure.sql. NB: db:migrate:reset
      # can't be used here — its prerequisite chain (db:drop db:create db:schema:dump db:migrate)
      # invokes db:schema:dump unconditionally, ignoring dump_schema_after_migration, so it would
      # rewrite structure.sql regardless. Run the steps ourselves, minus the dump. The flag below
      # still suppresses the post-migrate db:_dump.
      ActiveRecord.dump_schema_after_migration = false
      ['db:drop', 'db:create', 'db:migrate:reset', 'db:seed', 'dc:test:prepare_database'].each do |t|
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
      # system tests need capybara/selenium (not bundled and skipped by `rails test` too)
      sh('bundle', 'exec', 'parallel_test', 'test/', '-t', 'test', '--exclude-pattern', 'test/system', *n)
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
