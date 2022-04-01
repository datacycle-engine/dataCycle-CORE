# frozen_string_literal: true

require 'rake_helpers/db_helper'
require 'rake_helpers/time_helper'

DATABASE_DUMP_EXCLUDES ||= {
  'review' => [
    'delayed_jobs',
    'subscriptions',
    '*histories',
    '*history_translations',
    'activities'
  ],
  'activities' => [
    'delayed_jobs',
    'subscriptions',
    '*histories',
    '*history_translations'
  ],
  'full' => [
    'delayed_jobs',
    'subscriptions'
  ]
}.freeze

namespace :data_cycle_core do
  namespace :db do
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
        cmd = "#{pgclusters}pg_dump -F #{dump_fmt}#{' -j 4' if dump_fmt == 'd'} -v -O --dbname='postgresql://#{user}:#{password}@#{host}:#{port}/#{db}' -f '#{full_path}' #{excludes}".squish
      end

      sh cmd
      puts ''
      puts "Dumped to file: #{full_path}"
      puts "Duration: #{TimeHelper.format_time(Time.zone.now - temp, 0, 6, 's')}"
      puts ''
    end

    namespace :dump do
      desc 'Dumps a specific table to backups'
      task :table, [:table, :backup_name, :format] => [:environment] do |_, args|
        table_name = args[:table]
        pgclusters = ''
        pgclusters = "PGCLUSTER=#{ENV.fetch('POSTGRES_VERSION', '11')}/main " unless ENV.fetch('PGCLUSTER_DISABLED', false)

        if table_name.present?
          dump_fmt   = DbHelper.ensure_format(args[:format])
          dump_sfx   = DbHelper.suffix_for_format(dump_fmt)
          backup_dir = DbHelper.backup_directory(Rails.env, create: true)
          full_path  = nil
          cmd        = nil

          DbHelper.with_config do |host, port, db, user, password|
            if args[:backup_name].nil?
              full_path = "#{backup_dir}/#{Time.zone.now.strftime('%Y%m%d%H%M%S')}_#{db}.#{table_name.parameterize.underscore}.#{dump_sfx}"
            else
              full_path = "#{backup_dir}/#{args[:backup_name]}.#{dump_sfx}"
            end
            cmd = "#{pgclusters}pg_dump -F #{dump_fmt} -v -O --dbname='postgresql://#{user}:#{password}@#{host}:#{port}/#{db}' -t '#{table_name}' -f '#{full_path}'"
          end

          puts cmd
          system cmd
          puts ''
          puts "Dumped to file: #{full_path}"
          puts ''
        else
          puts 'Please specify a table name'
        end
      end
    end

    desc 'Clean up database backups'
    task clean_up_dumps: :environment do
      max_files = 5
      backup_dir = DbHelper.backup_directory(Rails.env)
      files = Dir.glob("#{backup_dir}/[0-9]*.*").sort_by { |f| File.mtime(f) }.reverse
      puts "checking directory: #{backup_dir}"

      if files.size > max_files
        puts 'deleting files'
        files.drop(5).each { |file| FileUtils.rm_rf(file) }
      else
        puts "nothing to delete - file count: #{files.size}"
      end

      puts 'backup dir does not exists' unless system "cd #{backup_dir} && du -hs --time *"
    end

    desc 'Show the existing database backups'
    task dumps: :environment do
      backup_dir = DbHelper.backup_directory(Rails.env)
      puts backup_dir.to_s

      puts 'backup dir does not exists' unless system "cd #{backup_dir} && du -hs --time *"
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
          files      = Dir.glob("#{backup_dir}/**/*#{pattern}*")

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
              cmd = "#{pgclusters}pg_restore -F #{fmt}#{' -j 4' if fmt == 'd'} -O -v --disable-triggers --superuser=#{user} --dbname='postgresql://#{user}:#{password}@#{host}:#{port}/#{db}' '#{file}'"
            end
          else
            puts "Too many files match the pattern '#{pattern}':"
            puts ' ' + files.join("\n ")
            puts ''
            puts 'Try a more specific pattern'
            puts ''
          end
        end
        unless cmd.nil?
          ENV['DISABLE_DATABASE_ENVIRONMENT_CHECK'] = '1'
          Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:db:clear_connections"].invoke
          Rake::Task['db:drop'].invoke
          Rake::Task['db:create'].invoke
          puts cmd
          system cmd
          ActiveRecord::Base.connection.execute('VACUUM;')
          ActiveRecord::Base.connection.execute('ANALYZE;')
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

      ActiveRecord::Base.configurations.to_h.slice(*environments).each_value do |db|
        ActiveRecord::Base.establish_connection(db)
        ActiveRecord::Base.connection.select_all "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname='#{db['database']}' AND pid <> pg_backend_pid();"
      rescue ActiveRecord::NoDatabaseError => e
        puts e.try(:message)
      end
    end

    # desc 'import db from [cap_environment]'
    # task :import_remote_db, [:cap_environment] => [:environment] do |_, args|
    #   logger = Logger.new('log/import_live_db.log')
    #   logger.info('Started Importing Live DB...')

    #   sh "cap #{args.fetch(:cap_environment, 'pre_release')} review:download_dev_db[true]"
    #   sh "mkdir -p db/backups/#{ENV.fetch('RAILS_ENV', 'development')}/"
    #   sh "mv tmp/dev_db.dump db/backups/#{ENV.fetch('RAILS_ENV', 'development')}/dev_db.dump"

    #   Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:db:dump"].invoke
    #   Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:db:restore"].invoke('dev_db.dump')

    #   if ENV.fetch('RAILS_ENV', 'development') != 'development'
    #     Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:migrate"].invoke
    #     Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update:configs:all"].invoke(true)
    #   end

    #   logger.info('Imported Live DB successfully')
    # end

    desc 'reset database, import templates, classifications, external_sources'
    task reset: :environment do
      ENV['RAILS_ENV'] ||= Rails.env
      puts "Environment: #{ENV['RAILS_ENV']}"

      begin
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:db:clear_connections"].invoke
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:drop"].invoke
      rescue ActiveRecord::NoDatabaseError
        puts 'No Database to drop, proceeding...'
      end

      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:create"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:migrate"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:seed"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update:configs:all"].invoke
      puts 'Reset Complete...'
    end
  end
end
