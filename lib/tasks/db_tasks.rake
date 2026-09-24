# frozen_string_literal: true

require 'rake_helpers/db_helper'

namespace :db do
  namespace :migrate do
    desc 'run data migrations'
    task data: :environment do
      data_paths = Rails.application.config.paths['db/migrate'].paths
        .map { |p| p.sub('/migrate', '/data_migrate') }
      Rails.application.config.paths['db/migrate'] = data_paths
      ActiveRecord::Migrator.migrations_paths = data_paths
      ActiveRecord::Base.schema_migrations_table_name = 'data_migrations'

      ActiveRecord::Tasks::DatabaseTasks.migrate_all
    end

    desc 'check before migrations'
    task check: :environment do
      # check for unsupported PostgreSQL versions (Multi-Range Types)
      pg_version = ActiveRecord::Base.connection.select_value('SELECT VERSION()').match(/[0-9]{1,2}([,.][0-9]{1,2})?/)[0]&.to_f
      abort("PostgreSQL version #{pg_version} is not supported!") if pg_version < 14.0

      # check for missing pg_dict_mappings
      # missing_pg_dict_mappings = DataCycleCore::PgDictMapping.check_missing
      # abort("missing pg_dict_mappings (#{missing_pg_dict_mappings.join(', ')})!") if missing_pg_dict_mappings.present?

      # index_concepts_on_external_system_id_and_external_key covers this pair since Redmine #41458:
      # it is unique over the two with NULLS NOT DISTINCT, so a system-less key conflicts like any
      # other. This runs before db:migrate, which is what lets it name the offending keys - the
      # CREATE UNIQUE INDEX in 20260907120000 would otherwise abort with Postgres' own message on a
      # database that accumulated such duplicates while the index still ignored them.
      duplicate_concepts = ActiveRecord::Base.connection.execute <<~SQL.squish
        SELECT c.external_key
        FROM concepts c
        WHERE c.external_system_id IS NULL
          AND c.external_key IS NOT NULL
        GROUP BY c.external_key
        HAVING COUNT(c.id) > 1;
      SQL

      abort("duplicate internal concepts found! (#{duplicate_concepts.pluck('external_key').join(', ')})") if duplicate_concepts.any?

      ess_wo_not_null_fields = ActiveRecord::Base.connection.execute <<~SQL.squish
        SELECT id
        FROM external_system_syncs
        WHERE syncable_id IS NULL
          OR syncable_type IS NULL
          OR external_system_id IS NULL;
      SQL

      abort("external system syncs with null fields for syncable_id, syncable_type or external_system_id found! (#{ess_wo_not_null_fields.pluck('id').join(', ')})") if ess_wo_not_null_fields.any?
    end
  end

  namespace :rollback do
    desc 'run data migrations'
    task data: :environment do
      data_paths = Rails.application.config.paths['db/migrate'].paths
        .map { |p| p.sub('/migrate', '/data_migrate') }
      Rails.application.config.paths['db/migrate'] = data_paths
      ActiveRecord::Migrator.migrations_paths = data_paths
      ActiveRecord::Base.schema_migrations_table_name = 'data_migrations'
      step = ENV['STEP'] ? ENV['STEP'].to_i : 1

      ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool.migration_context.rollback(step)
    end
  end

  namespace :maintenance do
    desc 'run VACUUM (FULL) on DB, full(false|true)'
    task :vacuum, [:full, :table_names] => [:environment] do |_, args|
      full = args.fetch(:full, 'false').to_s == 'true'
      table_names = args.fetch(:table_names, nil).to_s.split('|').join(', ')

      options = []
      options << 'FULL' if full
      options << 'ANALYZE'
      sql = "#{"VACUUM (#{options.join(', ')}) #{table_names}".squish};"
      visibility_sql = "#{"VACUUM (ANALYZE) #{table_names}".squish};"

      DbHelper.without_statement_timeout do |connection|
        connection.exec_query(sql)
        connection.exec_query(visibility_sql) if full # fix visibility tables
      end
    end

    desc 'Remove activities except type donwload older than 3 monts [include_downloads=false, max_age=today-3months]'
    task :activities, [:include_downloads, :max_age] => [:environment] do |_, args|
      Rake::Task['data_cycle_core:clear:activities'].invoke(*args)
      Rake::Task['data_cycle_core:clear:activities'].reenable
    end

    desc 'reindex database and refresh collation version'
    task refresh_collation_version: :environment do
      db_name = ActiveRecord::Base.connection.current_database

      DbHelper.without_statement_timeout do |connection|
        puts "Reindexing database '#{db_name}' and refreshing collation version..."
        connection.exec_query("REINDEX DATABASE CONCURRENTLY \"#{db_name}\";")
        connection.exec_query("ALTER DATABASE \"#{db_name}\" REFRESH COLLATION VERSION;")
      ensure
        puts 'Cleanup invalid indexes...'
        connection
          .select_all('SELECT pg_class.relname FROM pg_class, pg_index WHERE pg_index.indisvalid = false AND pg_index.indexrelid = pg_class.oid;')
          .first&.each_value do |index_name|
          puts "Dropping invalid index '#{index_name}'..."
          connection.exec_query("DROP INDEX IF EXISTS \"#{index_name}\";")
        end
      end
    end
  end

  namespace :configure do
    desc 'rebuild all tables concerning transitive classifications'
    task rebuild_transitive_tables: :environment do
      DataCycleCore::Feature::TransitiveClassificationPath.rebuild_transitive_tables!
    end

    desc 'rebuild collected_concept_contents'
    task rebuild_ccc: :environment do
      DataCycleCore::Feature::TransitiveClassificationPath.rebuild_ccc!
    end

    desc 'rebuild content_content_links'
    task rebuild_content_content_links: :environment do
      ActiveRecord::Base.connection.execute <<~SQL.squish
        SELECT generate_content_content_links(ARRAY_AGG(id)) FROM content_contents;
      SQL

      next if Rails.env.test?

      Rake::Task['db:maintenance:vacuum'].invoke(true, 'content_content_links')
      Rake::Task['db:maintenance:vacuum'].reenable
    end

    desc 'rebuild schedule occurrences, optionally without the trailing VACUUM FULL'
    task :rebuild_schedule_occurrences, [:vacuum] => :environment do |_task, args|
      puts 'Rebuilding schedule occurrences...'
      tmp = Time.zone.now
      DataCycleCore::Schedule.rebuild_occurrences
      puts "Rebuilding schedule occurrences...done (#{(Time.zone.now - tmp).round}s)"

      # VACUUM FULL holds ACCESS EXCLUSIVE on schedules for the whole rebuild, so a caller that
      # cannot pick the moment - a deploy's data migration - passes false and schedules its own.
      next if args[:vacuum].to_s == 'false'

      tmp = Time.zone.now
      puts 'VACUUM FULL schedules...'
      Rake::Task['db:maintenance:vacuum'].invoke(true, 'schedules')
      Rake::Task['db:maintenance:vacuum'].reenable
      puts "VACUUM FULL schedules...done (#{(Time.zone.now - tmp).round}s)"
    end
  end

  desc 'Show the existing database backups'
  task dumps: :environment do
    backup_dir = DbHelper.backup_directory(Rails.env)
    puts backup_dir

    puts 'backup dir does not exists' unless system "cd #{backup_dir} && du -hs --time *"
  end

  desc 'Dumps the database to backups (mode = review|activities|full, max_age_hours = skip if a dump is younger)'
  task :dump, [:backup_name, :format, :mode, :max_age_hours] => [:environment] do |_, args|
    temp = Time.zone.now
    dump_fmt = DbHelper.ensure_format(args.format)
    dump_sfx = DbHelper.suffix_for_format(dump_fmt)
    backup_dir = DbHelper.backup_directory(Rails.env, create: true)
    full_path  = nil
    tmp_path   = nil
    cmd        = nil

    if args[:max_age_hours].present?
      recent = DbHelper.recent_dump(backup_dir, args[:max_age_hours].to_f.hours)

      if recent.present?
        puts "Skipping dump: #{recent} is younger than #{args[:max_age_hours]}h"
        next
      end
    end

    DbHelper.with_config do |host, port, db, user, password|
      full_path = if args[:backup_name].nil?
                    "#{backup_dir}/#{Time.zone.now.strftime('%Y%m%d%H%M%S')}_#{db}.#{dump_sfx}"
                  else
                    "#{backup_dir}/#{args[:backup_name]}.#{dump_sfx}"
                  end
      tmp_path = DbHelper.in_progress_path(full_path)

      sh "rm -rf #{full_path} #{tmp_path}" if full_path.present?

      excludes = DATABASE_DUMP_EXCLUDES[args.mode].map { |e| "--exclude-table-data='#{e}'" }.join(' ') if args.mode.present?
      cmd = "pg_dump -F #{dump_fmt}#{" -j #{ENV.fetch('POSTGRES_WORKER_COUNT', '8')}" if dump_fmt == 'd'} -v -O --compress=zstd --dbname='postgresql://#{user}:#{password}@#{host}:#{port}/#{db}' -f '#{tmp_path}' #{excludes}".squish
    end

    sh cmd
    File.rename(tmp_path, full_path)
    puts ''
    puts "Dumped to file: #{full_path}"
    puts "Duration: #{TimeHelper.format_time(Time.zone.now - temp, 0, 6, 's')}"
    puts ''
  end

  desc 'Restores the database from a backup using PATTERN'
  task :restore, [:pattern] => [:environment] do |_, args|
    temp = Time.zone.now
    pattern = args[:pattern]

    if pattern.present?
      file = nil
      cmd  = nil

      DbHelper.with_config do |host, port, db, user, password|
        backup_dir = DbHelper.backup_directory
        files      = Dir.glob("#{backup_dir}/**/#{pattern}")

        case files.size
        when 0
          puts "No backups found for the pattern '#{pattern}'"
        when 1
          file = files.first
          fmt = DbHelper.format_for_file file
          case fmt
          when nil
            puts "No recognized dump file suffix: #{file}"
          when 'p'
            cmd = "psql --dbname='postgresql://#{user}:#{password}@#{host}:#{port}/#{db}' -f '#{file}'"
          else
            cmd = "pg_restore -F #{fmt}#{" -j #{ENV.fetch('POSTGRES_WORKER_COUNT', '8')}" if fmt == 'd'} -O -v --disable-triggers --superuser=#{user} --dbname='postgresql://#{user}:#{password}@#{host}:#{port}/#{db}' '#{file}'"
          end
        else
          puts "Too many files match the pattern '#{pattern}':"
          puts " #{files.join("\n ")}"
          puts ''
          puts 'Try a more specific pattern'
          puts ''
        end
      end
      unless cmd.nil?
        ENV['DISABLE_DATABASE_ENVIRONMENT_CHECK'] = '1'
        Rake::Task['db:clear_connections'].invoke
        Rake::Task['db:clear_connections'].reenable
        Rake::Task['db:drop'].invoke
        Rake::Task['db:drop'].reenable
        Rake::Task['db:create'].invoke
        Rake::Task['db:create'].reenable
        puts cmd
        system cmd
        Rake::Task['db:maintenance:vacuum'].invoke
        Rake::Task['db:maintenance:vacuum'].reenable
        Rake::Task['dc:jobs:unlock'].invoke
        Rake::Task['dc:jobs:unlock'].reenable
        Rake::Task['dc:external_systems:fail_running_imports'].invoke
        Rake::Task['dc:external_systems:fail_running_imports'].reenable
        puts ''
        puts "Restored from file: #{file}"
        puts "Duration: #{TimeHelper.format_time(Time.zone.now - temp, 0, 6, 's')}"
        puts ''
      end
    else
      puts 'Please specify a file pattern for the backup to restore (e.g. timestamp)'
    end
  end

  desc 'remove all active database connections'
  task clear_connections: :environment do
    environments = [Rails.env]
    environments.unshift('test') if Rails.env.development?

    Rails.application.config.database_configuration.slice(*environments).each_value do |db|
      ActiveRecord::Base.establish_connection(db)
      ActiveRecord::Base.connection.exec_query "UPDATE pg_catalog.pg_database SET datallowconn=false WHERE datname='#{db['database']}'"
      ActiveRecord::Base.connection.select_all "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname='#{db['database']}' AND pid <> pg_backend_pid();"
    rescue ActiveRecord::NoDatabaseError => e
      puts e.try(:message)
    end
  end
end
