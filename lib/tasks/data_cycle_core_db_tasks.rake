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
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:dump"].invoke(*args)
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:dump"].reenable
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
      puts backup_dir

      puts 'backup dir does not exists' unless system "cd #{backup_dir} && du -hs --time *"
    end

    desc 'Restores the database from a backup using PATTERN'
    task :restore, [:pattern] => [:environment] do |_, args|
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:restore"].invoke(*args)
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:restore"].reenable
    end

    desc 'remove all active database connections'
    task clear_connections: :environment do
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:clear_connections"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:clear_connections"].reenable
    end

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
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update:configs"].invoke
      puts 'Reset Complete...'
    end
  end
end
