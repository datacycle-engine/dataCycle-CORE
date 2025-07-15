# frozen_string_literal: true

require 'rake_helpers/db_helper'

namespace :db do
  namespace :migrate do
    desc 'run data migrations'
    task with_data: :environment do
      data_paths = Rails.application.config.paths['db/migrate'].paths.map { |p| p.sub('/migrate', '/data_migrate') }
      Rails.application.config.paths['db/migrate'].concat(data_paths)
      ActiveRecord::Migrator.migrations_paths.concat(data_paths)

      Rake::Task['db:migrate'].invoke
      Rake::Task['db:migrate'].reenable
    end

    desc 'check before migrations'
    task check: :environment do
      # check for unsupported PostgreSQL versions (Multi-Range Types)
      pg_version = ActiveRecord::Base.connection.select_value('SELECT VERSION()').match(/[0-9]{1,2}([,.][0-9]{1,2})?/)[0]&.to_f
      abort("PostgreSQL version #{pg_version} is not supported!") if pg_version < 14.0

      # check for missing pg_dict_mappings
      # missing_pg_dict_mappings = DataCycleCore::PgDictMapping.check_missing
      # abort("missing pg_dict_mappings (#{missing_pg_dict_mappings.join(', ')})!") if missing_pg_dict_mappings.present?

      result = ActiveRecord::Base.connection.execute <<-SQL.squish
        WITH duplicate_external_classification AS (
          SELECT classifications.external_source_id,
            classifications.external_key,
            COUNT(*)
          FROM classifications
          WHERE classifications.external_source_id IS NOT NULL
            AND classifications.external_key IS NOT NULL
            AND classifications.deleted_at IS NULL
          GROUP BY classifications.external_source_id,
            classifications.external_key
          HAVING COUNT(*) > 1
        )
        SELECT classifications.id,
          classification_alias_paths.full_path_names,
          classification_contents.content_data_id
        FROM duplicate_external_classification
          JOIN classifications ON duplicate_external_classification.external_source_id = classifications.external_source_id
          AND duplicate_external_classification.external_key = classifications.external_key
          JOIN classification_groups ON classifications.id = classification_groups.classification_id
          JOIN classification_alias_paths ON classification_groups.classification_alias_id = classification_alias_paths.id
          LEFT OUTER JOIN classification_contents ON classification_contents.classification_id = classifications.id
        ORDER BY CHAR_LENGTH(classifications.external_key),
          classifications.external_key;
      SQL

      abort('duplicate external_classifications found!') if result.any?
    end
  end

  namespace :rollback do
    desc 'run data migrations'
    task with_data: :environment do
      data_paths = Rails.application.config.paths['db/migrate'].paths.map { |p| p.sub('/migrate', '/data_migrate') }
      Rails.application.config.paths['db/migrate'].concat(data_paths)
      ActiveRecord::Migrator.migrations_paths.concat(data_paths)

      Rake::Task['db:rollback'].invoke
      Rake::Task['db:rollback'].reenable
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

      ActiveRecord::Base.connection.exec_query('SET statement_timeout = 0;')
      ActiveRecord::Base.connection.exec_query(sql)
      ActiveRecord::Base.connection.exec_query(visibility_sql) if full # fix visibility tables
      ActiveRecord::Base.connection.exec_query('SET statement_timeout = 60000;')
    end

    desc 'Remove activities except type donwload older than 3 monts [include_downloads=false, max_age=today-3months]'
    task :activities, [:include_downloads, :max_age] => [:environment] do |_, args|
      Rake::Task['data_cycle_core:clear:activities'].invoke(*args)
      Rake::Task['data_cycle_core:clear:activities'].reenable
    end
  end

  namespace :configure do
    desc 'rebuild all tables concerning transitive classifications'
    task rebuild_transitive_tables: :environment do
      if DataCycleCore::Feature::TransitiveClassificationPath.enabled?
        ActiveRecord::Base.connection.execute <<-SQL.squish
          SET LOCAL statement_timeout = 0;
          SELECT public.upsert_ca_paths_transitive (ARRAY_AGG(id)) FROM concepts;
        SQL
      else
        ActiveRecord::Base.connection.execute <<-SQL.squish
          SET LOCAL statement_timeout = 0;
          SELECT public.upsert_ca_paths (ARRAY_AGG(id)) FROM concepts;
        SQL
      end

      Rake::Task['db:configure:rebuild_ccc'].invoke
      Rake::Task['db:configure:rebuild_ccc'].reenable

      next if Rails.env.test?

      Rake::Task['db:maintenance:vacuum'].invoke(true, 'classification_alias_paths|classification_alias_paths_transitive|collected_classification_contents')
      Rake::Task['db:maintenance:vacuum'].reenable
    end

    desc 'rebuild collected_classification_contents'
    task rebuild_ccc: :environment do
      if DataCycleCore::Feature::TransitiveClassificationPath.enabled?
        ActiveRecord::Base.connection.execute <<-SQL.squish
          SET LOCAL statement_timeout = 0;
          SELECT public.generate_collected_cl_content_relations_transitive (array_agg(things.id))
          FROM things;
        SQL
      else
        ActiveRecord::Base.connection.execute <<-SQL.squish
          SET LOCAL statement_timeout = 0;
          SELECT public.generate_collected_classification_content_relations (array_agg(things.id), ARRAY[]::UUID[])
          FROM things;
        SQL
      end
    end

    desc 'rebuild content_content_links'
    task rebuild_content_content_links: :environment do
      ActiveRecord::Base.connection.execute <<-SQL.squish
        SELECT generate_content_content_links(ARRAY_AGG(id)) FROM content_contents;
      SQL

      next if Rails.env.test?

      Rake::Task['db:maintenance:vacuum'].invoke(true, 'content_content_links')
      Rake::Task['db:maintenance:vacuum'].reenable
    end

    desc 'rebuild schedule occurrences'
    task rebuild_schedule_occurrences: :environment do
      puts 'Rebuilding schedule occurrences...'
      tmp = Time.zone.now
      DataCycleCore::Schedule.rebuild_occurrences
      puts "Rebuilding schedule occurrences...done (#{(Time.zone.now - tmp).round}s)"

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

  desc 'Dumps the database to backups (mode = review|activities|full)'
  task :dump, [:backup_name, :format, :mode] => [:environment] do |_, args|
    temp = Time.zone.now
    dump_fmt = DbHelper.ensure_format(args[:format])
    dump_sfx = DbHelper.suffix_for_format(dump_fmt)
    backup_dir = DbHelper.backup_directory(Rails.env, create: true)
    full_path  = nil
    cmd        = nil

    pgclusters = ''
    pgclusters = "PGCLUSTER=#{ENV.fetch('POSTGRES_VERSION', '11')}/main " unless ENV.fetch('PGCLUSTER_DISABLED', false)

    DbHelper.with_config do |host, port, db, user, password|
      if args[:backup_name].nil?
        full_path = "#{backup_dir}/#{Time.zone.now.strftime('%Y%m%d%H%M%S')}_#{db}.#{dump_sfx}"
      else
        full_path = "#{backup_dir}/#{args[:backup_name]}.#{dump_sfx}"
      end

      sh "rm -rf #{full_path}" if full_path.present?

      excludes = DATABASE_DUMP_EXCLUDES[args.mode].map { |e| "--exclude-table-data='#{e}'" }.join(' ') if args.mode.present?
      cmd = "#{pgclusters}pg_dump -F #{dump_fmt}#{" -j #{ENV.fetch('POSTGRES_WORKER_COUNT', '8')}" if dump_fmt == 'd'} -v -O --dbname='postgresql://#{user}:#{password}@#{host}:#{port}/#{db}' -f '#{full_path}' #{excludes}".squish
    end

    sh cmd
    puts ''
    puts "Dumped to file: #{full_path}"
    puts "Duration: #{TimeHelper.format_time(Time.zone.now - temp, 0, 6, 's')}"
    puts ''
  end

  desc 'Restores the database from a backup using PATTERN'
  task :restore, [:pattern] => [:environment] do |_, args|
    temp = Time.zone.now
    pattern = args[:pattern]
    pgclusters = ''
    pgclusters = "PGCLUSTER=#{ENV.fetch('POSTGRES_VERSION', '11')}/main " unless ENV.fetch('PGCLUSTER_DISABLED', false)

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
            cmd = "#{pgclusters}pg_restore -F #{fmt}#{" -j #{ENV.fetch('POSTGRES_WORKER_COUNT', '8')}" if fmt == 'd'} -O -v --disable-triggers --superuser=#{user} --dbname='postgresql://#{user}:#{password}@#{host}:#{port}/#{db}' '#{file}'"
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
