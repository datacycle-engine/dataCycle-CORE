# frozen_string_literal: true

namespace :data_cycle_core do
  namespace :db do
    desc 'Dumps the database to backups'
    task :dump, [:backup_name, :format, :mode] => [:environment] do |_, args|
      dump_fmt   = ensure_format(args[:format])
      dump_sfx   = suffix_for_format(dump_fmt)
      backup_dir = backup_directory(Rails.env, create: true)
      full_path  = nil
      cmd        = nil

      with_config do |host, port, db, user, password|
        if args[:backup_name].nil?
          full_path = "#{backup_dir}/#{Time.zone.now.strftime('%Y%m%d%H%M%S')}_#{db}.#{dump_sfx}"
        else
          full_path = "#{backup_dir}/#{args[:backup_name]}.#{dump_sfx}"
        end

        case args[:mode]
        when 'review'
          cmd = "PGCLUSTER=#{ENV.fetch('POSTGRES_VERSION', '9.6')}/main pg_dump -F #{dump_fmt} -v -o -O --dbname='postgresql://#{user}:#{password}@#{host}:#{port}/#{db}' -f '#{full_path}' --exclude-table-data='delayed_jobs' --exclude-table-data='subscriptions' --exclude-table-data='*histories'"
        when 'full'
          cmd = "PGCLUSTER=#{ENV.fetch('POSTGRES_VERSION', '9.6')}/main pg_dump -F #{dump_fmt} -v -o -O --dbname='postgresql://#{user}:#{password}@#{host}:#{port}/#{db}' -f '#{full_path}' --exclude-table-data='delayed_jobs' --exclude-table-data='subscriptions'"
        else
          cmd = "PGCLUSTER=#{ENV.fetch('POSTGRES_VERSION', '9.6')}/main pg_dump -F #{dump_fmt} -v -o -O --dbname='postgresql://#{user}:#{password}@#{host}:#{port}/#{db}' -f '#{full_path}'"
        end
      end

      puts cmd
      system cmd
      puts ''
      puts "Dumped to file: #{full_path}"
      puts ''
    end

    namespace :dump do
      desc 'Dumps a specific table to backups'
      task :table, [:table, :backup_name, :format] => [:environment] do |_, args|
        table_name = args[:table]

        if table_name.present?
          dump_fmt   = ensure_format(args[:format])
          dump_sfx   = suffix_for_format(dump_fmt)
          backup_dir = backup_directory(Rails.env, create: true)
          full_path  = nil
          cmd        = nil

          with_config do |host, port, db, user, password|
            if args[:backup_name].nil?
              full_path = "#{backup_dir}/#{Time.zone.now.strftime('%Y%m%d%H%M%S')}_#{db}.#{table_name.parameterize.underscore}.#{dump_sfx}"
            else
              full_path = "#{backup_dir}/#{args[:backup_name]}.#{dump_sfx}"
            end
            cmd = "PGCLUSTER=#{ENV.fetch('POSTGRES_VERSION', '9.6')}/main pg_dump -F #{dump_fmt} -v -o -O --dbname='postgresql://#{user}:#{password}@#{host}:#{port}/#{db}' -t '#{table_name}' -f '#{full_path}'"
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
      backup_dir = backup_directory(Rails.env)
      files = Dir.glob("#{backup_dir}/[0-9]*.sql").sort_by { |f| File.mtime(f) }.reverse
      puts "checking directory: #{backup_dir}"

      if files.size > max_files
        puts 'deleting files'
        files.drop(5).each { |file| File.delete(file) }
      else
        puts "nothing to delete - file count: #{files.size}"
      end
      system "/bin/ls -lt #{backup_dir}"
    end

    desc 'Show the existing database backups'
    task dumps: :environment do
      backup_dir = backup_directory(Rails.env)
      puts backup_dir.to_s
      system "/bin/ls -lt #{backup_dir}"
    end

    desc 'Restores the database from a backup using PATTERN'
    task :restore, [:pattern] => [:environment] do |_, args|
      pattern = args[:pattern]

      if pattern.present?
        file = nil
        cmd  = nil

        with_config do |host, port, db, user, password|
          backup_dir = backup_directory
          files      = Dir.glob("#{backup_dir}/**/*#{pattern}*")

          case files.size
          when 0
            puts "No backups found for the pattern '#{pattern}'"
          when 1
            file = files.first
            fmt = format_for_file file
            case fmt
            when nil
              puts "No recognized dump file suffix: #{file}"
            when 'p'
              cmd = "psql --dbname='postgresql://#{user}:#{password}@#{host}:#{port}/#{db}' -f '#{file}'"
            else
              cmd = "PGCLUSTER=#{ENV.fetch('POSTGRES_VERSION', '9.6')}/main pg_restore -F #{fmt} -v -c -C -U --dbname='postgresql://#{user}:#{password}@#{host}:#{port}/#{db}' -f '#{file}'"
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
          Rake::Task['data_cycle_core:db:clear_connections'].invoke
          Rake::Task['db:drop'].invoke
          Rake::Task['db:create'].invoke
          puts cmd
          system cmd
          puts ''
          puts "Restored from file: #{file}"
          puts ''
        end
      else
        puts 'Please specify a file pattern for the backup to restore (e.g. timestamp)'
      end
    end

    desc 'remove all active database connections'
    task clear_connections: :environment do
      ActiveRecord::Base.establish_connection
      ActiveRecord::Base.connection.select_all "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname='#{ActiveRecord::Base.connection_config[:database]}' AND pid <> pg_backend_pid();"
    end

    desc 'import db from [cap_environment]'
    task :import_remote_db, [:cap_environment] => [:environment] do |_, args|
      logger = Logger.new('log/import_live_db.log')
      logger.info('Started Importing Live DB...')

      sh "cap #{args.fetch(:cap_environment, 'pre_release')} review:download_dev_db[true]"
      sh "mkdir -p db/backups/#{ENV.fetch('RAILS_ENV', 'development')}/"
      sh "mv tmp/dev_db.sql db/backups/#{ENV.fetch('RAILS_ENV', 'development')}/dev_db.sql"

      ENV['DISABLE_DATABASE_ENVIRONMENT_CHECK'] = '1'

      Rake::Task['data_cycle_core:db:clear_connections'].invoke
      Rake::Task['data_cycle_core:db:restore'].invoke('dev_db.sql')
      logger.info('Imported Live DB successfully')
    end

    desc 'reset database, import templates, classifications, external_sources'
    task :reset, [:prefix] => :environment do |_, args|
      args[:prefix] ||= ''

      ENV['RAILS_ENV'] ||= Rails.env
      puts "Environment: #{ENV['RAILS_ENV']}"

      begin
        Rake::Task["#{args[:prefix]}data_cycle_core:db:clear_connections"].invoke
        Rake::Task["#{args[:prefix]}db:drop"].invoke
      rescue ActiveRecord::NoDatabaseError
        puts 'No Database to drop, proceeding...'
      end

      Rake::Task["#{args[:prefix]}db:create"].invoke
      Rake::Task["#{args[:prefix]}db:migrate"].invoke
      Rake::Task["#{args[:prefix]}db:seed"].invoke
      Rake::Task["#{args[:prefix]}data_cycle_core:update:import_classifications"].invoke
      Rake::Task["#{args[:prefix]}data_cycle_core:update:import_external_source_configs"].invoke
      Rake::Task["#{args[:prefix]}data_cycle_core:update:import_external_system_configs"].invoke
      Rake::Task["#{args[:prefix]}data_cycle_core:update:import_templates"].invoke
      puts 'Reset Complete...'
    end

    private

    def ensure_format(format)
      return format if ['c', 'p', 't', 'd'].include?(format)

      case format
      when 'dump' then 'c'
      when 'sql' then 'p'
      when 'tar' then 't'
      when 'dir' then 'd'
      else 'p'
      end
    end

    def suffix_for_format(suffix)
      case suffix
      when 'c' then 'dump'
      when 'p' then 'sql'
      when 't' then 'tar'
      when 'd' then 'dir'
      end
    end

    def format_for_file(file)
      case file
      when /\.dump$/ then 'c'
      when /\.sql$/  then 'p'
      when /\.dir$/  then 'd'
      when /\.tar$/  then 't'
      end
    end

    def backup_directory(suffix = nil, create: false)
      backup_dir = Rails.root.join('db', 'backups', suffix.nil? ? '' : suffix)

      if create && !Dir.exist?(backup_dir)
        puts "Creating #{backup_dir} .."
        FileUtils.mkdir_p(backup_dir)
      end

      backup_dir
    end

    def with_config
      yield ActiveRecord::Base.connection_config[:host],
        ActiveRecord::Base.connection_config[:port],
        ActiveRecord::Base.connection_config[:database],
        ActiveRecord::Base.connection_config[:username],
        ActiveRecord::Base.connection_config[:password]
    end
  end
end
