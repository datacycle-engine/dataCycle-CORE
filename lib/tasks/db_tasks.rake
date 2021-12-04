# frozen_string_literal: true

namespace :db do
  namespace :migrate do
    desc 'run data migrations'
    task with_data: :environment do
      data_paths = [
        Rails.root.join('db', 'data_migrate').to_s,
        DataCycleCore::Engine.root.join('db', 'data_migrate').to_s
      ]

      Rails.application.config.paths['db/migrate'].concat(data_paths)
      ActiveRecord::Migrator.migrations_paths.concat(data_paths)

      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}db:migrate"].invoke
    end
  end

  namespace :maintenance do
    desc 'run VACUUM FULL and ANALYZE on DB'
    task vacuum_full: :environment do
      ActiveRecord::Base.connection.execute('VACUUM FULL;')
      ActiveRecord::Base.connection.execute('ANALYZE;')
    end

    desc 'run VACUUM (FULL) on DB, full(false|true)'
    task :vacuum, [:full] => [:environment] do |_, args|
      full = args.fetch(:full, false)
      sql = 'VACUUM'
      sql += ' FULL' if full
      sql += ';'
      ActiveRecord::Base.connection.execute(sql)
    end
  end
end
