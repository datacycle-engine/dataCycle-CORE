# frozen_string_literal: true

require 'rake_helpers/db_helper'
require 'rake_helpers/time_helper'

namespace :data_cycle_core do
  namespace :mongo do
    desc 'List all external_systems'
    task list: :environment do
      DataCycleCore::ExternalSystem.find_each do |es|
        puts "#{es.id} -> #{es.identifier}(#{es.name})"
      end
    end

    desc 'Show the existing database archives'
    task dumps: :environment do
      backup_dir = DbHelper.backup_directory([Rails.env, 'mongo'])
      puts backup_dir.to_s
      DataCycleCore::ExternalSystem.find_each do |es|
        db_name = es.database_name
        puts "#{db_name} --> #{es.identifier}(#{es.name})"
        system "cd #{backup_dir}; du -hs --time #{db_name}*" if Dir.glob("#{backup_dir}/#{db_name}_*").size.positive?
      end
    end

    desc 'Clean up database backups'
    task clean_up_dumps: :environment do
      max_files = 5
      backup_dir = DbHelper.backup_directory([Rails.env, 'mongo'])
      puts "checking directory: #{backup_dir}"
      DataCycleCore::ExternalSystem.find_each do |es|
        db_name = es.database_name
        files = Dir.glob("#{backup_dir}/#{db_name}_*").sort_by { |f| File.mtime(f) }.reverse
        puts "#{db_name} --> #{es.identifier}(#{es.name})"
        if files.size > max_files
          puts 'deleting files'
          files.drop(5).each { |file| FileUtils.rm_rf(file) }
        else
          puts "nothing to delete - file count: #{files.size}"
        end
      end

      puts 'all files:'
      system "cd #{backup_dir}; du -hs --time *"
    end

    desc 'Dump a mongo db'
    task :dump, [:external_system_id, :download] => [:environment] do |_, args|
      temp = Time.zone.now
      backup_dir = DbHelper.backup_directory([Rails.env, 'mongo'], create: true)
      download_dir = DbHelper.backup_directory([Rails.env, 'mongo', 'download'], create: true)
      date = Time.zone.now.to_s(:compact_datetime)
      file_name = nil

      external_system = DataCycleCore::ExternalSystem.find(args[:external_system_id])
      if external_system.blank?
        puts 'Id is not a valid external System!'
        exit 1
      end

      db_name = external_system.database_name
      if args[:download] == 'true'
        file_name = "#{download_dir}/#{db_name}_download.archive"
      else
        file_name = "#{backup_dir}/#{db_name}_#{date}.archive"
      end

      cmd = "mongodump --db #{db_name} --archive > #{file_name}"
      sh cmd
      puts ''
      puts "Dumped to file: #{file_name}"
      puts "Duration: #{TimeHelper.format_time(Time.zone.now - temp, 0, 6, 's')}"
      puts ''
    end

    desc 'Restores a mongo db from a backup archive'
    task :restore, [:file_name, :downloaded, :port] => [:environment] do |_, args|
      temp = Time.zone.now
      file_name = args[:file_name]

      dir = DbHelper.backup_directory([Rails.env, 'mongo'], create: true)
      dir = DbHelper.backup_directory([Rails.env, 'mongo', 'download'], create: true) if args[:downloaded] == 'true'

      origin_db_name = file_name.split('_')[0..-2].join('_')
      external_system_id = file_name.split('_')[-2]
      db_name = [DataCycleCore::Generic::Collection.database_name, external_system_id].join('_')
      port = args[:port] || '27017'

      cmd = "mongorestore --port=#{port} --archive=#{dir}/#{file_name} --drop --nsFrom='#{origin_db_name}.*' --nsTo='#{db_name}.*'"
      sh cmd
      puts ''
      puts "DB source: #{origin_db_name}"
      puts "DB target: #{db_name}"
      puts "reloaded: #{dir}/#{file_name}"
      puts "Duration: #{TimeHelper.format_time(Time.zone.now - temp, 0, 6, 's')}"
      puts ''
    end

    desc 'print full name of a mongodb'
    task :name, [:uuid] => [:environment] do |_, args|
      external_system = DataCycleCore::ExternalSystem.find_by(id: args[:uuid])
      if external_system.blank?
        puts 'Id is not a valid external System.'
        exit 1
      end

      db_name = external_system.database_name
      puts db_name
    end
  end
end
